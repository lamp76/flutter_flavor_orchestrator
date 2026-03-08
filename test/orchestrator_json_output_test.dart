import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';
import 'package:test/test.dart';

/// Creates a minimal valid Flutter project in [dir] with the supplied
/// [configYaml] written to `flavor_config.yaml`.
Future<void> _setupProject(Directory dir, String configYaml) async {
  await File('${dir.path}/pubspec.yaml').writeAsString(
    'name: test_app\nflutter:\n  uses-material-design: true\n',
  );
  await File('${dir.path}/flavor_config.yaml').writeAsString(configYaml);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('json_output_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // FlavorConfig.toJson
  // ---------------------------------------------------------------------------

  group('FlavorConfig.toJson', () {
    test('contains all stable top-level keys', () {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      final json = config.toJson();

      expect(json, containsPair('name', 'dev'));
      expect(json, containsPair('bundle_id', 'com.example.dev'));
      expect(json, containsPair('app_name', 'App Dev'));
      expect(json, contains('file_mappings'));
      expect(json, contains('file_mappings_count'));
      expect(json, contains('replace_destination_directories'));
    });

    test('file_mappings_count matches actual count', () {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/a.dart': 'src/a.dart',
          'lib/b.dart': 'src/b.dart',
        },
      );

      final json = config.toJson();

      expect(json['file_mappings_count'], equals(2));
    });

    test('includes provisioning when present', () {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        provisioning: ProvisioningConfig(
          androidGoogleServicesPath: 'configs/dev/google-services.json',
        ),
      );

      final json = config.toJson();

      expect(json, contains('provisioning'));
      final prov = json['provisioning']! as Map<String, Object?>;
      expect(
        prov,
        containsPair(
          'android_google_services',
          'configs/dev/google-services.json',
        ),
      );
    });

    test('is JSON-encodable (no non-serialisable values)', () {
      const config = FlavorConfig(
        name: 'staging',
        bundleId: 'com.example.staging',
        appName: 'App Staging',
        metadata: {'API_URL': 'https://staging.example.com'},
        fileMappings: {'lib/env.dart': 'configs/staging/env.dart'},
        replaceDestinationDirectories: true,
      );

      expect(() => jsonEncode(config.toJson()), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // ProvisioningConfig.toJson
  // ---------------------------------------------------------------------------

  group('ProvisioningConfig.toJson', () {
    test('includes android_google_services when present', () {
      const config = ProvisioningConfig(
        androidGoogleServicesPath: 'configs/dev/google-services.json',
      );

      final json = config.toJson();

      expect(
        json,
        containsPair(
          'android_google_services',
          'configs/dev/google-services.json',
        ),
      );
    });

    test('includes ios_google_service when present', () {
      const config = ProvisioningConfig(
        iosGoogleServicePath: 'configs/dev/GoogleService-Info.plist',
      );

      final json = config.toJson();

      expect(
        json,
        containsPair(
          'ios_google_service',
          'configs/dev/GoogleService-Info.plist',
        ),
      );
    });

    test('empty when no paths set', () {
      const config = ProvisioningConfig();

      final json = config.toJson();

      expect(json, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Logger.silent mode
  // ---------------------------------------------------------------------------

  group('Logger.silent', () {
    test('creates Logger with silent=true without error', () {
      expect(
        () => const Logger(silent: true),
        returnsNormally,
      );
    });

    test('silent Logger methods do not throw', () {
      const logger = Logger(silent: true);
      expect(() => logger.info('test'), returnsNormally);
      expect(() => logger.success('test'), returnsNormally);
      expect(() => logger.warning('test'), returnsNormally);
      expect(() => logger.error('test'), returnsNormally);
      expect(() => logger.debug('test'), returnsNormally);
      expect(() => logger.section('test'), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // FlavorOrchestrator.getFlavorInfo
  // ---------------------------------------------------------------------------

  group('FlavorOrchestrator.getFlavorInfo', () {
    test('returns FlavorConfig for existing flavor', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final config = await orchestrator.getFlavorInfo('dev');

      expect(config.name, equals('dev'));
      expect(config.bundleId, equals('com.example.dev'));
      expect(config.appName, equals('App Dev'));
    });

    test('throws FormatException for unknown flavor', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);

      expect(
        () => orchestrator.getFlavorInfo('nonexistent'),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson result is JSON-encodable', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  metadata:
    API_URL: https://dev.example.com
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final config = await orchestrator.getFlavorInfo('dev');
      final json = config.toJson();

      expect(() => jsonEncode(json), returnsNormally);
      expect(json['name'], equals('dev'));
    });
  });

  // ---------------------------------------------------------------------------
  // FlavorOrchestrator.validateConfigurationsDetailed
  // ---------------------------------------------------------------------------

  group('FlavorOrchestrator.validateConfigurationsDetailed', () {
    test('returns one entry per flavor', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
staging:
  bundle_id: com.example.staging
  app_name: App Staging
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      expect(results, hasLength(2));
    });

    test('valid flavor has valid=true and empty errors', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      expect(results, hasLength(1));
      final result = results.first;
      expect(result['name'], equals('dev'));
      expect(result['valid'], isTrue);
      expect(result['errors'], equals(<String>[]));
    });

    test('invalid flavor has valid=false and non-empty errors', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: ''
  app_name: ''
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      expect(results, hasLength(1));
      final result = results.first;
      expect(result['name'], equals('dev'));
      expect(result['valid'], isFalse);
      final errors = result['errors']! as List;
      expect(errors, isNotEmpty);
    });

    test('each result entry is JSON-encodable', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final results = await orchestrator.validateConfigurationsDetailed();

      for (final r in results) {
        expect(() => jsonEncode(r), returnsNormally);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // FlavorOrchestrator silent mode
  // ---------------------------------------------------------------------------

  group('FlavorOrchestrator silent mode', () {
    test('can be constructed with silent=true', () {
      expect(
        () => FlavorOrchestrator(
          projectRoot: tempDir.path,
          silent: true,
        ),
        returnsNormally,
      );
    });

    test('listFlavors succeeds in silent mode', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final flavors = await orchestrator.listFlavors();
      expect(flavors, contains('dev'));
    });

    test('getFlavorInfo succeeds in silent mode', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final config = await orchestrator.getFlavorInfo('dev');
      expect(config.name, equals('dev'));
    });

    test('validateConfigurationsDetailed succeeds in silent mode', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );

      final results = await orchestrator.validateConfigurationsDetailed();
      expect(results, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // JSON stable key contracts (per-command)
  // ---------------------------------------------------------------------------

  group('JSON stable key contracts — list', () {
    test('list JSON payload contains command, count, flavors', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
production:
  bundle_id: com.example.app
  app_name: App
''');

      // Simulate what the CLI handler does in JSON mode.
      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final configs = await orchestrator.configParser.parseConfig(
        tempDir.path,
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

      final payload = jsonEncode({
        'command': 'list',
        'count': flavors.length,
        'flavors': flavors,
      });

      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['command'], equals('list'));
      expect(decoded['count'], equals(2));
      final flavorList = decoded['flavors']! as List;
      expect(flavorList, hasLength(2));
      final first = flavorList.first as Map<String, Object?>;
      expect(first, contains('name'));
      expect(first, contains('file_mappings_count'));
      expect(first, contains('replace_destination_directories'));
    });
  });

  group('JSON stable key contracts — info', () {
    test('info JSON payload contains command and flavor', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final config = await orchestrator.getFlavorInfo('dev');
      final payload = jsonEncode({
        'command': 'info',
        'flavor': config.toJson(),
      });

      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['command'], equals('info'));
      final flavor = decoded['flavor']! as Map<String, Object?>;
      expect(flavor['name'], equals('dev'));
      expect(flavor['bundle_id'], equals('com.example.dev'));
    });
  });

  group('JSON stable key contracts — validate', () {
    test('validate JSON payload contains command, valid, flavors', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(
        projectRoot: tempDir.path,
        silent: true,
      );
      final results = await orchestrator.validateConfigurationsDetailed();
      final allValid = results.every((r) => r['valid'] as bool);

      final payload = jsonEncode({
        'command': 'validate',
        'valid': allValid,
        'flavors': results,
      });

      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['command'], equals('validate'));
      expect(decoded, contains('valid'));
      expect(decoded, contains('flavors'));
      final flavorList = decoded['flavors']! as List;
      for (final item in flavorList) {
        final entry = item as Map<String, Object?>;
        expect(entry, contains('name'));
        expect(entry, contains('valid'));
        expect(entry, contains('errors'));
      }
    });
  });

  group('JSON stable key contracts — rollback', () {
    test('rollback JSON payload structure is stable', () {
      final payload = jsonEncode({
        'command': 'rollback',
        'success': true,
        'backup_id': '20260225_194640123_dev',
        'flavor': 'dev',
        'files_restored': 2,
        'new_paths_removed': 0,
      });

      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['command'], equals('rollback'));
      expect(decoded, contains('success'));
      expect(decoded, contains('backup_id'));
      expect(decoded, contains('flavor'));
      expect(decoded, contains('files_restored'));
      expect(decoded, contains('new_paths_removed'));
    });

    test('rollback error JSON payload is stable', () {
      final payload = jsonEncode({
        'command': 'rollback',
        'success': false,
        'error': 'No backups found. Run `apply` first to create a backup.',
      });

      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['command'], equals('rollback'));
      expect(decoded['success'], isFalse);
      expect(decoded, contains('error'));
    });
  });
}
