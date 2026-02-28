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
    tempDir = await Directory.systemTemp.createTemp('orchestrator_rollback_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FlavorOrchestrator.rollbackLatest', () {
    test('returns false when no backups exist', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.rollbackLatest();
      expect(result, isFalse);
    });

    test('restores file to pre-apply state', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      // Create a source file that can be mapped
      const srcContent = '// source config';
      const dstContent = '// existing destination';
      final srcFile = File('${tempDir.path}/configs/dev/app_config.dart');
      await srcFile.create(recursive: true);
      await srcFile.writeAsString(srcContent);

      final dstFile = File('${tempDir.path}/lib/config/app_config.dart');
      await dstFile.create(recursive: true);
      await dstFile.writeAsString(dstContent);

      await File('${tempDir.path}/flavor_config.yaml').writeAsString('''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config/app_config.dart': 'configs/dev/app_config.dart'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);

      // Apply must succeed (dry-run = false)
      final applySuccess = await orchestrator.applyFlavor(
        'dev',
        platforms: [],
      );
      expect(applySuccess, isTrue);

      // Destination file is now the source content
      expect(await dstFile.readAsString(), equals(srcContent));

      // Rollback should restore it to the original destination content
      final rollbackSuccess = await orchestrator.rollbackLatest();
      expect(rollbackSuccess, isTrue);
      expect(await dstFile.readAsString(), equals(dstContent));
    });

    test('rollback does not mutate files in dry-run apply scenario',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);

      // Dry-run apply must NOT create a backup
      await orchestrator.applyFlavor('dev', platforms: [], dryRun: true);

      final backups = await orchestrator.listBackups();
      expect(backups, isEmpty);
    });

    test('deletes newly created files and directories on rollback', () async {
      // Create source files / directory — but NOT the destinations
      final srcFile = File('${tempDir.path}/configs/dev/new_config.dart');
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('// new config');

      final srcThemeDir =
          Directory('${tempDir.path}/resources/dev/themes');
      await srcThemeDir.create(recursive: true);
      await File('${srcThemeDir.path}/colors.dart')
          .writeAsString('// new colors');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config/new_config.dart': 'configs/dev/new_config.dart'
    'lib/theme': 'resources/dev/themes'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);

      // Neither destination exists before apply
      final newFile = File('${tempDir.path}/lib/config/new_config.dart');
      final newThemeDir = Directory('${tempDir.path}/lib/theme');
      expect(await newFile.exists(), isFalse);
      expect(await newThemeDir.exists(), isFalse);

      final applySuccess =
          await orchestrator.applyFlavor('dev', platforms: []);
      expect(applySuccess, isTrue);

      // Both should now exist after apply
      expect(await newFile.exists(), isTrue);
      expect(await newThemeDir.exists(), isTrue);

      // Rollback must remove them since they didn't exist before apply
      final rollbackSuccess = await orchestrator.rollbackLatest();
      expect(rollbackSuccess, isTrue);
      expect(await newFile.exists(), isFalse);
      expect(await newThemeDir.exists(), isFalse);
    });
  });

  group('FlavorOrchestrator.rollbackById', () {
    test('returns false for unknown backup id', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result =
          await orchestrator.rollbackById('nonexistent_id');
      expect(result, isFalse);
    });
  });

  group('FlavorOrchestrator.listBackups', () {
    test('returns empty list before any apply', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final backups = await orchestrator.listBackups();
      expect(backups, isEmpty);
    });

    test('returns backup after non-dry-run apply', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      await orchestrator.applyFlavor('dev', platforms: []);

      final backups = await orchestrator.listBackups();
      expect(backups, hasLength(1));
      expect(backups.first.flavorName, equals('dev'));
    });
  });
}
