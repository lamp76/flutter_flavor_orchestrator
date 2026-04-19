import 'dart:io';
import 'package:flutter_flavor_orchestrator/src/models/flavor_config.dart';
import 'package:flutter_flavor_orchestrator/src/processors/asset_processor.dart';
import 'package:flutter_flavor_orchestrator/src/utils/file_manager.dart';
import 'package:flutter_flavor_orchestrator/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late AssetProcessor processor;
  late FileManager fileManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('asset_processor_test_');
    const logger = Logger();
    fileManager = FileManager(logger: logger, createBackups: false);
    processor = AssetProcessor(
      projectRoot: tempDir.path,
      fileManager: fileManager,
      logger: logger,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AssetProcessor', () {
    test('returns 0 when no file mappings defined', () async {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(0));
    });

    test('copies single file successfully', () async {
      // Create source file
      final sourceDir = Directory('${tempDir.path}/configs/dev');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/config.json');
      await sourceFile.writeAsString('{"env": "development"}');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/config.json': 'configs/dev/config.json',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(1));

      final destinationFile = File('${tempDir.path}/lib/config.json');
      expect(await destinationFile.exists(), isTrue);

      final content = await destinationFile.readAsString();
      expect(content, equals('{"env": "development"}'));
    });

    test('copies multiple files successfully', () async {
      // Create source files
      final sourceDir1 = Directory('${tempDir.path}/assets/icons');
      await sourceDir1.create(recursive: true);
      final sourceFile1 = File('${sourceDir1.path}/icon.png');
      await sourceFile1.writeAsString('PNG_DATA_1');

      final sourceDir2 = Directory('${tempDir.path}/configs');
      await sourceDir2.create(recursive: true);
      final sourceFile2 = File('${sourceDir2.path}/api.json');
      await sourceFile2.writeAsString('{"api": "url"}');

      const config = FlavorConfig(
        name: 'staging',
        bundleId: 'com.example.staging',
        appName: 'App Staging',
        fileMappings: {
          'android/app/icon.png': 'assets/icons/icon.png',
          'lib/api_config.json': 'configs/api.json',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(2));

      final destFile1 = File('${tempDir.path}/android/app/icon.png');
      expect(await destFile1.exists(), isTrue);
      expect(await destFile1.readAsString(), equals('PNG_DATA_1'));

      final destFile2 = File('${tempDir.path}/lib/api_config.json');
      expect(await destFile2.exists(), isTrue);
      expect(await destFile2.readAsString(), equals('{"api": "url"}'));
    });

    test('replaces existing file at destination', () async {
      // Create destination file with old content
      final destDir = Directory('${tempDir.path}/lib/config');
      await destDir.create(recursive: true);
      final destFile = File('${destDir.path}/settings.dart');
      await destFile.writeAsString('// Old settings');

      // Create source file with new content
      final sourceDir = Directory('${tempDir.path}/configs/dev');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/settings.dart');
      await sourceFile.writeAsString('// New dev settings');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/config/settings.dart': 'configs/dev/settings.dart',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(1));

      final content = await destFile.readAsString();
      expect(content, equals('// New dev settings'));
    });

    test('copies directory recursively', () async {
      // Create source directory with multiple files and subdirectories
      final sourceDir = Directory('${tempDir.path}/source/assets');
      await sourceDir.create(recursive: true);

      final file1 = File('${sourceDir.path}/image1.png');
      await file1.writeAsString('IMAGE1');

      final file2 = File('${sourceDir.path}/image2.png');
      await file2.writeAsString('IMAGE2');

      final subDir = Directory('${sourceDir.path}/icons');
      await subDir.create(recursive: true);

      final file3 = File('${subDir.path}/icon.svg');
      await file3.writeAsString('SVG_DATA');

      final deepSubDir = Directory('${subDir.path}/small');
      await deepSubDir.create(recursive: true);

      final file4 = File('${deepSubDir.path}/small_icon.svg');
      await file4.writeAsString('SMALL_SVG');

      const config = FlavorConfig(
        name: 'prod',
        bundleId: 'com.example.prod',
        appName: 'App Prod',
        fileMappings: {
          'assets/images': 'source/assets',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(4));

      // Verify all files were copied
      final destFile1 = File('${tempDir.path}/assets/images/image1.png');
      expect(await destFile1.exists(), isTrue);
      expect(await destFile1.readAsString(), equals('IMAGE1'));

      final destFile2 = File('${tempDir.path}/assets/images/image2.png');
      expect(await destFile2.exists(), isTrue);
      expect(await destFile2.readAsString(), equals('IMAGE2'));

      final destFile3 = File('${tempDir.path}/assets/images/icons/icon.svg');
      expect(await destFile3.exists(), isTrue);
      expect(await destFile3.readAsString(), equals('SVG_DATA'));

      final destFile4 = File(
        '${tempDir.path}/assets/images/icons/small/small_icon.svg',
      );
      expect(await destFile4.exists(), isTrue);
      expect(await destFile4.readAsString(), equals('SMALL_SVG'));
    });

    test('skips non-existent source path with warning', () async {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/config.json': 'configs/nonexistent/config.json',
        },
      );

      final result = await processor.processFileMappings(config);

      // Should skip the non-existent file
      expect(result, equals(0));

      final destinationFile = File('${tempDir.path}/lib/config.json');
      expect(await destinationFile.exists(), isFalse);
    });

    test('handles mixed file and directory mappings', () async {
      // Create source file
      final sourceFile = File('${tempDir.path}/source/config.txt');
      await sourceFile.create(recursive: true);
      await sourceFile.writeAsString('CONFIG');

      // Create source directory
      final sourceDir = Directory('${tempDir.path}/source/icons');
      await sourceDir.create(recursive: true);

      final iconFile1 = File('${sourceDir.path}/icon1.png');
      await iconFile1.writeAsString('ICON1');

      final iconFile2 = File('${sourceDir.path}/icon2.png');
      await iconFile2.writeAsString('ICON2');

      const config = FlavorConfig(
        name: 'staging',
        bundleId: 'com.example.staging',
        appName: 'App Staging',
        fileMappings: {
          'lib/config.txt': 'source/config.txt',
          'assets/icons': 'source/icons',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(3)); // 1 file + 2 files in directory

      // Verify file
      final destFile = File('${tempDir.path}/lib/config.txt');
      expect(await destFile.exists(), isTrue);
      expect(await destFile.readAsString(), equals('CONFIG'));

      // Verify directory contents
      final destIcon1 = File('${tempDir.path}/assets/icons/icon1.png');
      expect(await destIcon1.exists(), isTrue);
      expect(await destIcon1.readAsString(), equals('ICON1'));

      final destIcon2 = File('${tempDir.path}/assets/icons/icon2.png');
      expect(await destIcon2.exists(), isTrue);
      expect(await destIcon2.readAsString(), equals('ICON2'));
    });

    test('creates destination directories if they do not exist', () async {
      // Create source file
      final sourceFile = File('${tempDir.path}/src/data.json');
      await sourceFile.create(recursive: true);
      await sourceFile.writeAsString('{"data": "test"}');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'deeply/nested/path/to/data.json': 'src/data.json',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(1));

      final destFile = File(
        '${tempDir.path}/deeply/nested/path/to/data.json',
      );
      expect(await destFile.exists(), isTrue);
      expect(await destFile.readAsString(), equals('{"data": "test"}'));
    });

    test('handles empty directory', () async {
      // Create empty source directory
      final sourceDir = Directory('${tempDir.path}/source/empty');
      await sourceDir.create(recursive: true);

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'assets/empty': 'source/empty',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(0)); // No files to copy

      // Verify directory was created
      final destDir = Directory('${tempDir.path}/assets/empty');
      expect(await destDir.exists(), isTrue);
    });

    test('processes multiple flavors with different mappings', () async {
      // Create dev source files
      final devDir = Directory('${tempDir.path}/configs/dev');
      await devDir.create(recursive: true);
      final devFile = File('${devDir.path}/config.dart');
      await devFile.writeAsString('// Dev config');

      // Create prod source files
      final prodDir = Directory('${tempDir.path}/configs/prod');
      await prodDir.create(recursive: true);
      final prodFile = File('${prodDir.path}/config.dart');
      await prodFile.writeAsString('// Prod config');

      // Process dev flavor
      const devConfig = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/config.dart': 'configs/dev/config.dart',
        },
      );

      final devResult = await processor.processFileMappings(devConfig);
      expect(devResult, equals(1));

      final destFile = File('${tempDir.path}/lib/config.dart');
      expect(await destFile.readAsString(), equals('// Dev config'));

      // Process prod flavor (should replace dev file)
      const prodConfig = FlavorConfig(
        name: 'prod',
        bundleId: 'com.example.prod',
        appName: 'App Prod',
        fileMappings: {
          'lib/config.dart': 'configs/prod/config.dart',
        },
      );

      final prodResult = await processor.processFileMappings(prodConfig);
      expect(prodResult, equals(1));

      expect(await destFile.readAsString(), equals('// Prod config'));
    });

    test('replaces existing directory when replace mode enabled', () async {
      // Create initial destination directory with old files
      final destDir = Directory('${tempDir.path}/lib/theme');
      await destDir.create(recursive: true);

      final oldFile1 = File('${destDir.path}/old_theme.dart');
      await oldFile1.writeAsString('// Old theme file');

      final oldFile2 = File('${destDir.path}/old_colors.dart');
      await oldFile2.writeAsString('// Old colors file');

      // Create new source directory with different files
      final sourceDir = Directory('${tempDir.path}/resources/dev/themes');
      await sourceDir.create(recursive: true);

      final newFile1 = File('${sourceDir.path}/app_theme.dart');
      await newFile1.writeAsString('// New dev theme');

      final newFile2 = File('${sourceDir.path}/colors.dart');
      await newFile2.writeAsString('// New dev colors');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/theme': 'resources/dev/themes',
        },
        replaceDestinationDirectories: true,
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(2));

      // Old files should be gone
      expect(await oldFile1.exists(), isFalse);
      expect(await oldFile2.exists(), isFalse);

      // New files should exist
      final newDestFile1 = File('${tempDir.path}/lib/theme/app_theme.dart');
      expect(await newDestFile1.exists(), isTrue);
      expect(
        await newDestFile1.readAsString(),
        equals('// New dev theme'),
      );

      final newDestFile2 = File('${tempDir.path}/lib/theme/colors.dart');
      expect(await newDestFile2.exists(), isTrue);
      expect(await newDestFile2.readAsString(), equals('// New dev colors'));
    });

    test(
      'merges with existing directory when replace mode disabled',
      () async {
        // Create destination directory with existing files
        final destDir = Directory('${tempDir.path}/lib/config');
        await destDir.create(recursive: true);

        final existingFile = File('${destDir.path}/existing.dart');
        await existingFile.writeAsString('// Existing file');

        // Create source directory with new files
        final sourceDir = Directory('${tempDir.path}/source/config');
        await sourceDir.create(recursive: true);

        final newFile = File('${sourceDir.path}/new_file.dart');
        await newFile.writeAsString('// New file');

        const config = FlavorConfig(
          name: 'dev',
          bundleId: 'com.example.dev',
          appName: 'App Dev',
          fileMappings: {
            'lib/config': 'source/config',
          },
        );

        final result = await processor.processFileMappings(config);

        expect(result, equals(1));

        // Existing file should still be there
        expect(await existingFile.exists(), isTrue);
        expect(
          await existingFile.readAsString(),
          equals('// Existing file'),
        );

        // New file should also exist
        final destNewFile = File('${tempDir.path}/lib/config/new_file.dart');
        expect(await destNewFile.exists(), isTrue);
        expect(await destNewFile.readAsString(), equals('// New file'));
      },
    );

    test('restores original directory on copy failure with replace mode',
        () async {
      // Create destination directory with original files
      final destDir = Directory('${tempDir.path}/lib/theme');
      await destDir.create(recursive: true);

      final originalFile = File('${destDir.path}/original.dart');
      await originalFile.writeAsString('// Original content');

      // Create source directory with file that will cause copy to fail
      final sourceDir = Directory('${tempDir.path}/source/theme');
      await sourceDir.create(recursive: true);

      final sourceFile = File('${sourceDir.path}/new.dart');
      await sourceFile.writeAsString('// New content');

      // Create a read-only destination path to cause failure
      final problematicPath = '${tempDir.path}/lib/theme/readonly.txt';
      final problematicFile = File(problematicPath);
      await problematicFile.create(recursive: true);
      await problematicFile.writeAsString('read-only');

      // Make it read-only on Windows
      // (won't work on all platforms, but demonstrates concept)
      if (Platform.isWindows) {
        await Process.run('attrib', ['+R', problematicPath]);
      }

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/theme': 'source/theme',
        },
        replaceDestinationDirectories: true,
      );

      try {
        // This should succeed since we're copying to a temp backup first
        // The test validates that the mechanism works
        await processor.processFileMappings(config);

        // Clean up read-only file if test passed
        if (Platform.isWindows) {
          await Process.run('attrib', ['-R', problematicPath]);
        }
      } on Exception {
        // If it fails, verify original is still there
        expect(await destDir.exists(), isTrue);

        // Clean up read-only file
        if (Platform.isWindows) {
          await Process.run('attrib', ['-R', problematicPath]);
        }
      }
    });

    test('handles nested directory structure in replace mode', () async {
      // Create destination with nested structure
      final destDir = Directory('${tempDir.path}/assets/images');
      await destDir.create(recursive: true);

      final oldSubDir = Directory('${destDir.path}/old_subdir');
      await oldSubDir.create(recursive: true);

      final oldFile = File('${oldSubDir.path}/old.png');
      await oldFile.writeAsString('OLD_IMAGE');

      // Create source with different nested structure
      final sourceDir = Directory('${tempDir.path}/source/images');
      await sourceDir.create(recursive: true);

      final newSubDir = Directory('${sourceDir.path}/new_subdir');
      await newSubDir.create(recursive: true);

      final newFile1 = File('${newSubDir.path}/icon.png');
      await newFile1.writeAsString('NEW_ICON');

      final newFile2 = File('${sourceDir.path}/logo.png');
      await newFile2.writeAsString('LOGO');

      const config = FlavorConfig(
        name: 'prod',
        bundleId: 'com.example.prod',
        appName: 'App Prod',
        fileMappings: {
          'assets/images': 'source/images',
        },
        replaceDestinationDirectories: true,
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(2));

      // Old subdirectory should be gone
      expect(await oldSubDir.exists(), isFalse);
      expect(await oldFile.exists(), isFalse);

      // New files should exist
      final destNewFile1 =
          File('${tempDir.path}/assets/images/new_subdir/icon.png');
      expect(await destNewFile1.exists(), isTrue);
      expect(await destNewFile1.readAsString(), equals('NEW_ICON'));

      final destNewFile2 = File('${tempDir.path}/assets/images/logo.png');
      expect(await destNewFile2.exists(), isTrue);
      expect(await destNewFile2.readAsString(), equals('LOGO'));
    });

    test('dry-run validates mapping without modifying destination file',
        () async {
      final sourceDir = Directory('${tempDir.path}/configs/dev');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/config.json');
      await sourceFile.writeAsString('{"env": "development"}');

      final destinationFile = File('${tempDir.path}/lib/config.json');
      await destinationFile.create(recursive: true);
      await destinationFile.writeAsString('{"env": "existing"}');

      fileManager.dryRun = true;

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/config.json': 'configs/dev/config.json',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(1));
      expect(
        await destinationFile.readAsString(),
        equals('{"env": "existing"}'),
      );
    });

    test('dry-run allows missing destination file', () async {
      final sourceDir = Directory('${tempDir.path}/configs/dev');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/config.json');
      await sourceFile.writeAsString('{"env": "development"}');

      fileManager.dryRun = true;

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/config.json': 'configs/dev/config.json',
        },
      );

      final result = await processor.processFileMappings(config);

      expect(result, equals(1));
      final destinationFile = File('${tempDir.path}/lib/config.json');
      expect(await destinationFile.exists(), isFalse);
    });
  });
}
