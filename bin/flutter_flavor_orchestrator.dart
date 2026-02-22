import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';

const _externalConfigHelp = 'Path to an external YAML config file '
    '(absolute or relative to project root).';

/// CLI entry point for the Flutter Flavor Orchestrator.
///
/// Provides a command-line interface for managing Flutter flavor
/// configurations.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('apply', _buildApplyCommand())
    ..addCommand('list', _buildListCommand())
    ..addCommand('info', _buildInfoCommand())
    ..addCommand('validate', _buildValidateCommand())
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Display this help information.',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Display version information.',
    );

  try {
    late ArgResults results;
    try {
      results = parser.parse(arguments);
    } on Object catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('mandatory') || errorMsg.contains('required')) {
        stderr
          ..writeln('Error: $errorMsg')
          ..writeln();
        if (arguments.isNotEmpty && arguments.first == 'info') {
          stderr.writeln(
            'Usage: flutter_flavor_orchestrator info --flavor <name>',
          );
        } else if (arguments.isNotEmpty && arguments.first == 'apply') {
          stderr.writeln(
            'Usage: flutter_flavor_orchestrator apply --flavor <name>',
          );
        } else {
          _printUsage(parser);
        }
      } else {
        stderr
          ..writeln('Invalid arguments: $errorMsg')
          ..writeln();
        _printUsage(parser);
      }
      exit(1);
    }

    if (results['help'] as bool) {
      _printUsage(parser);
      exit(0);
    }

    if (results['version'] as bool) {
      _printVersion();
      exit(0);
    }

    if (results.command == null) {
      _printUsage(parser);
      exit(1);
    }

    final command = results.command!;
    final projectRoot = Directory.current.path;

    switch (command.name) {
      case 'apply':
        await _handleApplyCommand(command, projectRoot);
      case 'list':
        await _handleListCommand(command, projectRoot);
      case 'info':
        await _handleInfoCommand(command, projectRoot);
      case 'validate':
        await _handleValidateCommand(command, projectRoot);
      default:
        stderr.writeln('Unknown command: ${command.name}');
        exit(1);
    }
  } on Object catch (e) {
    // Unexpected error that wasn't handled by command handlers
    stderr.writeln('Unexpected error: $e');
    exit(1);
  }
}

/// Builds the argument parser for the 'apply' command.
ArgParser _buildApplyCommand() => ArgParser()
  ..addOption(
    'flavor',
    abbr: 'f',
    mandatory: true,
    help: 'The flavor to apply (e.g., dev, staging, production).',
  )
  ..addOption(
    'config',
    abbr: 'c',
    help: _externalConfigHelp,
  )
  ..addMultiOption(
    'platform',
    abbr: 'p',
    allowed: ['android', 'ios'],
    defaultsTo: ['android', 'ios'],
    help: 'Target platform(s) to process.',
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Builds the argument parser for the 'list' command.
ArgParser _buildListCommand() => ArgParser()
  ..addOption(
    'config',
    abbr: 'c',
    help: _externalConfigHelp,
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Builds the argument parser for the 'info' command.
ArgParser _buildInfoCommand() => ArgParser()
  ..addOption(
    'flavor',
    abbr: 'f',
    mandatory: true,
    help: 'The flavor to display information for.',
  )
  ..addOption(
    'config',
    abbr: 'c',
    help: _externalConfigHelp,
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Builds the argument parser for the 'validate' command.
ArgParser _buildValidateCommand() => ArgParser()
  ..addOption(
    'config',
    abbr: 'c',
    help: _externalConfigHelp,
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Handles the 'apply' command.
Future<void> _handleApplyCommand(
  ArgResults command,
  String projectRoot,
) async {
  final flavor = command['flavor'] as String?;

  if (flavor == null || flavor.isEmpty) {
    stderr
      ..writeln('Error: --flavor argument is required')
      ..writeln()
      ..writeln('Usage: flutter_flavor_orchestrator apply --flavor <name>');
    exit(1);
  }

  final platforms = command['platform'] as List<String>;
  final verbose = command['verbose'] as bool;
  final configPath = command['config'] as String?;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
  );

  try {
    final success = await orchestrator.applyFlavor(
      flavor,
      platforms: platforms,
    );
    exit(success ? 0 : 1);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Handles the 'list' command.
Future<void> _handleListCommand(
  ArgResults command,
  String projectRoot,
) async {
  final verbose = command['verbose'] as bool;
  final configPath = command['config'] as String?;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
  );

  try {
    final flavors = await orchestrator.listFlavors();
    exit(flavors.isNotEmpty ? 0 : 1);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Handles the 'info' command.
Future<void> _handleInfoCommand(
  ArgResults command,
  String projectRoot,
) async {
  final flavor = command['flavor'] as String?;

  if (flavor == null || flavor.isEmpty) {
    stderr
      ..writeln('Error: --flavor argument is required')
      ..writeln()
      ..writeln('Usage: flutter_flavor_orchestrator info --flavor <name>');
    exit(1);
  }

  final verbose = command['verbose'] as bool;
  final configPath = command['config'] as String?;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
  );

  try {
    await orchestrator.showFlavorInfo(flavor);
    exit(0);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Handles the 'validate' command.
Future<void> _handleValidateCommand(
  ArgResults command,
  String projectRoot,
) async {
  final verbose = command['verbose'] as bool;
  final configPath = command['config'] as String?;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
  );

  try {
    final valid = await orchestrator.validateConfigurations();
    exit(valid ? 0 : 1);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Prints usage information.
void _printUsage(ArgParser parser) {
  stdout.writeln('''
Flutter Flavor Orchestrator - Build-time configuration manager

A CLI tool for managing Flutter flavor configurations across Android
and iOS platforms, including file mappings and safe directory replacement.

USAGE:
  flutter_flavor_orchestrator <command> [options]

COMMANDS:
  apply       Apply a flavor configuration (includes file_mappings processing)
  list        List all available flavors with mapping/replacement summary
  info        Display detailed flavor info, mappings, and replacement behavior
  validate    Validate all flavor configurations and mapping-related settings

GLOBAL OPTIONS:
${parser.usage}

EXAMPLES:
  # Apply a flavor configuration
  flutter_flavor_orchestrator apply --flavor dev

  # Apply using an external YAML config file
  flutter_flavor_orchestrator apply --flavor production --config /secure/jenkins/flavor_config.yaml

  # Apply only to Android
  flutter_flavor_orchestrator apply --flavor production --platform android

  # List available flavors
  flutter_flavor_orchestrator list

  # Show detailed flavor information
  flutter_flavor_orchestrator info --flavor staging

  # Show file mapping details and replacement mode for a flavor
  flutter_flavor_orchestrator info --flavor dev

  # Validate all configurations
  flutter_flavor_orchestrator validate

  # Validate using an external YAML config file
  flutter_flavor_orchestrator validate --config /secure/jenkins/flavor_config.yaml

For more information, visit:
https://github.com/alessiolm/flutter_flavor_orchestrator
''');
}

/// Prints version information.
void _printVersion() {
  stdout.writeln('Flutter Flavor Orchestrator v0.1.9');
}
