import 'dart:io';
import 'config_parser.dart';
import 'models/execution_plan.dart';
import 'models/flavor_config.dart';
import 'models/operation_kind.dart';
import 'models/planned_operation.dart';
import 'processors/android_processor.dart';
import 'processors/asset_processor.dart';
import 'processors/ios_processor.dart';
import 'utils/backup_manager.dart';
import 'utils/conflict_analyzer.dart';
import 'utils/file_manager.dart';
import 'utils/logger.dart';

/// Main orchestrator for flavor configuration processing.
///
/// Coordinates the parsing of configuration files and the execution of
/// platform-specific processors to apply flavor configurations.
final class FlavorOrchestrator {
  /// Creates a new [FlavorOrchestrator] instance.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [verbose] enables detailed debug logging.
  /// [silent] suppresses all logger output (used for JSON output mode).
  FlavorOrchestrator({
    required this.projectRoot,
    this.configPath,
    this.verbose = false,
    this.silent = false,
  })  : logger = Logger(verbose: verbose, silent: silent),
        fileManager = FileManager(
          logger: Logger(verbose: verbose, silent: silent),
        ) {
    configParser = ConfigParser(logger: logger);
    androidProcessor = AndroidProcessor(
      fileManager: fileManager,
      logger: logger,
    );
    iosProcessor = IosProcessor(
      fileManager: fileManager,
      logger: logger,
    );
    assetProcessor = AssetProcessor(
      projectRoot: projectRoot,
      fileManager: fileManager,
      logger: logger,
    );
    backupManager = BackupManager(
      projectRoot: projectRoot,
      logger: logger,
    );
  }

  /// Root directory of the Flutter project.
  final String projectRoot;

  /// Optional external path to flavor configuration YAML file.
  final String? configPath;

  /// Whether to show verbose debug output.
  final bool verbose;

  /// Whether to suppress all logger output (used for JSON output mode).
  final bool silent;

  /// Logger instance for output.
  late final Logger logger;

  /// File manager for file operations.
  late final FileManager fileManager;

  /// Configuration parser.
  late final ConfigParser configParser;

  /// Android processor.
  late final AndroidProcessor androidProcessor;

  /// iOS processor.
  late final IosProcessor iosProcessor;

  /// Asset processor for file mappings.
  late final AssetProcessor assetProcessor;

  /// Persistent backup manager for pre-apply snapshots.
  late final BackupManager backupManager;

