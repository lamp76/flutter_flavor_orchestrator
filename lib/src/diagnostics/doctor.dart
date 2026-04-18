import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../models/flavor_config.dart';
import '../utils/logger.dart';
import 'diagnostic.dart';

/// Preflight diagnostics runner for the Flutter Flavor Orchestrator.
///
/// [Doctor] runs a series of composable checks against the project and its
/// flavor configuration, producing a [DoctorResult] with categorised
/// [Diagnostic] findings (error / warning / info).
///
/// No file mutations are performed — `doctor` is a read-only command.
///
/// Usage:
/// ```dart
/// final doctor = Doctor(projectRoot: '/path/to/project');
/// final result = await doctor.run(platforms: ['android', 'ios']);
/// if (result.hasErrors) { /* handle */ }
/// ```
final class Doctor {
  /// Creates a new [Doctor] instance.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [configPath] optionally points to an external YAML config file.
  /// [logger] is used for debug output when the `--debug` flag is active.
  const Doctor({
    required this.projectRoot,
    this.configPath,
    this.logger = const Logger(),
  });

  /// Root directory of the Flutter project being diagnosed.
  final String projectRoot;

  /// Optional external path to a flavor configuration YAML file.
  final String? configPath;

  /// Logger for debug output.
  ///
  /// When created with `Logger(verbose: true)`, all `debug()` calls produce
  /// output — this corresponds to running `doctor --debug` on the CLI.
  final Logger logger;

  /// Runs all diagnostic checks and returns the aggregated [DoctorResult].
  ///
  /// [platforms] controls which platform-specific checks are executed.
  /// Pass `['android']`, `['ios']`, or both (the default).
  Future<DoctorResult> run({
    List<String> platforms = const ['android', 'ios'],
  }) async {
    final diagnostics = <Diagnostic>[];

    logger
      ..debug(
        'Doctor starting — projectRoot: $projectRoot, '
        'platforms: ${platforms.isEmpty ? "none" : platforms.join(", ")}',
      )
      // ── Project-root checks ────────────────────────────────────────────────
      ..debug('Checking project root...');
    final pubspecOk = await _checkProjectRoot(diagnostics);

    // ── Config checks ────────────────────────────────────────────────────────
    // Only proceed with config checks when the project root is valid.
    Map<String, FlavorConfig>? configs;
    int? schemaVersion;
    if (pubspecOk) {
      logger.debug('Checking flavor config...');
      configs = await _checkConfig(
        diagnostics,
        schemaVersion: (v) => schemaVersion = v,
      );
      if (configs != null) {
        logger.debug(
          'Config loaded: ${configs.length} flavor(s): '
          '${configs.keys.join(", ")}',
        );
      }
    }

    // ── Platform checks ──────────────────────────────────────────────────────
    for (final platform in platforms) {
      if (platform == 'android') {
        logger.debug('Checking Android project structure...');
        await _checkAndroidProject(diagnostics);
      } else if (platform == 'ios') {
        logger.debug('Checking iOS project structure...');
        await _checkIosProject(diagnostics);
      }
    }

    // ── Per-flavor file reference checks ────────────────────────────────────
    if (configs != null) {
      for (final config in configs.values) {
        logger.debug(
          'Checking file references for flavor "${config.name}"...',
        );
        await _checkFlavorFileRefs(diagnostics, config, platforms: platforms);
      }
    }

    // ── Schema version info ──────────────────────────────────────────────────
    if (configs != null && schemaVersion == null) {
      logger.debug('schema_version key absent from config.');
      diagnostics.add(
        const Diagnostic(
          code: 'schema_version_missing',
          severity: DiagnosticSeverity.warning,
          message: 'schema_version key is absent from the config document.',
          suggestion: 'Add `schema_version: 1` at the top of your '
              'flavor_config.yaml to enable strict validation and future '
              'migration support.',
        ),
      );
    }

    final result = DoctorResult(diagnostics: diagnostics);
    logger.debug(
      'Doctor complete — ${result.errors.length} error(s), '
      '${result.warnings.length} warning(s), '
      '${result.infos.length} info(s).',
    );
    return result;
  }

