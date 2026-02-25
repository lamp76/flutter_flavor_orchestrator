import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

/// Computes the SHA-256 checksum of [content] as a hex string.
String _sha256(List<int> content) => sha256.convert(content).toString();

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_manager_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupManager.createBackup', () {
    test('creates backup directory and metadata.json', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      // Create a file that the plan will reference
      final destFile = File('${tempDir.path}/android/app/build.gradle');
      await destFile.create(recursive: true);
      await destFile.writeAsString('// build.gradle content');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor(
        'dev',
        platforms: ['android'],
      );

      final record = await manager.createBackup(plan);

      // Backup directory must exist
      expect(await Directory(record.backupDir).exists(), isTrue);

      // metadata.json must exist
      final metadataFile =
          File('${record.backupDir}/metadata.json');
      expect(await metadataFile.exists(), isTrue);
    });

    test('metadata.json contains correct flavor and id', () async {
      await _setupProject(tempDir, '''
staging:
  bundle_id: com.example.staging
  app_name: App Staging
''');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('staging');

      final record = await manager.createBackup(plan);

      final metadataFile =
          File('${record.backupDir}/metadata.json');
      final json =
          jsonDecode(await metadataFile.readAsString()) as Map<String, Object?>;

      expect(json['flavor'], equals('staging'));
      expect(json['id'], equals(record.id));
      expect(json.containsKey('created_at'), isTrue);
      expect(json.containsKey('entries'), isTrue);
    });

    test('backed-up file matches original content', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const originalContent = '// original build.gradle';
      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString(originalContent);

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      // Find the backup entry for build.gradle
      final entry = record.entries.firstWhere(
        (e) => e.backupRelativePath.contains('build.gradle'),
      );

      final backupFile = File(
        '${record.backupDir}/files/${entry.backupRelativePath}',
      );
      expect(await backupFile.exists(), isTrue);
      expect(await backupFile.readAsString(), equals(originalContent));
    });

    test('pre-apply checksum matches backed-up file content', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const originalContent = '// original content';
      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString(originalContent);

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      final entry = record.entries.firstWhere(
        (e) => e.backupRelativePath.contains('build.gradle'),
      );

      final expectedChecksum =
          _sha256(await File(entry.originalPath).readAsBytes());
      expect(entry.preApplyChecksum, equals(expectedChecksum));
    });

    test('skips destination files that do not exist', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      // Do NOT create any native files — nothing to back up
      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      final record = await manager.createBackup(plan);

      expect(record.entries, isEmpty);
    });
  });

  group('BackupManager.finalizeBackup', () {
    test('sets post-apply checksums for existing files', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString('// pre-apply');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      // Simulate apply by overwriting the file
      await destFile.writeAsString('// post-apply');

      final finalised = await manager.finalizeBackup(record);

      final entry = finalised.entries.firstWhere(
        (e) => e.backupRelativePath.contains('build.gradle'),
      );
      expect(entry.postApplyChecksum, isNotNull);

      final expectedPostApplyChecksum =
          _sha256(await destFile.readAsBytes());
      expect(entry.postApplyChecksum, equals(expectedPostApplyChecksum));
    });

    test('persists post-apply checksums to metadata.json', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString('// original');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      var record = await manager.createBackup(plan);
      await destFile.writeAsString('// after apply');
      record = await manager.finalizeBackup(record);

      // Reload from disk
      final metadataFile =
          File('${record.backupDir}/metadata.json');
      final json = jsonDecode(await metadataFile.readAsString())
          as Map<String, Object?>;
      final entries = json['entries'] as List<Object?>;
      final entryMap =
          entries.cast<Map<String, Object?>>().firstWhere(
                (e) =>
                    (e['backup_relative_path'] as String)
                        .contains('build.gradle'),
              );
      expect(entryMap.containsKey('post_apply_checksum'), isTrue);
    });
  });

  group('BackupManager.listBackups and latestBackup', () {
    test('listBackups returns empty list when no backups exist', () async {
      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final backups = await manager.listBackups();
      expect(backups, isEmpty);
    });

    test('latestBackup returns null when no backups exist', () async {
      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final latest = await manager.latestBackup();
      expect(latest, isNull);
    });

    test('listBackups returns created backup', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');
      await manager.createBackup(plan);

      final backups = await manager.listBackups();
      expect(backups, hasLength(1));
      expect(backups.first.flavorName, equals('dev'));
    });

    test('latestBackup returns the most recently created backup', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      await manager.createBackup(plan);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = await manager.createBackup(plan);

      final latest = await manager.latestBackup();
      expect(latest, isNotNull);
      expect(latest!.id, equals(second.id));
    });

    test(
        'listBackups is sorted newest-first',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      await manager.createBackup(plan);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await manager.createBackup(plan);

      final backups = await manager.listBackups();
      expect(backups, hasLength(2));
      expect(
        backups[0].createdAt.isAfter(backups[1].createdAt) ||
            backups[0].createdAt == backups[1].createdAt,
        isTrue,
      );
    });
  });

  group('BackupManager.restore', () {
    test('restores original file content', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const originalContent = '// original build.gradle';
      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString(originalContent);

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      // Simulate apply by overwriting the file
      await destFile.writeAsString('// after apply');
      final finalised = await manager.finalizeBackup(record);

      // Restore
      final success = await manager.restore(finalised);
      expect(success, isTrue);
      expect(await destFile.readAsString(), equals(originalContent));
    });

    test('returns true when no entries to restore', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      // No destination files exist, so entries will be empty
      final record = await manager.createBackup(plan);
      final success = await manager.restore(record);
      expect(success, isTrue);
    });

    test(
        'returns false on checksum mismatch without --force',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString('// original');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      // Apply changes the file
      await destFile.writeAsString('// post-apply');
      final finalised = await manager.finalizeBackup(record);

      // Simulate manual edit AFTER apply
      await destFile.writeAsString('// manually edited');

      final success = await manager.restore(finalised);
      expect(success, isFalse);
    });

    test(
        'restores despite checksum mismatch when force is true',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const originalContent = '// original';
      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString(originalContent);

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      await destFile.writeAsString('// post-apply');
      final finalised = await manager.finalizeBackup(record);

      // Simulate manual edit AFTER apply
      await destFile.writeAsString('// manually edited');

      final success = await manager.restore(finalised, force: true);
      expect(success, isTrue);
      expect(await destFile.readAsString(), equals(originalContent));
    });

    test(
        'restore proceeds without conflict when no post-apply '
        'checksums are set',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      const originalContent = '// original';
      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString(originalContent);

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      // createBackup only — no finalizeBackup, so no post-apply checksums
      final record = await manager.createBackup(plan);

      await destFile.writeAsString('// changed');

      // Should not detect conflicts since postApplyChecksum is null
      final success = await manager.restore(record);
      expect(success, isTrue);
      expect(await destFile.readAsString(), equals(originalContent));
    });
  });

  group('BackupRecord serialisation', () {
    test('toJson/fromJson roundtrip preserves all fields', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final destFile = File(
        '${tempDir.path}/android/app/build.gradle',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString('// content');

      const logger = Logger();
      final manager = BackupManager(
        projectRoot: tempDir.path,
        logger: logger,
      );
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final record = await manager.createBackup(plan);

      final json = record.toJson();
      final restored = BackupRecord.fromJson(json);

      expect(restored.id, equals(record.id));
      expect(restored.flavorName, equals(record.flavorName));
      expect(restored.backupDir, equals(record.backupDir));
      expect(restored.entries.length, equals(record.entries.length));
    });
  });
}