  /// Applies a flavor configuration to the project.
  ///
  /// [flavorName] is the name of the flavor to apply.
  /// [platforms] specifies which platforms to process
  /// ('android', 'ios', or both).
  ///
  /// Before executing, a persistent backup of all destination files is
  /// created in `.ffo/backups/` unless [dryRun] is `true`.
  ///
  /// If the execution plan contains conflicts (duplicate or overlapping
  /// destination paths), the apply is aborted and returns `false` unless
  /// [force] is `true`, in which case the conflicts are logged as warnings
  /// and execution continues.
  ///
  /// Returns `true` if the operation succeeds, `false` otherwise.
  Future<bool> applyFlavor(
    String flavorName, {
    List<String> platforms = const ['android', 'ios'],
    bool dryRun = false,
    bool force = false,
  }) async {
    try {
      fileManager.dryRun = dryRun;

      logger
        ..section('Flutter Flavor Orchestrator')
        ..info('Project root: $projectRoot')
        ..info('Applying flavor: $flavorName')
        ..info('Target platforms: ${platforms.join(', ')}')
        ..info('Dry-run mode: ${dryRun ? 'enabled' : 'disabled'}');

      // Validate project root
      if (!await _validateProjectRoot()) {
        return false;
      }

      // Parse configuration
      final config = await configParser.parseFlavorConfig(
        projectRoot,
        flavorName,
        configPath: configPath,
      );

      logger
        ..info('Configuration loaded successfully')
        ..debug('Bundle ID: ${config.bundleId}')
        ..debug('App Name: ${config.appName}');

      _printFileMappingSummary(config);

      // Build execution plan (shared foundation for apply and future plan cmd)
      final plan = await _buildExecutionPlan(config, platforms);
      logger.debug(
        'Execution plan: ${plan.activeOperations} active, '
        '${plan.skippedOperations} skipped',
      );

      // Run conflict analysis before any file mutations.
      final conflicts = const ConflictAnalyzer().analyze(plan);
      if (conflicts.isNotEmpty) {
        if (!force) {
          logger.error(
            'Conflict detection failed: ${conflicts.length} conflict(s) '
            'found. Use --force to override.',
          );
          for (final conflict in conflicts) {
            logger.error('  [${conflict.code}] ${conflict.message}');
          }
          return false;
        } else {
          logger.warning(
            'Conflicts detected (continuing due to --force):',
          );
          for (final conflict in conflicts) {
            logger.warning('  [${conflict.code}] ${conflict.message}');
          }
        }
      }

      // Create persistent backup before mutating any files (skip in dry-run)
      BackupRecord? backupRecord;
      if (!dryRun) {
        backupRecord = await backupManager.createBackup(plan);
      }

      // Process platforms
      final processAndroid = platforms.contains('android');
      final processIos = platforms.contains('ios');

      if (processAndroid) {
        await androidProcessor.process(projectRoot, config);
      }

      if (processIos) {
        await iosProcessor.process(projectRoot, config);
      }

      // Process file mappings (asset copying)
      await assetProcessor.processFileMappings(config);

      // Commit all file changes
      await fileManager.commit();

      // Finalise backup with post-apply checksums so rollback can detect
      // manual edits that happen after this apply.
      if (backupRecord != null) {
        await backupManager.finalizeBackup(backupRecord);
      }

      if (dryRun) {
        logger
          ..section('Dry-run Complete')
          ..success('Flavor "$flavorName" validated successfully!')
          ..info('No files were changed.');
      } else {
        logger
          ..section('Success')
          ..success('Flavor "$flavorName" applied successfully!')
          ..info('Next steps:')
          ..info('  1. Review the changes in your native files')
          ..info('  2. Run flutter clean')
          ..info('  3. Run flutter pub get')
          ..info('  4. Build your app with the new configuration');
      }

      return true;
    } on Exception catch (e, stackTrace) {
      logger.error('Failed to apply flavor', e, stackTrace);

      // Rollback changes on error
      try {
        await fileManager.rollback();
        logger.warning('Changes have been rolled back');
      } on Exception catch (rollbackError) {
        logger.error(
          'Failed to rollback changes',
          rollbackError,
        );
      }

      return false;
    }
  }

  /// Lists all available flavors in the configuration.
  ///
  /// Returns a list of flavor names.
  Future<List<String>> listFlavors() async {
    try {
      logger.section('Available Flavors');

      final configs = await configParser.parseConfig(
        projectRoot,
        configPath: configPath,
      );
      final flavors = configs.keys.toList()..sort();

      if (flavors.isEmpty) {
        logger.warning('No flavors found in configuration');
        return [];
      }

      logger.info('Found ${flavors.length} flavor(s):');
      for (final flavor in flavors) {
        final config = configs[flavor];
        if (config == null) {
          logger.info('  - $flavor');
          continue;
        }

        logger.info(
          '  - $flavor '
          '(file_mappings: ${config.fileMappings.length}, '
          'replace_destination_directories: '
          '${config.replaceDestinationDirectories})',
        );
      }

      logger.info(
        'Tip: run `flutter_flavor_orchestrator info --flavor <name>` '
        'for full mapping details.',
      );

      return flavors;
    } on FormatException {
      rethrow;
    } on FileSystemException {
      rethrow;
    }
  }

  /// Displays detailed information about a specific flavor.
  ///
  /// [flavorName] is the name of the flavor to inspect.
  Future<void> showFlavorInfo(String flavorName) async {
    try {
      logger.section('Flavor Information: $flavorName');

      final config = await configParser.parseFlavorConfig(
        projectRoot,
        flavorName,
        configPath: configPath,
      );

      _printFlavorConfig(config);
    } on FormatException {
      rethrow;
    } on FileSystemException {
      rethrow;
    }
  }