  // ── Project-root checks ────────────────────────────────────────────────────

  /// Resolves the effective config file path.
  ///
  /// Resolution order:
  /// 1. [configPath] (explicit external path)
  /// 2. `flavor_config.yaml` in [projectRoot]
  /// 3. `pubspec.yaml` in [projectRoot] — only when it contains a
  ///    `flavor_config:` section.
  ///
  /// Returns the resolved path on success, or `null` when no config is found
  /// (in which case a [Diagnostic] with code `no_config` is added to
  /// [diagnostics]).
  Future<String?> _resolveConfigPath(List<Diagnostic> diagnostics) async {
    if (configPath != null && configPath!.trim().isNotEmpty) {
      final resolved = path.isAbsolute(configPath!)
          ? configPath!
          : path.join(projectRoot, configPath);
      logger.debug('Checking explicit config path: $resolved');
      if (!await File(resolved).exists()) {
        logger.debug('Explicit config not found: $resolved');
        diagnostics.add(
          Diagnostic(
            code: 'no_config',
            severity: DiagnosticSeverity.error,
            message: 'Flavor config file not found at: $resolved',
            suggestion: 'Verify the path passed to `--config` and '
                'ensure the file exists.',
            path: resolved,
          ),
        );
        return null;
      }
      logger.debug('Using explicit config: $resolved');
      return resolved;
    }

    final dedicated = path.join(projectRoot, 'flavor_config.yaml');
    logger.debug('Checking dedicated config: $dedicated');
    if (await File(dedicated).exists()) {
      logger.debug('Using dedicated config: $dedicated');
      return dedicated;
    }

    // Fall back to pubspec.yaml — only if it has a flavor_config section.
    final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
    logger.debug(
      'Checking pubspec.yaml for flavor_config section: $pubspecPath',
    );
    if (await File(pubspecPath).exists()) {
      try {
        final content = await File(pubspecPath).readAsString();
        final parsed = loadYaml(content);
        if (parsed is YamlMap && parsed.containsKey('flavor_config')) {
          logger.debug(
            'Using pubspec.yaml (has flavor_config section): $pubspecPath',
          );
          return pubspecPath;
        }
      } on YamlException {
        // Fall through to no_config below.
      }
    }

    logger.debug('No flavor config found in project root: $projectRoot');
    diagnostics.add(
      Diagnostic(
        code: 'no_config',
        severity: DiagnosticSeverity.error,
        message: 'No flavor config found. Neither `flavor_config.yaml` nor '
            'a `flavor_config:` section in `pubspec.yaml` was found.',
        suggestion: 'Create a `flavor_config.yaml` in your project root, '
            'or add a `flavor_config:` section to `pubspec.yaml`.',
        path: projectRoot,
      ),
    );
    return null;
  }

  /// Checks that `pubspec.yaml` exists in [projectRoot].
  ///
  /// Returns `true` when the file is present.
  Future<bool> _checkProjectRoot(List<Diagnostic> diagnostics) async {
    final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);

    if (!await pubspecFile.exists()) {
      logger.debug('pubspec.yaml not found at: $pubspecPath');
      diagnostics.add(
        Diagnostic(
          code: 'no_pubspec',
          severity: DiagnosticSeverity.error,
          message:
              'pubspec.yaml not found — this does not appear to be a '
              'Flutter project.',
          suggestion: 'Run `flutter create .` in a Flutter project directory, '
              'or change to your project root before running `doctor`.',
          path: pubspecPath,
        ),
      );
      return false;
    }

