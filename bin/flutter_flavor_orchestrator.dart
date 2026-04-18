import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';

const _externalConfigHelp = 'Path to an external YAML config file '
    '(absolute or relative to project root).';
const _outputHelp = 'Output format: text (default) or json.';

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
    ..addCommand('plan', _buildPlanCommand())
    ..addCommand('rollback', _buildRollbackCommand())
    ..addCommand('doctor', _buildDoctorCommand())
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
        } else if (arguments.isNotEmpty && arguments.first == 'plan') {
          stderr.writeln(
            'Usage: flutter_flavor_orchestrator plan --flavor <name>',
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
      case 'plan':
        await _handlePlanCommand(command, projectRoot);
      case 'rollback':
        await _handleRollbackCommand(command, projectRoot);
      case 'doctor':
        await _handleDoctorCommand(command, projectRoot);
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
    'dry-run',
    abbr: 'd',
    negatable: false,
    help: 'Execute checks without modifying files.',
  )
  ..addFlag(
    'force',
    negatable: false,
    help: 'Override conflict-detection guardrails and apply anyway.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: _outputHelp,
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
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: _outputHelp,
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
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: _outputHelp,
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Builds the argument parser for the 'plan' command.
ArgParser _buildPlanCommand() => ArgParser()
  ..addOption(
    'flavor',
    abbr: 'f',
    mandatory: true,
    help: 'The flavor to preview (e.g., dev, staging, production).',
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
    help: 'Target platform(s) to include in the plan.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: 'Output format: text (default) or json.',
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
    'strict',
    negatable: false,
    help: 'Enable strict schema validation: fail on missing schema_version '
        'and on unknown or deprecated keys.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: _outputHelp,
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose debug output.',
  );

/// Builds the argument parser for the 'rollback' command.
ArgParser _buildRollbackCommand() => ArgParser()
  ..addFlag(
    'latest',
    negatable: false,
    help: 'Restore from the most recent backup (default behaviour).',
  )
  ..addOption(
    'id',
    help: 'Restore from the backup with this identifier.',
  )
  ..addFlag(
    'force',
    negatable: false,
    help:
        'Override checksum conflicts caused by manual edits after apply.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: _outputHelp,
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
  final dryRun = command['dry-run'] as bool;
  final force = command['force'] as bool;
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
    silent: isJson,
  );

  try {
    if (isJson) {
      final result = await orchestrator.applyFlavorDetailed(
        flavor,
        platforms: platforms,
        dryRun: dryRun,
        force: force,
      );
      formatterFor(outputFormat)({'command': 'apply', ...result});
      exit((result['success'] as bool) ? 0 : 1);
    } else {
      final success = await orchestrator.applyFlavor(
        flavor,
        platforms: platforms,
        dryRun: dryRun,
        force: force,
      );
      exit(success ? 0 : 1);
    }
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
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
    silent: isJson,
  );

  try {
    if (isJson) {
      // In JSON mode collect rich per-flavor data and write a single payload.
      final configs = await orchestrator.configParser.parseConfig(
        projectRoot,
        configPath: configPath,
      );
      final flavors = (configs.keys.toList()..sort())
          .map(
            (name) => {
              'name': name,
              'file_mappings_count': configs[name]!.fileMappings.length,
              'replace_destination_directories':
                  configs[name]!.replaceDestinationDirectories,
            },
          )
          .toList();
      formatterFor(outputFormat)({
        'command': 'list',
        'count': flavors.length,
        'flavors': flavors,
      });
      exit(flavors.isNotEmpty ? 0 : 1);
    } else {
      final flavors = await orchestrator.listFlavors();
      exit(flavors.isNotEmpty ? 0 : 1);
    }
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
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
    silent: isJson,
  );

  try {
    if (isJson) {
      final config = await orchestrator.getFlavorInfo(flavor);
      formatterFor(outputFormat)({
        'command': 'info',
        'flavor': config.toJson(),
      });
    } else {
      await orchestrator.showFlavorInfo(flavor);
    }
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
  final strict = command['strict'] as bool;
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
    silent: isJson,
  );

  try {
    if (isJson) {
      final schemaVersion = await orchestrator.getSchemaVersion();
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: strict);
      final allValid = results.isNotEmpty &&
          results.every((r) => r['valid'] as bool);
      formatterFor(outputFormat)({
        'command': 'validate',
        'valid': allValid,
        'schema_version': schemaVersion,
        'strict': strict,
        'flavors': results,
      });
      exit(allValid ? 0 : 1);
    } else {
      final valid =
          await orchestrator.validateConfigurations(strict: strict);
      exit(valid ? 0 : 1);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Handles the 'rollback' command.
Future<void> _handleRollbackCommand(
  ArgResults command,
  String projectRoot,
) async {
  final verbose = command['verbose'] as bool;
  final force = command['force'] as bool;
  final id = command['id'] as String?;
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    verbose: verbose,
    silent: isJson,
  );

  try {
    if (isJson) {
      // Resolve the backup record first so we can include its metadata in the
      // JSON payload regardless of success or failure.
      BackupRecord? record;
      if (id != null && id.isNotEmpty) {
        final all = await orchestrator.listBackups();
        for (final r in all) {
          if (r.id == id) {
            record = r;
            break;
          }
        }
      } else {
        record = await orchestrator.backupManager.latestBackup();
      }

      if (record == null) {
        formatterFor(outputFormat)({
          'command': 'rollback',
          'success': false,
          'error': id != null
              ? 'Backup not found: $id'
              : 'No backups found. Run `apply` first to create a backup.',
        });
        exit(1);
      }

      final success = await orchestrator.backupManager.restore(
        record,
        force: force,
      );
      formatterFor(outputFormat)({
        'command': 'rollback',
        'success': success,
        'backup_id': record.id,
        'flavor': record.flavorName,
        'files_restored': record.entries.length,
        'new_paths_removed': record.newPaths.length,
      });
      exit(success ? 0 : 1);
    } else {
      final bool success;
      if (id != null && id.isNotEmpty) {
        success = await orchestrator.rollbackById(id, force: force);
      } else {
        success = await orchestrator.rollbackLatest(force: force);
      }
      exit(success ? 0 : 1);
    }
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Handles the 'plan' command.
Future<void> _handlePlanCommand(
  ArgResults command,
  String projectRoot,
) async {
  final flavor = command['flavor'] as String?;

  if (flavor == null || flavor.isEmpty) {
    stderr
      ..writeln('Error: --flavor argument is required')
      ..writeln()
      ..writeln('Usage: flutter_flavor_orchestrator plan --flavor <name>');
    exit(1);
  }

  final platforms = command['platform'] as List<String>;
  final verbose = command['verbose'] as bool;
  final configPath = command['config'] as String?;
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
    silent: isJson,
  );

  try {
    final plan = await orchestrator.planFlavor(
      flavor,
      platforms: platforms,
    );

    if (isJson) {
      stdout.writeln(jsonEncode(plan.toJson()));
    } else {
      _printPlanText(plan);
    }

    exit(0);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Builds the argument parser for the 'doctor' command.
ArgParser _buildDoctorCommand() => ArgParser()
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
    help: 'Target platform(s) to check.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    allowed: ['text', 'json'],
    defaultsTo: 'text',
    help: _outputHelp,
  )
  ..addFlag(
    'verbose',
    negatable: false,
    help: 'Enable verbose output.',
  )
  ..addFlag(
    'debug',
    negatable: false,
    help: 'Enable debug logging for each check step.',
  );

/// Handles the 'doctor' command.
Future<void> _handleDoctorCommand(
  ArgResults command,
  String projectRoot,
) async {
  final verbose = command['verbose'] as bool;
  final debug = command['debug'] as bool;
  final configPath = command['config'] as String?;
  final platforms = command['platform'] as List<String>;
  final outputFormat = parseOutputFormat(command['output'] as String);
  final isJson = outputFormat == OutputFormat.json;

  final orchestrator = FlavorOrchestrator(
    projectRoot: projectRoot,
    configPath: configPath,
    verbose: verbose,
    silent: isJson,
  );

  try {
    final result = await orchestrator.runDoctor(
      platforms: platforms,
      debug: debug,
    );

    if (isJson) {
      formatterFor(outputFormat)({'command': 'doctor', ...result.toJson()});
    } else {
      _printDoctorText(result);
    }

    exit(result.hasErrors ? 1 : 0);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

/// Prints a human-readable doctor report to stdout.
void _printDoctorText(DoctorResult result) {
  final icon = result.hasErrors ? '❌' : '✅';
  final status = result.hasErrors ? 'Issues detected' : 'Healthy';
  stdout
    ..writeln()
    ..writeln('${'=' * 60}')
    ..writeln('  Doctor Report')
    ..writeln('${'=' * 60}')
    ..writeln();

  if (result.diagnostics.isEmpty) {
    stdout.writeln('$icon  $status — no findings.');
  } else {
    for (final d in result.diagnostics) {
      final severityIcon = switch (d.severity) {
        DiagnosticSeverity.error => '❌',
        DiagnosticSeverity.warning => '⚠️ ',
        DiagnosticSeverity.info => 'ℹ️ ',
      };
      stdout.writeln('$severityIcon  [${d.code}] ${d.message}');
      if (d.path != null) {
        stdout.writeln('     Path: ${d.path}');
      }
      if (d.suggestion != null) {
        stdout.writeln('     Fix:  ${d.suggestion}');
      }
      stdout.writeln();
    }
    stdout.writeln(
      'Summary: ${result.errors.length} error(s), '
      '${result.warnings.length} warning(s), '
      '${result.infos.length} info(s).',
    );
    stdout.writeln('Status:  $icon  $status');
  }
  stdout.writeln();
}

/// Prints a human-readable plan summary to stdout.
void _printPlanText(ExecutionPlan plan) {
  stdout
    ..writeln('Execution Plan — flavor: ${plan.flavorName}')
    ..writeln('Platforms: ${plan.platforms.join(', ')}')
    ..writeln(
      'Operations: ${plan.activeOperations} active, '
      '${plan.skippedOperations} skipped '
      '(${plan.totalOperations} total)',
    )
    ..writeln();

  for (final platform in [...plan.platforms, ExecutionPlan.platformAssets]) {
    final ops = plan.forPlatform(platform);
    if (ops.isEmpty) {
      continue;
    }

    stdout.writeln('[$platform]');
    for (final op in ops) {
      final paths = _formatOpPaths(op.sourcePath, op.destinationPath);
      stdout.writeln('  [${op.kind.name}] ${op.description}$paths');
    }
    stdout.writeln();
  }
}

/// Returns a compact path suffix for a planned operation.
///
/// - Both paths present: `: src → dst`
/// - Destination only:  ` → dst`
/// - Source only:       `: src`
/// - Neither:           `''`
String _formatOpPaths(String? src, String? dst) {
  if (src != null && dst != null) {
    return ': $src → $dst';
  }
  if (dst != null) {
    return ' → $dst';
  }
  if (src != null) {
    return ': $src';
  }
  return '';
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
  plan        Preview the operations that would be performed for a flavor
  rollback    Restore files from the most recent (or a specific) backup
  list        List all available flavors with mapping/replacement summary
  info        Display detailed flavor info, mappings, and replacement behavior
  validate    Validate all flavor configurations and mapping-related settings
  doctor      Run preflight diagnostics and check the project setup

GLOBAL OPTIONS:
${parser.usage}

EXAMPLES:
  # Apply a flavor configuration
  flutter_flavor_orchestrator apply --flavor dev

  # Apply using an external YAML config file
  flutter_flavor_orchestrator apply \
    --flavor production --config /secure/jenkins/flavor_config.yaml

  # Apply only to Android
  flutter_flavor_orchestrator apply --flavor production --platform android

  # Validate an apply run without changing files
  flutter_flavor_orchestrator apply --flavor dev --dry-run

  # Override conflict guardrails and apply anyway
  flutter_flavor_orchestrator apply --flavor dev --force

  # Apply and get machine-readable JSON result
  flutter_flavor_orchestrator apply --flavor dev --output json

  # Preview operations without mutating files
  flutter_flavor_orchestrator plan --flavor dev

  # Preview as JSON
  flutter_flavor_orchestrator plan --flavor dev --output json

  # Preview Android-only plan
  flutter_flavor_orchestrator plan --flavor staging --platform android

  # Rollback to the most recent backup
  flutter_flavor_orchestrator rollback --latest

  # Rollback to a specific backup (use the ID shown in the backup log)
  flutter_flavor_orchestrator rollback --id 20260225_194640123_dev

  # Force rollback even if files were manually edited after the last apply
  flutter_flavor_orchestrator rollback --latest --force

  # List available flavors
  flutter_flavor_orchestrator list

  # List flavors as machine-readable JSON
  flutter_flavor_orchestrator list --output json

  # Show detailed flavor information
  flutter_flavor_orchestrator info --flavor staging

  # Show flavor information as JSON
  flutter_flavor_orchestrator info --flavor staging --output json

  # Show file mapping details and replacement mode for a flavor
  flutter_flavor_orchestrator info --flavor dev

  # Validate all configurations
  flutter_flavor_orchestrator validate

  # Strict schema validation (fails on missing schema_version or unknown keys)
  flutter_flavor_orchestrator validate --strict

  # Validate and emit machine-readable JSON result
  flutter_flavor_orchestrator validate --output json

  # Validate with strict schema checking and JSON output
  flutter_flavor_orchestrator validate --strict --output json

  # Validate using an external YAML config file
  flutter_flavor_orchestrator validate \
    --config /secure/jenkins/flavor_config.yaml

  # Rollback and get JSON result
  flutter_flavor_orchestrator rollback --latest --output json

  # Run preflight diagnostics
  flutter_flavor_orchestrator doctor

  # Run diagnostics for Android only
  flutter_flavor_orchestrator doctor --platform android

  # Run diagnostics and get machine-readable JSON result
  flutter_flavor_orchestrator doctor --output json

  # Run diagnostics with an external config path
  flutter_flavor_orchestrator doctor --config ./ci/flavor_config.yaml

  # Run diagnostics with step-level debug logging
  flutter_flavor_orchestrator doctor --debug

For more information, visit:
https://github.com/lamp76/flutter_flavor_orchestrator
''');
}

/// Prints version information.
void _printVersion() {
  stdout.writeln('Flutter Flavor Orchestrator v0.9.0');
}
