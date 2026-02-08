import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'models/flavor_config.dart';
import 'utils/logger.dart';

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
  ///
  /// Returns a map of flavor names to [FlavorConfig] instances.
  ///
  /// Throws [FormatException] if the YAML is invalid.
  /// Throws [FileSystemException] if no configuration file is found.
  Future<Map<String, FlavorConfig>> parseConfig(String projectRoot) async {
    logger.debug('Parsing flavor configuration from: $projectRoot');

    // Try dedicated flavor_config.yaml first
    final flavorConfigPath = path.join(projectRoot, 'flavor_config.yaml');
    final flavorConfigFile = File(flavorConfigPath);

    Map<dynamic, dynamic> configYaml;

    if (await flavorConfigFile.exists()) {
      logger.debug('Found flavor_config.yaml');
      final content = await flavorConfigFile.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      configYaml = _extractFlavorConfig(yaml);
    } else {
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

      configYaml = _extractFlavorConfig(yaml);
    }

    return _parseFlavorConfigs(configYaml);
  }

  /// Parses a specific flavor configuration from a YAML file.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [flavorName] is the name of the flavor to parse.
  ///
  /// Returns a [FlavorConfig] instance for the specified flavor.
  ///
  /// Throws [FormatException] if the flavor is not found.
  Future<FlavorConfig> parseFlavorConfig(
    String projectRoot,
    String flavorName,
  ) async {
    logger.debug('Parsing flavor configuration for: $flavorName');

    final allConfigs = await parseConfig(projectRoot);

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
  Future<List<String>> getAvailableFlavors(String projectRoot) async {
    final configs = await parseConfig(projectRoot);
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

  /// Parses all flavor configurations from a YAML map.
  Map<String, FlavorConfig> _parseFlavorConfigs(
    Map<dynamic, dynamic> configYaml,
  ) {
    final configs = <String, FlavorConfig>{};

    for (final entry in configYaml.entries) {
      final flavorName = entry.key as String;
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
}