  /// Returns the [FlavorConfig] for [flavorName] without printing anything.
  ///
  /// Use this method when you need the raw config data (e.g. for JSON output)
  /// rather than human-readable text.  Unlike [showFlavorInfo], this method
  /// does not write any output — it simply parses and returns the config.
  ///
  /// Throws [FormatException] if the flavor is not found or config is invalid.
  Future<FlavorConfig> getFlavorInfo(String flavorName) =>
      configParser.parseFlavorConfig(
        projectRoot,
        flavorName,
        configPath: configPath,
      );

  /// Returns per-flavor validation results as a structured list.
  ///
  /// Each entry in the returned list is a map with the following stable keys:
  /// - `name` — flavor name
  /// - `valid` — `true` if validation passed
  /// - `errors` — list of error message strings (empty when valid)
  ///
  /// This method is the data source for `validate --output json`.  For
  /// human-readable output, use [validateConfigurations] instead.
  ///
  /// Unlike [validateConfigurations], this method does **not** abort on the
  /// first invalid flavor — it processes every flavor and collects all results.
  Future<List<Map<String, Object?>>> validateConfigurationsDetailed() async {
    // Use unchecked parse so that invalid flavors do not abort the loop.
    final configs = await configParser.parseConfigUnchecked(
      projectRoot,
      configPath: configPath,
    );

    final results = <Map<String, Object?>>[];

    for (final config in configs.values) {
      try {
        configParser.validateConfig(config);
        results.add({'name': config.name, 'valid': true, 'errors': <String>[]});
      } on FormatException catch (e) {
        results.add({
          'name': config.name,
          'valid': false,
          'errors': [e.message],
        });
      }
    }

    return results;
  }

  /// Validates all flavor configurations.
  ///
  /// Returns `true` if all configurations are valid, `false` otherwise.
  Future<bool> validateConfigurations() async {
    try {
      logger.section('Validating Configurations');

      final configs = await configParser.parseConfig(
        projectRoot,
        configPath: configPath,
      );

      if (configs.isEmpty) {
        logger.error('No configurations found');
        return false;
      }

      var allValid = true;

      for (final config in configs.values) {
        logger.info('Validating flavor: ${config.name}');

        try {
          configParser.validateConfig(config);
          _printValidationFeatureSummary(config);
          logger.success('✓ ${config.name} is valid');
        } on FormatException catch (e) {
          logger.error('✗ ${config.name} is invalid: ${e.message}');
          allValid = false;
        }
      }

      if (allValid) {
        logger
          ..section('Validation Complete')
          ..success('All configurations are valid!');
      } else {
        logger
          ..section('Validation Failed')
          ..error('Some configurations are invalid');
      }

      return allValid;
    } on FormatException {
      rethrow;
    } on FileSystemException {
      rethrow;
    }
  }

  /// Validates that the project root is a valid Flutter project.
  Future<bool> _validateProjectRoot() async {
    logger.debug('Validating project root...');

    // Check if pubspec.yaml exists
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      logger.error(
        'Not a valid Flutter project: pubspec.yaml not found in $projectRoot',
      );
      return false;
    }

    // Check if it's a Flutter project
    final pubspecContent = await pubspecFile.readAsString();
    if (!pubspecContent.contains('flutter:')) {
      logger.error(
        'Not a Flutter project: no flutter section in pubspec.yaml',
      );
      return false;
    }

