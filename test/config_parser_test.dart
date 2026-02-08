import 'dart:io';
import 'package:flutter_flavor_orchestrator/src/config_parser.dart';
import 'package:flutter_flavor_orchestrator/src/models/flavor_config.dart';
import 'package:flutter_flavor_orchestrator/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ConfigParser parser;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('flavor_test_');
    parser = ConfigParser(logger: const Logger());
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ConfigParser', () {
    test('parses flavor_config.yaml file', () async {
      // Create a test flavor_config.yaml
      final configFile = File('${tempDir.path}/flavor_config.yaml');
      await configFile.writeAsString('''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  metadata:
    API_URL: https://dev-api.example.com

production:
  bundle_id: com.example.app
  app_name: My App
  metadata:
    API_URL: https://api.example.com
''');

      // Create a minimal pubspec.yaml
      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_app
flutter:
  uses-material-design: true
''');

      final configs = await parser.parseConfig(tempDir.path);

      expect(configs.length, equals(2));
      expect(configs.containsKey('dev'), isTrue);
      expect(configs.containsKey('production'), isTrue);
      expect(configs['dev']!.bundleId, equals('com.example.dev'));
      expect(configs['production']!.appName, equals('My App'));
    });

    test('parses flavor_config section in pubspec.yaml', () async {
      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_app

flutter:
  uses-material-design: true

flavor_config:
  staging:
    bundle_id: com.example.staging
    app_name: App Staging
''');

      final configs = await parser.parseConfig(tempDir.path);

      expect(configs.length, equals(1));
      expect(configs.containsKey('staging'), isTrue);
      expect(configs['staging']!.bundleId, equals('com.example.staging'));
    });

    test('parses specific flavor configuration', () async {
      final configFile = File('${tempDir.path}/flavor_config.yaml');
      await configFile.writeAsString('''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  
production:
  bundle_id: com.example.app
  app_name: My App
''');

      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('name: test_app\nflutter:\n');

      final config = await parser.parseFlavorConfig(tempDir.path, 'dev');

      expect(config.name, equals('dev'));
      expect(config.bundleId, equals('com.example.dev'));
      expect(config.appName, equals('App Dev'));
    });

    test('throws FormatException for non-existent flavor', () async {
      final configFile = File('${tempDir.path}/flavor_config.yaml');
      await configFile.writeAsString('''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('name: test_app\nflutter:\n');

      expect(
        () => parser.parseFlavorConfig(tempDir.path, 'nonexistent'),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates bundle_id format', () async {
      const validConfig = {
        'bundle_id': 'com.example.app',
        'app_name': 'My App',
      };

      const invalidConfig = {
        'bundle_id': 'invalid_bundle_id',
        'app_name': 'My App',
      };

      final validFlavorConfig = FlavorConfig.fromYaml('valid', validConfig);
      final invalidFlavorConfig =
          FlavorConfig.fromYaml('invalid', invalidConfig);

      expect(() => parser.validateConfig(validFlavorConfig), returnsNormally);
      expect(
        () => parser.validateConfig(invalidFlavorConfig),
        throwsA(isA<FormatException>()),
      );
    });

    test('gets list of available flavors', () async {
      final configFile = File('${tempDir.path}/flavor_config.yaml');
      await configFile.writeAsString('''
dev:
  bundle_id: com.example.dev
  app_name: App Dev

staging:
  bundle_id: com.example.staging
  app_name: App Staging

production:
  bundle_id: com.example.app
  app_name: My App
''');

      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('name: test_app\nflutter:\n');

      final flavors = await parser.getAvailableFlavors(tempDir.path);

      expect(flavors.length, equals(3));
      expect(flavors, contains('dev'));
      expect(flavors, contains('staging'));
      expect(flavors, contains('production'));
    });

    test('throws FileSystemException when no config found', () async {
      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('name: test_app\nflutter:\n');

      expect(
        () => parser.parseConfig(tempDir.path),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
