import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';
import 'package:test/test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a minimal valid Flutter project in [dir] with the supplied
/// [configYaml] written to `flavor_config.yaml`.
Future<void> _setupProject(Directory dir, String configYaml) async {
  await File('${dir.path}/pubspec.yaml').writeAsString(
    'name: test_app\nflutter:\n  uses-material-design: true\n',
  );
  await File('${dir.path}/flavor_config.yaml').writeAsString(configYaml);
}

/// Minimal valid flavor YAML without schema_version.
const _validFlavorNoSchema = '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''';

/// Minimal valid flavor YAML WITH schema_version: 1.
const _validFlavorWithSchema = '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('schema_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SchemaValidator — unit tests
  // ───────────────────────────────────────────────────────────────────────────

  group('SchemaValidator', () {
    // ── schema_version presence ──────────────────────────────────────────────

    group('schema_version', () {
      test('non-strict: missing schema_version produces global warning', () {
        final result = SchemaValidator.validate(
          {'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'}},
          null,
        );

        expect(result.isValid, isTrue);
        expect(result.globalWarnings, isNotEmpty);
        expect(
          result.globalWarnings.first,
          contains('schema_version'),
        );
        expect(result.globalErrors, isEmpty);
      });

      test('strict: missing schema_version produces global error', () {
        final result = SchemaValidator.validate(
          {'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'}},
          null,
          strict: true,
        );

        expect(result.isValid, isFalse);
        expect(result.globalErrors, isNotEmpty);
        expect(result.globalErrors.first, contains('schema_version'));
        expect(result.globalWarnings, isEmpty);
      });

      test('non-strict: present schema_version produces no warnings', () {
        final result = SchemaValidator.validate(
          {'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'}},
          1,
        );

        expect(result.globalWarnings, isEmpty);
        expect(result.globalErrors, isEmpty);
      });

      test('strict: present schema_version produces no errors', () {
        final result = SchemaValidator.validate(
          {'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'}},
          1,
          strict: true,
        );

        expect(result.isValid, isTrue);
        expect(result.globalErrors, isEmpty);
      });

      test('result stores schemaVersion', () {
        final result = SchemaValidator.validate({}, 1);
        expect(result.schemaVersion, equals(1));
      });

      test('result stores null schemaVersion when absent', () {
        final result = SchemaValidator.validate({}, null);
        expect(result.schemaVersion, isNull);
      });
    });

    // ── unknown key detection ────────────────────────────────────────────────

    group('unknown keys', () {
      test('non-strict: unknown flavor key produces per-flavor warning', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'typo_key': 'oops',
            },
          },
          1,
        );

        expect(result.isValid, isTrue);
        final warnings = result.warningsForFlavor('dev');
        expect(warnings, isNotEmpty);
        expect(warnings.first, contains('flavors.dev.typo_key'));
      });

      test('strict: unknown flavor key produces per-flavor error', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'typo_key': 'oops',
            },
          },
          1,
          strict: true,
        );

        expect(result.isValid, isFalse);
        final errors = result.errorsForFlavor('dev');
        expect(errors, isNotEmpty);
        expect(errors.first, contains('flavors.dev.typo_key'));
      });

      test('error message includes actionable key path', () {
        final result = SchemaValidator.validate(
          {
            'myflav': {
              'bundle_id': 'com.example.myflav',
              'app_name': 'MyFlav',
              'bad_key': 'value',
            },
          },
          1,
          strict: true,
        );

        final errors = result.errorsForFlavor('myflav');
        expect(errors, isNotEmpty);
        // Key path must follow the format: flavors.<flavor>.<key>
        expect(errors.first, contains('flavors.myflav.bad_key'));
      });

      test('known flavor keys produce no warnings', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'icon_path': 'assets/icons/dev',
              'metadata': {'API_URL': 'https://dev.example.com'},
              'assets': ['assets/dev/'],
              'dependencies': {'some_pkg': '1.0.0'},
              'android_min_sdk_version': 21,
              'android_target_sdk_version': 33,
              'android_compile_sdk_version': 33,
              'ios_min_version': '12.0',
              'custom_gradle_config': {'key': 'val'},
              'custom_info_plist_entries': {'KEY': 'VAL'},
              'file_mappings': {'lib/a.dart': 'src/a.dart'},
              'replace_destination_directories': false,
            },
          },
          1,
          strict: true,
        );

        expect(result.isValid, isTrue);
        expect(result.errorsForFlavor('dev'), isEmpty);
        expect(result.warningsForFlavor('dev'), isEmpty);
      });

      test('unknown keys detected across multiple flavors independently', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'bad_dev_key': 'x',
            },
            'staging': {
              'bundle_id': 'com.example.staging',
              'app_name': 'Staging',
            },
          },
          1,
          strict: true,
        );

        expect(result.errorsForFlavor('dev'), isNotEmpty);
        expect(result.errorsForFlavor('staging'), isEmpty);
      });
    });

    // ── provisioning sub-key detection ───────────────────────────────────────

    group('provisioning sub-keys', () {
      test('non-strict: unknown provisioning key produces warning', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'provisioning': {
                'android_google_services': 'path/to/services.json',
                'unknown_provision_key': 'bad',
              },
            },
          },
          1,
        );

        expect(result.isValid, isTrue);
        final warnings = result.warningsForFlavor('dev');
        expect(warnings, isNotEmpty);
        expect(
          warnings.first,
          contains('flavors.dev.provisioning.unknown_provision_key'),
        );
      });

      test('strict: unknown provisioning key produces error', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'provisioning': {
                'ios_google_service': 'path/to/plist',
                'rogue_key': 'bad',
              },
            },
          },
          1,
          strict: true,
        );

        expect(result.isValid, isFalse);
        final errors = result.errorsForFlavor('dev');
        expect(errors, isNotEmpty);
        expect(
          errors.first,
          contains('flavors.dev.provisioning.rogue_key'),
        );
      });

      test('known provisioning keys produce no issues', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'provisioning': {
                'android_google_services': 'path/android',
                'ios_google_service': 'path/ios',
                'additional_files': <String, String>{},
              },
            },
          },
          1,
          strict: true,
        );

        expect(result.isValid, isTrue);
        expect(result.errorsForFlavor('dev'), isEmpty);
        expect(result.warningsForFlavor('dev'), isEmpty);
      });
    });

    // ── SchemaValidationResult helpers ───────────────────────────────────────

    group('SchemaValidationResult', () {
      test('errorsForFlavor returns empty list for unknown flavor', () {
        final result = SchemaValidator.validate({'dev': {}}, 1, strict: true);
        expect(result.errorsForFlavor('nonexistent'), isEmpty);
      });

      test('warningsForFlavor returns empty list for unknown flavor', () {
        final result = SchemaValidator.validate({'dev': {}}, null);
        expect(result.warningsForFlavor('nonexistent'), isEmpty);
      });

      test('hasWarnings is true when globalWarnings present', () {
        final result = SchemaValidator.validate({'dev': {}}, null);
        expect(result.hasWarnings, isTrue);
      });

      test('hasWarnings is false when no warnings', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
            },
          },
          1,
        );
        expect(result.hasWarnings, isFalse);
      });

      test('isValid is false when flavorErrors present in strict mode', () {
        final result = SchemaValidator.validate(
          {
            'dev': {
              'bundle_id': 'com.example.dev',
              'app_name': 'Dev',
              'bad_key': 'val',
            },
          },
          1,
          strict: true,
        );
        expect(result.isValid, isFalse);
      });
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SchemaMigration scaffold
  // ───────────────────────────────────────────────────────────────────────────

  group('SchemaMigrations', () {
    test('registered list is non-empty', () {
      expect(SchemaMigrations.registered, isNotEmpty);
    });

    test('v1 no-op migration exists', () {
      final noOp =
          SchemaMigrations.registered.where((m) => m.fromVersion == 1);
      expect(noOp, isNotEmpty);
    });

    test('applyMigrations with fromVersion=1 returns same map', () {
      final raw = <dynamic, dynamic>{
        'schema_version': 1,
        'dev': {
          'bundle_id': 'com.example.dev',
          'app_name': 'Dev',
        },
      };

      final (migratedMap, finalVersion) =
          SchemaMigrations.applyMigrations(raw, fromVersion: 1);

      expect(finalVersion, equals(1));
      expect(migratedMap, same(raw));
    });

    test('applyMigrations returns input unchanged for unknown fromVersion', () {
      final raw = <dynamic, dynamic>{
        'schema_version': 99,
        'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'},
      };

      final (migratedMap, finalVersion) =
          SchemaMigrations.applyMigrations(raw, fromVersion: 99);

      expect(finalVersion, equals(99));
      expect(migratedMap, same(raw));
    });

    test('no-op migration fromVersion == toVersion', () {
      final migration =
          SchemaMigrations.registered.where((m) => m.fromVersion == 1).first;
      expect(migration.toVersion, equals(migration.fromVersion));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ConfigParser — schema integration
  // ───────────────────────────────────────────────────────────────────────────

  group('ConfigParser — schema_version', () {
    late ConfigParser parser;

    setUp(() {
      parser = ConfigParser(logger: const Logger());
    });

    test('extractSchemaVersion returns null when key absent', () {
      final rawMap = <dynamic, dynamic>{
        'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'},
      };
      expect(parser.extractSchemaVersion(rawMap), isNull);
    });

    test('extractSchemaVersion returns integer value', () {
      final rawMap = <dynamic, dynamic>{
        'schema_version': 1,
        'dev': {'bundle_id': 'com.example.dev', 'app_name': 'Dev'},
      };
      expect(parser.extractSchemaVersion(rawMap), equals(1));
    });

    test('parseSchemaVersion returns 1 from file with schema_version: 1',
        () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final version =
          await parser.parseSchemaVersion(tempDir.path);
      expect(version, equals(1));
    });

    test('parseSchemaVersion returns null from file without schema_version',
        () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final version = await parser.parseSchemaVersion(tempDir.path);
      expect(version, isNull);
    });

    test('parseConfig skips schema_version key (no type error)', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final configs = await parser.parseConfig(tempDir.path);

      expect(configs, hasLength(1));
      expect(configs.containsKey('dev'), isTrue);
      // schema_version must NOT appear as a flavor name
      expect(configs.containsKey('schema_version'), isFalse);
    });

    test('parseConfigUnchecked skips schema_version key', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final configs = await parser.parseConfigUnchecked(tempDir.path);

      expect(configs, hasLength(1));
      expect(configs.containsKey('dev'), isTrue);
      expect(configs.containsKey('schema_version'), isFalse);
    });

    test('validateSchema non-strict: no errors for valid config', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final result = await parser.validateSchema(tempDir.path);

      expect(result.globalErrors, isEmpty);
      expect(result.globalWarnings, isEmpty);
      expect(result.isValid, isTrue);
    });

    test('validateSchema non-strict: warns when schema_version missing',
        () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final result = await parser.validateSchema(tempDir.path);

      expect(result.globalWarnings, isNotEmpty);
      expect(result.globalErrors, isEmpty);
      expect(result.isValid, isTrue);
    });

    test('validateSchema strict: errors when schema_version missing', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final result =
          await parser.validateSchema(tempDir.path, strict: true);

      expect(result.globalErrors, isNotEmpty);
      expect(result.isValid, isFalse);
    });

    test('validateSchema strict: unknown flavor key causes error', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: Dev
  unknown_custom_key: bad_value
''');
      final result =
          await parser.validateSchema(tempDir.path, strict: true);

      expect(result.isValid, isFalse);
      final errors = result.errorsForFlavor('dev');
      expect(errors, isNotEmpty);
      expect(errors.first, contains('flavors.dev.unknown_custom_key'));
    });

    test('validateSchema non-strict: unknown key is warning not error',
        () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: Dev
  unknown_custom_key: bad_value
''');
      final result = await parser.validateSchema(tempDir.path);

      expect(result.isValid, isTrue);
      final warnings = result.warningsForFlavor('dev');
      expect(warnings, isNotEmpty);
      expect(result.errorsForFlavor('dev'), isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FlavorOrchestrator — getSchemaVersion
  // ───────────────────────────────────────────────────────────────────────────

  group('FlavorOrchestrator.getSchemaVersion', () {
    test('returns 1 when schema_version: 1 present', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      expect(await orchestrator.getSchemaVersion(), equals(1));
    });

    test('returns null when schema_version absent', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      expect(await orchestrator.getSchemaVersion(), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FlavorOrchestrator.validateConfigurationsDetailed — strict mode
  // ───────────────────────────────────────────────────────────────────────────

  group('FlavorOrchestrator.validateConfigurationsDetailed — strict', () {
    test('strict: missing schema_version makes all flavors invalid', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);

      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r['valid'], isFalse,
            reason: 'Every flavor should be invalid when schema_version '
                'is missing in strict mode');
      }
    });

    test('non-strict: missing schema_version keeps flavors valid', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r['valid'], isTrue);
      }
    });

    test('non-strict: warnings present when schema_version missing', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      for (final r in results) {
        final warnings = r['warnings']! as List;
        expect(warnings, isNotEmpty);
      }
    });

    test('strict: unknown flavor key invalidates that flavor', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: Dev
  rogue_key: bad
staging:
  bundle_id: com.example.staging
  app_name: Staging
''');
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);

      final dev = results.firstWhere((r) => r['name'] == 'dev');
      final staging = results.firstWhere((r) => r['name'] == 'staging');

      expect(dev['valid'], isFalse);
      expect(staging['valid'], isTrue);

      final errors = dev['errors']! as List;
      expect(errors.any((e) => (e as String).contains('flavors.dev.rogue_key')),
          isTrue);
    });

    test('non-strict: unknown flavor key stays valid with warning', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: Dev
  rogue_key: bad
''');
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      final dev = results.first;
      expect(dev['valid'], isTrue);

      final warnings = dev['warnings']! as List;
      expect(
        warnings.any((w) => (w as String).contains('flavors.dev.rogue_key')),
        isTrue,
      );
    });

    test('each result has name, valid, errors, warnings keys', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);

      for (final r in results) {
        expect(r, contains('name'));
        expect(r, contains('valid'));
        expect(r, contains('errors'));
        expect(r, contains('warnings'));
      }
    });

    test('each result entry is JSON-encodable', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);

      for (final r in results) {
        expect(() => jsonEncode(r), returnsNormally);
      }
    });

    test('strict: valid config with schema_version passes cleanly', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);

      expect(results, hasLength(1));
      expect(results.first['valid'], isTrue);
      expect((results.first['errors']! as List), isEmpty);
      expect((results.first['warnings']! as List), isEmpty);
    });

    test('strict: provisioning unknown key invalidates flavor', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: Dev
  provisioning:
    android_google_services: configs/dev/google-services.json
    bad_provision_key: oops
''');
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);

      final dev = results.first;
      expect(dev['valid'], isFalse);
      final errors = dev['errors']! as List;
      expect(
        errors.any(
          (e) => (e as String).contains(
            'flavors.dev.provisioning.bad_provision_key',
          ),
        ),
        isTrue,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FlavorOrchestrator.validateConfigurations — strict mode (text)
  // ───────────────────────────────────────────────────────────────────────────

  group('FlavorOrchestrator.validateConfigurations — strict', () {
    test('strict: returns false when schema_version missing', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final valid =
          await orchestrator.validateConfigurations(strict: true);
      expect(valid, isFalse);
    });

    test('non-strict: returns true when schema_version missing', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final valid = await orchestrator.validateConfigurations();
      expect(valid, isTrue);
    });

    test('strict: returns true for valid config with schema_version', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final valid =
          await orchestrator.validateConfigurations(strict: true);
      expect(valid, isTrue);
    });

    test('strict: returns false for config with unknown key', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: Dev
  unknown_key: value
''');
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final valid =
          await orchestrator.validateConfigurations(strict: true);
      expect(valid, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // JSON stable key contracts — validate (v0.8.0 additions)
  // ───────────────────────────────────────────────────────────────────────────

  group('JSON stable key contracts — validate (v0.8.0)', () {
    test('validate JSON payload now contains schema_version and strict keys',
        () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final schemaVersion = await orchestrator.getSchemaVersion();
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: false);
      final allValid = results.every((r) => r['valid'] as bool);

      final payload = jsonEncode({
        'command': 'validate',
        'valid': allValid,
        'schema_version': schemaVersion,
        'strict': false,
        'flavors': results,
      });

      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['command'], equals('validate'));
      expect(decoded, contains('valid'));
      expect(decoded, contains('schema_version'));
      expect(decoded, contains('strict'));
      expect(decoded, contains('flavors'));

      final flavorList = decoded['flavors']! as List;
      for (final item in flavorList) {
        final entry = item as Map<String, Object?>;
        expect(entry, contains('name'));
        expect(entry, contains('valid'));
        expect(entry, contains('errors'));
        expect(entry, contains('warnings'));
      }
    });

    test('strict validate JSON payload is JSON-encodable', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final schemaVersion = await orchestrator.getSchemaVersion();
      final results =
          await orchestrator.validateConfigurationsDetailed(strict: true);
      final allValid = results.every((r) => r['valid'] as bool);

      expect(
        () => jsonEncode({
          'command': 'validate',
          'valid': allValid,
          'schema_version': schemaVersion,
          'strict': true,
          'flavors': results,
        }),
        returnsNormally,
      );
    });

    test('validate JSON payload with null schema_version is encodable',
        () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final schemaVersion = await orchestrator.getSchemaVersion();
      final results = await orchestrator.validateConfigurationsDetailed();

      expect(
        () => jsonEncode({
          'command': 'validate',
          'valid': true,
          'schema_version': schemaVersion, // null — must still encode
          'strict': false,
          'flavors': results,
        }),
        returnsNormally,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // knownFlavorKeys / knownProvisioningKeys constants — public API
  // ───────────────────────────────────────────────────────────────────────────

  group('known key sets', () {
    test('knownFlavorKeys contains expected keys', () {
      expect(knownFlavorKeys, contains('bundle_id'));
      expect(knownFlavorKeys, contains('app_name'));
      expect(knownFlavorKeys, contains('file_mappings'));
      expect(knownFlavorKeys, contains('provisioning'));
      expect(knownFlavorKeys, contains('replace_destination_directories'));
    });

    test('knownProvisioningKeys contains expected keys', () {
      expect(knownProvisioningKeys, contains('android_google_services'));
      expect(knownProvisioningKeys, contains('ios_google_service'));
      expect(knownProvisioningKeys, contains('additional_files'));
    });

    test('deprecatedFlavorKeys is a map (scaffold exists)', () {
      expect(deprecatedFlavorKeys, isA<Map<String, String>>());
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Backward compatibility — existing tests still pass
  // ───────────────────────────────────────────────────────────────────────────

  group('backward compatibility', () {
    test('validateConfigurationsDetailed() still returns name/valid/errors',
        () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      expect(results, hasLength(1));
      expect(results.first, contains('name'));
      expect(results.first, contains('valid'));
      expect(results.first, contains('errors'));
      expect(results.first['valid'], isTrue);
    });

    test('validateConfigurations() still returns bool', () async {
      await _setupProject(tempDir, _validFlavorNoSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final valid = await orchestrator.validateConfigurations();
      expect(valid, isTrue);
    });

    test('config with schema_version is parsed as before', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final flavors = await orchestrator.listFlavors();
      expect(flavors, contains('dev'));
      expect(flavors, isNot(contains('schema_version')));
    });

    test('apply dry-run still works with schema_version in config', () async {
      await _setupProject(tempDir, _validFlavorWithSchema);
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final result = await orchestrator.applyFlavorDetailed(
        'dev',
        platforms: [],
        dryRun: true,
      );

      expect(result['success'], isTrue);
      expect(result['flavor'], equals('dev'));
    });
  });
}