    logger.debug('Project root validation passed');
    return true;
  }

  /// Prints detailed flavor configuration information.
  void _printFlavorConfig(FlavorConfig config) {
    logger
      ..info('Name: ${config.name}')
      ..info('Bundle ID: ${config.bundleId}')
      ..info('App Name: ${config.appName}');

    if (config.iconPath != null) {
      logger.info('Icon Path: ${config.iconPath}');
    }

    if (config.androidMinSdkVersion != null) {
      logger.info('Android Min SDK: ${config.androidMinSdkVersion}');
    }

    if (config.androidTargetSdkVersion != null) {
      logger.info('Android Target SDK: ${config.androidTargetSdkVersion}');
    }

    if (config.androidCompileSdkVersion != null) {
      logger.info('Android Compile SDK: ${config.androidCompileSdkVersion}');
    }

    if (config.iosMinVersion != null) {
      logger.info('iOS Min Version: ${config.iosMinVersion}');
    }

    if (config.metadata.isNotEmpty) {
      logger.info('Metadata:');
      for (final entry in config.metadata.entries) {
        logger.info('  ${entry.key}: ${entry.value}');
      }
    }

    if (config.assets.isNotEmpty) {
      logger.info('Assets:');
      for (final asset in config.assets) {
        logger.info('  - $asset');
      }
    }

    if (config.dependencies.isNotEmpty) {
      logger.info('Dependencies:');
      for (final entry in config.dependencies.entries) {
        logger.info('  ${entry.key}: ${entry.value}');
      }
    }

    if (config.provisioning != null) {
      logger.info('Provisioning:');
      if (config.provisioning!.androidGoogleServicesPath != null) {
        logger.info(
          '  Android: ${config.provisioning!.androidGoogleServicesPath}',
        );
      }
      if (config.provisioning!.iosGoogleServicePath != null) {
        logger.info(
          '  iOS: ${config.provisioning!.iosGoogleServicePath}',
        );
      }
    }

    logger.info('File mappings:');
    if (config.fileMappings.isEmpty) {
      logger.info('  none');
    } else {
      logger.info(
        '  ${config.fileMappings.length} mapping(s) '
        '(destination <- source):',
      );
      for (final mapping in config.fileMappings.entries) {
        logger.info('  ${mapping.key} <- ${mapping.value}');
      }
    }

    logger
      ..info(
        'replace_destination_directories: '
        '${config.replaceDestinationDirectories}',
      )
      ..info(
        '  Applies only to directory mappings in file_mappings. '
        'When true, existing destination directories are backed up and '
        'atomically replaced with automatic rollback on failure.',
      );
  }

  void _printFileMappingSummary(FlavorConfig config) {
    logger
      ..info('File mapping configuration:')
      ..info('  file_mappings: ${config.fileMappings.length} mapping(s)')
      ..info(
        '  replace_destination_directories: '
        '${config.replaceDestinationDirectories}',
      );

    if (config.fileMappings.isNotEmpty && verbose) {
      logger.info('  mapping details (destination <- source):');
      for (final mapping in config.fileMappings.entries) {
        logger.info('  ${mapping.key} <- ${mapping.value}');
      }
    }
  }

  void _printValidationFeatureSummary(FlavorConfig config) {
    logger
      ..info(
        '  file_mappings: ${config.fileMappings.length} mapping(s)',
      )
      ..info(
        '  replace_destination_directories: '
        '${config.replaceDestinationDirectories}',
      );

    if (config.replaceDestinationDirectories) {
      logger.info(
        '  directory replacement is enabled for directory '
        'entries in file_mappings',
      );
    }
  }

  /// Returns an [ExecutionPlan] describing the operations that would be
  /// performed to apply [flavorName] without mutating any files.
  ///
  /// [flavorName] is the name of the flavor to preview.
  /// [platforms] specifies which platforms to include in the plan
  /// ('android', 'ios', or both).
  ///
  /// The plan is built from the same pipeline used by [applyFlavor], so the
  /// output is guaranteed to match what a real apply would execute.
  Future<ExecutionPlan> planFlavor(
    String flavorName, {
    List<String> platforms = const ['android', 'ios'],
  }) async {
    final config = await configParser.parseFlavorConfig(
      projectRoot,
      flavorName,
      configPath: configPath,
    );
    return _buildExecutionPlan(config, platforms);
  }

  /// Restores project files from the most recent backup.
  ///
  /// Equivalent to `rollback --latest` on the CLI.
  ///
  /// If post-apply checksums are recorded and any current file was manually
  /// edited after the last apply, the rollback aborts and returns `false`
  /// unless [force] is `true`.
  ///
  /// Returns `true` on success, `false` if no backup is found or a conflict
  /// prevents the restore.
  Future<bool> rollbackLatest({bool force = false}) async {
    logger.section('Rollback — latest');

    final record = await backupManager.latestBackup();

    if (record == null) {
      logger.error(
        'No backups found. Run `apply` first to create a backup.',
      );
      return false;
    }

    return backupManager.restore(record, force: force);
  }

  /// Restores project files from the backup identified by [backupId].
  ///
  /// [backupId] is the unique identifier shown by `rollback --list`.
  ///
  /// Returns `true` on success, `false` if the backup is not found or a
  /// conflict prevents the restore.
  Future<bool> rollbackById(String backupId, {bool force = false}) async {
    logger.section('Rollback — id: $backupId');

    final all = await backupManager.listBackups();
    BackupRecord? record;
    for (final r in all) {
      if (r.id == backupId) {
        record = r;
        break;
      }
    }

    if (record == null) {
      logger.error('Backup not found: $backupId');
      return false;
    }

    return backupManager.restore(record, force: force);
  }

  /// Returns all available backups sorted newest-first.
  Future<List<BackupRecord>> listBackups() =>
      backupManager.listBackups();

  /// Builds an [ExecutionPlan] for [config] and [platforms] without
  /// executing any file system operations.
  ///
  /// This shared planning phase is the foundation for both the `apply`
  /// command (which executes the plan) and the `plan` command
  /// (which only previews operations).
  ///
  /// Platform-level operations (Android / iOS native file updates) are
  /// included as high-level descriptors; detailed sub-operations are
  /// resolved by the individual processors at execution time.
  Future<ExecutionPlan> _buildExecutionPlan(
    FlavorConfig config,
    List<String> platforms,
  ) async {
    final operations = <PlannedOperation>[];

    if (platforms.contains('android')) {
      operations.addAll(await _buildAndroidOperations(config));
    }

    if (platforms.contains('ios')) {
      operations.addAll(_buildIosOperations(config));
    }

    // File-mapping operations (shared asset processor planning)
    final assetOps = await assetProcessor.planFileMappings(config);
    operations.addAll(assetOps);

    return ExecutionPlan(
      flavorName: config.name,
      operations: operations,
      platforms: platforms,
    );
  }

  /// Returns high-level [PlannedOperation]s for Android native file updates.
  ///
  /// Detects whether the project uses `build.gradle.kts` (Kotlin DSL) or
  /// `build.gradle` (Groovy) so that the plan — and therefore the backup —
  /// references the file that will actually be modified.
  Future<List<PlannedOperation>> _buildAndroidOperations(
    FlavorConfig config,
  ) async {
    // Mirror the detection logic used by AndroidProcessor: prefer .kts
    final ktsFile =
        File('$projectRoot/android/app/build.gradle.kts');
    final gradleDestPath = await ktsFile.exists()
        ? 'android/app/build.gradle.kts'
        : 'android/app/build.gradle';

    final ops = <PlannedOperation>[
      const PlannedOperation(
        kind: OperationKind.writeFile,
        description: 'Update AndroidManifest.xml',
        destinationPath: 'android/app/src/main/AndroidManifest.xml',
        platform: ExecutionPlan.platformAndroid,
      ),
      PlannedOperation(
        kind: OperationKind.writeFile,
        description: 'Update build.gradle / build.gradle.kts',
        destinationPath: gradleDestPath,
        platform: ExecutionPlan.platformAndroid,
      ),
    ];

    if (config.provisioning?.androidGoogleServicesPath != null) {
      ops.add(
        PlannedOperation(
          kind: OperationKind.copyFile,
          description: 'Copy google-services.json',
          sourcePath: config.provisioning!.androidGoogleServicesPath,
          destinationPath: 'android/app/google-services.json',
          platform: ExecutionPlan.platformAndroid,
        ),
      );
    }

    return ops;
  }

  /// Returns high-level [PlannedOperation]s for iOS native file updates.
  List<PlannedOperation> _buildIosOperations(FlavorConfig config) {
    final ops = <PlannedOperation>[
      const PlannedOperation(
        kind: OperationKind.writeFile,
        description: 'Update Info.plist',
        destinationPath: 'ios/Runner/Info.plist',
        platform: ExecutionPlan.platformIos,
      ),
    ];

    if (config.provisioning?.iosGoogleServicePath != null) {
      ops.add(
        PlannedOperation(
          kind: OperationKind.copyFile,
          description: 'Copy GoogleService-Info.plist',
          sourcePath: config.provisioning!.iosGoogleServicePath,
          destinationPath: 'ios/Runner/GoogleService-Info.plist',
          platform: ExecutionPlan.platformIos,
        ),
      );
    }

    return ops;
  }
}