    logger.debug('pubspec.yaml found at: $pubspecPath');
    return true;
  }

  // ── Config checks ──────────────────────────────────────────────────────────

  /// Locates, loads, and lightly validates the flavor config.
  ///
  /// Reports errors/warnings via [diagnostics] and returns the parsed
  /// [FlavorConfig] map on success, or `null` when loading fails.
  ///
  /// The [schemaVersion] callback is called with the extracted version (or
  /// `null`) so the caller can record it without re-parsing.
  Future<Map<String, FlavorConfig>?> _checkConfig(
    List<Diagnostic> diagnostics, {
    required void Function(int?) schemaVersion,
  }) async {
    // Determine the effective config path.
    final resolvedPath = await _resolveConfigPath(diagnostics);
    if (resolvedPath == null) {
      return null;
    }

    // Attempt to parse the YAML.
    final rawYaml = await _readAndParseYaml(
      resolvedPath,
      diagnostics,
    );
    if (rawYaml == null) {
      return null;
    }

    // Extract and report schema_version.
    const reservedTopLevelKeys = {'schema_version'};
    schemaVersion(rawYaml['schema_version'] as int?);

    // Parse flavors.
    final configs = <String, FlavorConfig>{};
    for (final entry in rawYaml.entries) {
      final key = entry.key as String;
      if (reservedTopLevelKeys.contains(key)) {
        continue;
      }
      final value = entry.value;
      if (value is! Map<dynamic, dynamic>) {
        diagnostics.add(
          Diagnostic(
            code: 'config_parse_error',
            severity: DiagnosticSeverity.error,
            message: 'Flavor "$key" has an invalid structure — expected a map.',
            suggestion:
                'Each flavor in the config must be a YAML map with keys '
                'like `bundle_id`, `app_name`, etc.',
            path: resolvedPath,
          ),
        );
        continue;
      }
      try {
        configs[key] = FlavorConfig.fromYaml(key, value);
      } on Object catch (e) {
        diagnostics.add(
          Diagnostic(
            code: 'config_parse_error',
            severity: DiagnosticSeverity.error,
            message: 'Could not parse flavor "$key": $e',
            suggestion: 'Review the structure of the "$key" flavor block. '
                'Ensure all required keys are present and have the correct '
                'types.',
            path: resolvedPath,
          ),
        );
      }
    }

    if (configs.isEmpty) {
      diagnostics.add(
        Diagnostic(
          code: 'no_flavor_config_key',
          severity: DiagnosticSeverity.error,
          message: 'No flavor definitions found in the config file.',
          suggestion:
              'Add at least one flavor block (e.g. `dev:`) with `bundle_id` '
              'and `app_name` keys to your config.',
          path: resolvedPath,
        ),
      );
      return null;
    }

    // Semantic validation of each flavor.
    final allValid = _validateFlavorSemantics(
      diagnostics,
      configs,
      configFilePath: resolvedPath,
    );

    if (allValid) {
      diagnostics.add(
        Diagnostic(
          code: 'config_valid',
          severity: DiagnosticSeverity.info,
          message: 'Flavor config is present and valid '
              '(${configs.length} flavor(s): '
              '${configs.keys.join(', ')}).',
          path: resolvedPath,
        ),
      );
    }

    return configs;
  }

  /// Validates semantic correctness of each flavor (required fields, formats).
  ///
  /// Returns `true` when every flavor passes, `false` when any flavor fails.
  bool _validateFlavorSemantics(
    List<Diagnostic> diagnostics,
    Map<String, FlavorConfig> configs, {
    required String configFilePath,
  }) {
    var allValid = true;

    for (final config in configs.values) {
      if (config.bundleId.isEmpty) {
        diagnostics.add(
          Diagnostic(
            code: 'config_parse_error',
            severity: DiagnosticSeverity.error,
            message:
                'Flavor "${config.name}": `bundle_id` is required but empty.',
            suggestion:
                'Add a non-empty `bundle_id` to the "${config.name}" flavor '
                '(e.g. `bundle_id: com.example.app.${config.name}`).',
            path: configFilePath,
          ),
        );
        allValid = false;
      }

      if (config.appName.isEmpty) {
        diagnostics.add(
          Diagnostic(
            code: 'config_parse_error',
            severity: DiagnosticSeverity.error,
            message:
                'Flavor "${config.name}": `app_name` is required but empty.',
            suggestion:
                'Add a non-empty `app_name` to the "${config.name}" flavor.',
            path: configFilePath,
          ),
        );
        allValid = false;
      }

      if (config.bundleId.isNotEmpty) {
        final bundleIdRegex =
            RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
        if (!bundleIdRegex.hasMatch(config.bundleId)) {
          diagnostics.add(
            Diagnostic(
              code: 'config_parse_error',
              severity: DiagnosticSeverity.error,
              message:
                  'Flavor "${config.name}": bundle_id "${config.bundleId}" '
                  'is not in valid format.',
              suggestion:
                  'Use a reverse-domain format, e.g. `com.example.app`. '
                  'Only lowercase letters, digits, and underscores are '
                  'allowed in each segment.',
              path: configFilePath,
            ),
          );
          allValid = false;
        }
      }
    }

    return allValid;
  }

  // ── Platform checks ────────────────────────────────────────────────────────

  /// Checks Android project structure.
  Future<void> _checkAndroidProject(List<Diagnostic> diagnostics) async {
    final androidDir = path.join(projectRoot, 'android');
    if (!await Directory(androidDir).exists()) {
      logger.debug('Android directory not found: $androidDir');
      diagnostics.add(
        Diagnostic(
          code: 'platform_dir_missing',
          severity: DiagnosticSeverity.warning,
          message: 'Android project directory not found.',
          suggestion:
              'If you intend to support Android, ensure the `android/` '
              'directory exists. Run `flutter create .` to regenerate it, '
              'or pass `--platform ios` to skip Android checks.',
          path: androidDir,
        ),
      );
      return;
    }

    final manifestPath = path.join(
      projectRoot,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    );
    if (!await File(manifestPath).exists()) {
      logger.debug('AndroidManifest.xml not found: $manifestPath');
      diagnostics.add(
        Diagnostic(
          code: 'android_manifest_missing',
          severity: DiagnosticSeverity.error,
          message: 'AndroidManifest.xml not found.',
          suggestion:
              'Ensure the file exists at '
              '`android/app/src/main/AndroidManifest.xml`. '
              'Run `flutter create .` to restore missing native files.',
          path: manifestPath,
        ),
      );
    } else {
      logger.debug('AndroidManifest.xml found: $manifestPath');
    }

    final gradlePath =
        path.join(projectRoot, 'android', 'app', 'build.gradle');
    final gradleKtsPath =
        path.join(projectRoot, 'android', 'app', 'build.gradle.kts');

    if (!await File(gradlePath).exists() &&
        !await File(gradleKtsPath).exists()) {
      logger.debug(
        'Neither build.gradle nor build.gradle.kts found in android/app/',
      );
      diagnostics.add(
        Diagnostic(
          code: 'android_build_gradle_missing',
          severity: DiagnosticSeverity.error,
          message: 'Neither `build.gradle` nor `build.gradle.kts` found in '
              '`android/app/`.',
          suggestion:
              'Ensure one of `android/app/build.gradle` or '
              '`android/app/build.gradle.kts` exists. Run `flutter create .` '
              'to restore missing native files.',
          path: path.join(projectRoot, 'android', 'app'),
        ),
      );
    } else {
      logger.debug('Android build script found.');
    }
  }

  /// Checks iOS project structure.
  Future<void> _checkIosProject(List<Diagnostic> diagnostics) async {
    final iosDir = path.join(projectRoot, 'ios');
    if (!await Directory(iosDir).exists()) {
      logger.debug('iOS directory not found: $iosDir');
      diagnostics.add(
        Diagnostic(
          code: 'platform_dir_missing',
          severity: DiagnosticSeverity.warning,
          message: 'iOS project directory not found.',
          suggestion:
              'If you intend to support iOS, ensure the `ios/` directory '
              'exists. Run `flutter create .` to regenerate it, or pass '
              '`--platform android` to skip iOS checks.',
          path: iosDir,
        ),
      );
      return;
    }

    final infoPlistPath =
        path.join(projectRoot, 'ios', 'Runner', 'Info.plist');
    if (!await File(infoPlistPath).exists()) {
      logger.debug('ios/Runner/Info.plist not found: $infoPlistPath');
      diagnostics.add(
        Diagnostic(
          code: 'ios_info_plist_missing',
          severity: DiagnosticSeverity.error,
          message: 'ios/Runner/Info.plist not found.',
          suggestion:
              'Ensure `ios/Runner/Info.plist` exists. Run `flutter create .` '
              'to restore missing native files.',
          path: infoPlistPath,
        ),
      );
    } else {
      logger.debug('ios/Runner/Info.plist found: $infoPlistPath');
    }

    final xcodeprojPath =
        path.join(projectRoot, 'ios', 'Runner.xcodeproj');
    if (!await Directory(xcodeprojPath).exists()) {
      logger.debug('ios/Runner.xcodeproj/ not found: $xcodeprojPath');
      diagnostics.add(
        Diagnostic(
          code: 'ios_xcodeproj_missing',
          severity: DiagnosticSeverity.error,
          message: 'ios/Runner.xcodeproj/ directory not found.',
          suggestion:
              'Ensure `ios/Runner.xcodeproj/` exists. Run `flutter create .` '
              'to restore missing native files.',
          path: xcodeprojPath,
        ),
      );
    } else {
      logger.debug('ios/Runner.xcodeproj/ found: $xcodeprojPath');
    }
  }

  // ── Per-flavor file-reference checks ──────────────────────────────────────

  /// Checks that all source file paths referenced by [config] exist on disk.
  ///
  /// Only checks provisioning files relevant to [platforms].
  Future<void> _checkFlavorFileRefs(
    List<Diagnostic> diagnostics,
    FlavorConfig config, {
    required List<String> platforms,
  }) async {
    final prov = config.provisioning;

    if (prov != null) {
      // Android provisioning.
      if (platforms.contains('android') &&
          prov.androidGoogleServicesPath != null) {
        final p = path.isAbsolute(prov.androidGoogleServicesPath!)
            ? prov.androidGoogleServicesPath!
            : path.join(projectRoot, prov.androidGoogleServicesPath);
        logger.debug(
          'Checking Android google-services.json source: $p',
        );
        if (!await File(p).exists()) {
          diagnostics.add(
            Diagnostic(
              code: 'provisioning_file_missing',
              severity: DiagnosticSeverity.warning,
              message:
                  'Flavor "${config.name}": Android google-services.json '
                  'source file not found.',
              suggestion: 'Ensure the file exists at '
                  '"${prov.androidGoogleServicesPath}". '
                  'Download it from the Firebase console or update the '
                  '`android_google_services` path in your config.',
              path: p,
            ),
          );
        } else {
          logger.debug('Android google-services.json source found: $p');
        }
      }

      // iOS provisioning.
      if (platforms.contains('ios') && prov.iosGoogleServicePath != null) {
        final p = path.isAbsolute(prov.iosGoogleServicePath!)
            ? prov.iosGoogleServicePath!
            : path.join(projectRoot, prov.iosGoogleServicePath);
        logger.debug(
          'Checking iOS GoogleService-Info.plist source: $p',
        );
        if (!await File(p).exists()) {
          diagnostics.add(
            Diagnostic(
              code: 'provisioning_file_missing',
              severity: DiagnosticSeverity.warning,
              message:
                  'Flavor "${config.name}": iOS GoogleService-Info.plist '
                  'source file not found.',
              suggestion: 'Ensure the file exists at '
                  '"${prov.iosGoogleServicePath}". '
                  'Download it from the Firebase console or update the '
                  '`ios_google_service` path in your config.',
              path: p,
            ),
          );
        } else {
          logger.debug('iOS GoogleService-Info.plist source found: $p');
        }
      }

      // Additional provisioning files.
      for (final entry in prov.additionalFiles.entries) {
        final src = entry.value;
        final srcAbsolute = path.isAbsolute(src)
            ? src
            : path.join(projectRoot, src);
        logger.debug(
          'Checking additional provisioning file: $srcAbsolute',
        );
        if (!await File(srcAbsolute).exists()) {
          diagnostics.add(
            Diagnostic(
              code: 'provisioning_file_missing',
              severity: DiagnosticSeverity.warning,
              message:
                  'Flavor "${config.name}": additional provisioning source '
                  '"$src" not found.',
              suggestion:
                  'Ensure the source file exists at "$src" relative to the '
                  'project root, or update the `additional_files` path in '
                  'your config.',
              path: srcAbsolute,
            ),
          );
        } else {
          logger.debug('Additional provisioning file found: $srcAbsolute');
        }
      }
    }

    // File mapping sources.
    for (final entry in config.fileMappings.entries) {
      final src = entry.value; // value is source path
      final srcAbsolute = path.isAbsolute(src)
          ? src
          : path.join(projectRoot, src);
      logger.debug('Checking file_mapping source: $srcAbsolute');
      final srcExists = await File(srcAbsolute).exists() ||
          await Directory(srcAbsolute).exists();
      if (!srcExists) {
        diagnostics.add(
          Diagnostic(
            code: 'file_mapping_source_missing',
            severity: DiagnosticSeverity.warning,
            message:
                'Flavor "${config.name}": file_mappings source "$src" '
                'not found.',
            suggestion:
                'Create the source file/directory at "$src" relative to '
                'the project root, or remove/update the corresponding '
                'entry in `file_mappings`.',
            path: srcAbsolute,
          ),
        );
      } else {
        logger.debug('File mapping source found: $srcAbsolute');
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Reads [filePath] and parses it as a YAML map.
  ///
  /// Returns `null` on any I/O or parse error, and adds the appropriate
  /// [Diagnostic] to [diagnostics].
  Future<Map<dynamic, dynamic>?> _readAndParseYaml(
    String filePath,
    List<Diagnostic> diagnostics,
  ) async {
    String content;
    try {
      content = await File(filePath).readAsString();
    } on FileSystemException catch (e) {
      diagnostics.add(
        Diagnostic(
          code: 'config_parse_error',
          severity: DiagnosticSeverity.error,
          message: 'Could not read config file: ${e.message}',
          suggestion: 'Ensure the config file is readable and not corrupted.',
          path: filePath,
        ),
      );
      return null;
    }

    try {
      final parsed = loadYaml(content);
      if (parsed is! YamlMap) {
        diagnostics.add(
          Diagnostic(
            code: 'config_parse_error',
            severity: DiagnosticSeverity.error,
            message: 'Config file is not a valid YAML mapping.',
            suggestion:
                'Ensure your config file contains a top-level YAML map. '
                'See the documentation for the expected format.',
            path: filePath,
          ),
        );
        return null;
      }
      // Extract flavor_config section if nested (pubspec.yaml style).
      return _extractFlavorSection(parsed);
    } on YamlException catch (e) {
      diagnostics.add(
        Diagnostic(
          code: 'config_parse_error',
          severity: DiagnosticSeverity.error,
          message: 'YAML parse error in config file: ${e.message}',
          suggestion:
              'Fix the YAML syntax error at the reported location. '
              'Consider using a YAML linter to validate the file.',
          path: filePath,
        ),
      );
      return null;
    }
  }

  /// Extracts the flavor config section from a parsed YAML map.
  ///
  /// Supports the `flavor_config:` wrapper used in `pubspec.yaml` and the
  /// `flavors:` alternative key.  Falls back to the root map.
  Map<dynamic, dynamic> _extractFlavorSection(YamlMap yaml) {
    if (yaml.containsKey('flavor_config')) {
      return yaml['flavor_config'] as YamlMap;
    }
    if (yaml.containsKey('flavors')) {
      return yaml['flavors'] as YamlMap;
    }
    return yaml;
  }
}
