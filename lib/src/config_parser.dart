import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'models/flavor_config.dart';
import 'schema/schema_validator.dart';
import 'utils/logger.dart';

/// Top-level YAML keys that are reserved for schema metadata.
///
/// These keys are skipped when iterating over flavor names so that
/// e.g. `schema_version: 1` is not treated as a flavor definition.
const _reservedTopLevelKeys = {'schema_version'};

/// Configuration parser for reading flavor configurations from YAML.
///
/// This class handles loading and validating flavor configuration files,
/// supporting both dedicated flavor_config.yaml files and inline
/// configurations in pubspec.yaml.
final class ConfigParser {
  /// Creates a new [ConfigParser] instance.
  ///
  /// [logger] is used for logging parsing operations and errors.
  ConfigParser({required this.logger});

  /// Logger instance for output.
  final Logger logger;

  /// Parses flavor configuration from a YAML file.
  ///
  /// First looks for a dedicated `flavor_config.yaml` file in the project root.
  /// If not found, looks for a `flavor_config` section in `pubspec.yaml`.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [configPath] optionally points to a specific YAML config file.
  ///
  /// Returns a map of flavor names to [FlavorConfig] instances.
  ///
  /// Throws [FormatException] if the YAML is invalid.
  /// Throws [FileSystemException] if no configuration file is found.
  Future<Map<String, FlavorConfig>> parseConfig(
    String projectRoot, {
    String? configPath,
  }) async {
    final configYaml = await _loadConfigYaml(projectRoot, configPath);
    return _parseFlavorConfigs(configYaml);
  }

  /// Parses all flavor configurations **without** running per-flavor
  /// validation.
  ///
  /// Identical to [parseConfig] except that [validateConfig] is not called
  /// for each flavor.  This allows the caller to collect per-flavor error
  /// details (e.g. for `validate --output json`) rather than having the first
  /// invalid flavor abort the whole parse.
  ///
  /// Throws [FileSystemException] if no configuration file is found.
  Future<Map<String, FlavorConfig>> parseConfigUnchecked(
    String projectRoot, {
    String? configPath,
  }) async {
    final configYaml = await _loadConfigYaml(projectRoot, configPath);
    return _parseFlavorConfigsUnchecked(configYaml);
  }

  /// Parses a specific flavor configuration from a YAML file.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [flavorName] is the name of the flavor to parse.
  /// [configPath] optionally points to a specific YAML config file.
  ///
  /// Returns a [FlavorConfig] instance for the specified flavor.
  ///
  /// Throws [FormatException] if the flavor is not found.
  Future<FlavorConfig> parseFlavorConfig(
    String projectRoot,
    String flavorName, {
    String? configPath,
  }) async {
    logger.debug('Parsing flavor configuration for: $flavorName');

    final allConfigs = await parseConfig(
      projectRoot,
      configPath: configPath,
    );

    if (!allConfigs.containsKey(flavorName)) {
      throw FormatException(
        'Flavor "$flavorName" not found in configuration. '
        'Available flavors: ${allConfigs.keys.join(', ')}',
      );
    }

    return allConfigs[flavorName]!;
  }

  /// Gets a list of all available flavor names.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [configPath] optionally points to a specific YAML config file.
  Future<List<String>> getAvailableFlavors(
    String projectRoot, {
    String? configPath,
  }) async {
    final configs = await parseConfig(
      projectRoot,
      configPath: configPath,
    );
    return configs.keys.toList();
  }

  /// Validates that all required fields are present in the configuration.
  ///
  /// [config] is the flavor configuration to validate.
  ///
  /// Throws [FormatException] if validation fails.
  void validateConfig(FlavorConfig config) {
    logger.debug('Validating configuration for flavor: ${config.name}');

    final errors = <String>[];

    if (config.bundleId.isEmpty) {
      errors.add('bundle_id is required but was empty');
    }

    if (config.appName.isEmpty) {
      errors.add('app_name is required but was empty');
    }

    // Validate bundle ID format (basic check)
    if (config.bundleId.isNotEmpty) {
      final bundleIdRegex = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
      if (!bundleIdRegex.hasMatch(config.bundleId)) {
        errors.add(
          'bundle_id "${config.bundleId}" is not in valid format '
          '(e.g., com.example.app)',
        );
      }
    }

    if (errors.isNotEmpty) {
      throw FormatException(
        'Configuration validation failed for flavor "${config.name}":\n'
        '${errors.map((e) => '  - $e').join('\n')}',
      );
    }

    logger.debug('Configuration validation passed');
  }

  /// Extracts the `schema_version` integer from a raw config YAML map.
  ///
  /// [rawConfig] is the full map returned by [_loadConfigYaml] (including
  /// the `schema_version` key when present alongside the flavor names).
  ///
  /// Returns the version as an [int], or `null` if the key is absent.
  int? extractSchemaVersion(Map<dynamic, dynamic> rawConfig) =>
      rawConfig['schema_version'] as int?;

  /// Loads the config and returns the parsed `schema_version`, or `null`.
  ///
  /// Convenience wrapper around [extractSchemaVersion] that handles file I/O.
  Future<int?> parseSchemaVersion(
    String projectRoot, {
    String? configPath,
  }) async {
    final rawConfig = await _loadConfigYaml(projectRoot, configPath);
    return extractSchemaVersion(rawConfig);
  }

