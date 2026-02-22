import 'dart:io';
import 'config_parser.dart';
import 'models/flavor_config.dart';
import 'processors/android_processor.dart';
import 'processors/asset_processor.dart';
import 'processors/ios_processor.dart';
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
  FlavorOrchestrator({
    required this.projectRoot,
    this.configPath,
    this.verbose = false,
  })  : logger = Logger(verbose: verbose),
        fileManager = FileManager(logger: Logger(verbose: verbose)) {
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
  }

  /// Root directory of the Flutter project.
  final String projectRoot;

  /// Optional external path to flavor configuration YAML file.
  final String? configPath;

  /// Whether to show verbose debug output.
  final bool verbose;

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

  /// Applies a flavor configuration to the project.
  ///
  /// [flavorName] is the name of the flavor to apply.
  /// [platforms] specifies which platforms to process
  /// ('android', 'ios', or both).
  ///
  /// Returns `true` if the operation succeeds, `false` otherwise.
  Future<bool> applyFlavor(
    String flavorName, {
    List<String> platforms = const ['android', 'ios'],
    bool dryRun = false,
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
}
