import 'dart:io';
import 'package:flutter_flavor_orchestrator/src/utils/file_manager.dart';
import 'package:flutter_flavor_orchestrator/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late FileManager fileManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_manager_test_');
    const logger = Logger();
    fileManager = FileManager(
      logger: logger,
      createBackups: false,
      dryRun: true,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileManager dry-run', () {
    test('writeFile validates destination in dry-run', () async {
      final destination = File('${tempDir.path}/lib/config.dart');
      await destination.create(recursive: true);
      await destination.writeAsString('// existing content');

      await fileManager.writeFile(destination.path, '// new content');

      expect(await destination.readAsString(), equals('// existing content'));
    });

    test('copyFile validates destination in dry-run', () async {
      final source = File('${tempDir.path}/configs/dev/app_config.dart');
      await source.create(recursive: true);
      await source.writeAsString('// source content');

      final destination = File('${tempDir.path}/lib/config/app_config.dart');
      await destination.create(recursive: true);
      await destination.writeAsString('// existing destination content');

      await fileManager.copyFile(source.path, destination.path);

      expect(
        await destination.readAsString(),
        equals('// existing destination content'),
      );
    });

    test('writeFile allows missing destination in dry-run', () async {
      final destinationPath = '${tempDir.path}/lib/missing.dart';

      await fileManager.writeFile(destinationPath, '// content');

      final destination = File(destinationPath);
      expect(await destination.exists(), isFalse);
    });

    test('copyFile allows missing destination in dry-run', () async {
      final source = File('${tempDir.path}/configs/dev/config.json');
      await source.create(recursive: true);
      await source.writeAsString('{"env": "dev"}');

      final destinationPath = '${tempDir.path}/lib/config.json';

      await fileManager.copyFile(source.path, destinationPath);

      final destination = File(destinationPath);
      expect(await destination.exists(), isFalse);
    });
  });
}
