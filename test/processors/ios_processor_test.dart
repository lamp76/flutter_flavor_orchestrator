import 'dart:io';
import 'package:flutter_flavor_orchestrator/src/models/flavor_config.dart';
import 'package:flutter_flavor_orchestrator/src/processors/ios_processor.dart';
import 'package:flutter_flavor_orchestrator/src/utils/file_manager.dart';
import 'package:flutter_flavor_orchestrator/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late IosProcessor processor;
  late FileManager fileManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ios_test_');
    const logger = Logger();
    fileManager = FileManager(logger: logger, createBackups: false);
    processor = IosProcessor(
      fileManager: fileManager,
      logger: logger,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('IosProcessor', () {
    test('updates Info.plist app name', () async {
      // Create iOS directory structure
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>Old App</string>
\t<key>CFBundleIdentifier</key>
\t<string>com.example.old</string>
</dict>
</plist>
''');

      // Create minimal project.pbxproj
      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.old;
    IPHONEOS_DEPLOYMENT_TARGET = 12.0;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<string>App Dev</string>'));
    });

    test('updates project.pbxproj bundle identifier', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      // Create minimal Info.plist
      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);

      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString(r'''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.old;
    PRODUCT_NAME = "$(TARGET_NAME)";
    IPHONEOS_DEPLOYMENT_TARGET = 12.0;
};
''');

      const config = FlavorConfig(
        name: 'production',
        bundleId: 'com.example.app',
        appName: 'My App',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await pbxprojFile.readAsString();

      expect(
        updatedContent,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.app;'),
      );
    });

    test('updates iOS deployment target', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);

      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
    IPHONEOS_DEPLOYMENT_TARGET = 12.0;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        iosMinVersion: '14.0',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await pbxprojFile.readAsString();

      expect(updatedContent, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
    });

    test('throws FileSystemException if ios directory missing', () async {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      expect(
        () => processor.process(tempDir.path, config),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
