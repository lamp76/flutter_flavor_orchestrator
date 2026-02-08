import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';

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
    final results = parser.parse(arguments);

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
  } on Exception catch (e) {
    stderr.writeln('Error: $e');
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
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Builds the argument parser for the 'validate' command.
ArgParser _buildValidateCommand() => ArgParser()
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
  final flavor = command['flavor'] as String;
  final platforms = command['platform'] as List<String>;
  final verbose = command['verbose'] as bool;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    verbose: verbose,
  );

  final success = await orchestrator.applyFlavor(
    flavor,
    platforms: platforms,
  );

  exit(success ? 0 : 1);
}

/// Handles the 'list' command.
Future<void> _handleListCommand(
  ArgResults command,
  String projectRoot,
) async {
  final verbose = command['verbose'] as bool;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    verbose: verbose,
  );

  final flavors = await orchestrator.listFlavors();
  exit(flavors.isNotEmpty ? 0 : 1);
}

/// Handles the 'info' command.
Future<void> _handleInfoCommand(
  ArgResults command,
  String projectRoot,
) async {
  final flavor = command['flavor'] as String;
  final verbose = command['verbose'] as bool;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    verbose: verbose,
  );

  await orchestrator.showFlavorInfo(flavor);
  exit(0);
}

/// Handles the 'validate' command.
Future<void> _handleValidateCommand(
  ArgResults command,
  String projectRoot,
) async {
  final verbose = command['verbose'] as bool;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    verbose: verbose,
  );

  final valid = await orchestrator.validateConfigurations();
  exit(valid ? 0 : 1);
}

/// Prints usage information.
void _printUsage(ArgParser parser) {
  stdout.writeln('''
Flutter Flavor Orchestrator - Build-time configuration manager

A powerful CLI tool for managing Flutter flavor configurations across
Android and iOS platforms.

USAGE:
  flutter_flavor_orchestrator <command> [options]

COMMANDS:
  apply       Apply a flavor configuration to the project
  list        List all available flavors
  info        Display detailed information about a flavor
  validate    Validate all flavor configurations

GLOBAL OPTIONS:
${parser.usage}

EXAMPLES:
  # Apply a flavor configuration
  flutter_flavor_orchestrator apply --flavor dev

  # Apply only to Android
  flutter_flavor_orchestrator apply --flavor production --platform android

  # List available flavors
  flutter_flavor_orchestrator list

  # Show detailed flavor information
  flutter_flavor_orchestrator info --flavor staging

  # Validate all configurations
  flutter_flavor_orchestrator validate

For more information, visit:
https://github.com/alessiolm/flutter_flavor_orchestrator
''');
}

/// Prints version information.
void _printVersion() {
  stdout.writeln('Flutter Flavor Orchestrator v0.1.0');
}