  /// Validates the structural schema of the config document.
  ///
  /// Checks for:
  /// - Presence of `schema_version` (error in strict mode, warning otherwise).
  /// - Unknown keys in each flavor block.
  /// - Deprecated keys in each flavor block.
  /// - Unknown keys in the `provisioning` sub-block of each flavor.
  ///
  /// Returns a [SchemaValidationResult] with all issues grouped by
  /// global vs. per-flavor and error vs. warning.
  Future<SchemaValidationResult> validateSchema(
    String projectRoot, {
    String? configPath,
    bool strict = false,
  }) async {
    final rawConfig = await _loadConfigYaml(projectRoot, configPath);
    final schemaVersion = extractSchemaVersion(rawConfig);

    // Build a flavor-only map for the validator (strip reserved top-level keys).
    final flavorsOnly = Map<dynamic, dynamic>.fromEntries(
      rawConfig.entries.where(
        (e) => !_reservedTopLevelKeys.contains(e.key as String),
      ),
    );

    return const SchemaValidator().validate(
      flavorsOnly,
      schemaVersion,
      strict: strict,
    );
  }

  /// Extracts the flavor_config section from a YAML document.
  Map<dynamic, dynamic> _extractFlavorConfig(YamlMap yaml) {
    if (yaml.containsKey('flavor_config')) {
      return yaml['flavor_config'] as YamlMap;
    } else if (yaml.containsKey('flavors')) {
      // Alternative key name
      return yaml['flavors'] as YamlMap;
    }

    return yaml;
  }

  /// Loads and extracts the raw YAML config map from the appropriate file.
  ///
  /// Looks for `flavor_config.yaml` first, then `pubspec.yaml`, or loads from
  /// an explicit [configPath] if provided.
  ///
  /// Throws [FileSystemException] or [FormatException] on missing/invalid file.
  Future<Map<dynamic, dynamic>> _loadConfigYaml(
    String projectRoot,
    String? configPath,
  ) async {
    logger.debug('Parsing flavor configuration from: $projectRoot');

    if (configPath != null && configPath.trim().isNotEmpty) {
      final resolvedPath = path.isAbsolute(configPath)
          ? configPath
          : path.join(projectRoot, configPath);
      final configFile = File(resolvedPath);

      logger
        ..debug('Using external configuration file: $resolvedPath')
        ..info('Loading configuration from: $resolvedPath');

      if (!await configFile.exists()) {
        throw FileSystemException(
          'Configuration file not found',
          resolvedPath,
        );
      }

      final content = await configFile.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      return _extractFlavorConfig(yaml);
    }

    // Try dedicated flavor_config.yaml first
    final flavorConfigPath = path.join(projectRoot, 'flavor_config.yaml');
    final flavorConfigFile = File(flavorConfigPath);

    if (await flavorConfigFile.exists()) {
      logger
        ..debug('Found flavor_config.yaml')
        ..info('Loading configuration from: $flavorConfigPath');
      final content = await flavorConfigFile.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      return _extractFlavorConfig(yaml);
    }

    // Try pubspec.yaml
    logger.debug('flavor_config.yaml not found, checking pubspec.yaml');
    final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);

    if (!await pubspecFile.exists()) {
      throw FileSystemException(
        'No pubspec.yaml found in project root',
        projectRoot,
      );
    }

    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content) as YamlMap;

    if (!yaml.containsKey('flavor_config')) {
      throw const FormatException(
        'No flavor_config found in pubspec.yaml or flavor_config.yaml',
      );
    }

    logger.info('Loading configuration from: $pubspecPath');
    return _extractFlavorConfig(yaml);
  }

  /// Parses all flavor configurations from a YAML map.
  Map<String, FlavorConfig> _parseFlavorConfigs(
    Map<dynamic, dynamic> configYaml,
  ) {
    final configs = <String, FlavorConfig>{};

    for (final entry in configYaml.entries) {
      final flavorName = entry.key as String;
      // Skip reserved top-level keys (e.g. schema_version).
      if (_reservedTopLevelKeys.contains(flavorName)) {
        continue;
      }
      final flavorData = entry.value as Map<dynamic, dynamic>;

      logger.debug('Parsing flavor: $flavorName');

      try {
        final config = FlavorConfig.fromYaml(flavorName, flavorData);
        validateConfig(config);
        configs[flavorName] = config;
      } catch (e) {
        logger.error('Failed to parse flavor "$flavorName"', e);
        rethrow;
      }
    }

    if (configs.isEmpty) {
      throw const FormatException('No valid flavor configurations found');
    }

    logger.info('Successfully parsed ${configs.length} flavor(s): '
        '${configs.keys.join(', ')}');

    return configs;
  }

  /// Parses all flavor configurations from a YAML map **without** running
  /// validation on each flavor.
  ///
  /// Use this when you need the raw [FlavorConfig] objects so that you can
  /// validate them individually (e.g. to collect per-flavor error details).
  Map<String, FlavorConfig> _parseFlavorConfigsUnchecked(
    Map<dynamic, dynamic> configYaml,
  ) {
    final configs = <String, FlavorConfig>{};

    for (final entry in configYaml.entries) {
      final flavorName = entry.key as String;
      // Skip reserved top-level keys (e.g. schema_version).
      if (_reservedTopLevelKeys.contains(flavorName)) {
        continue;
      }
      final flavorData = entry.value as Map<dynamic, dynamic>;
      configs[flavorName] = FlavorConfig.fromYaml(flavorName, flavorData);
    }

    return configs;
  }
}
