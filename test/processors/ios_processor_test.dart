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

    test('adds custom Info.plist entries with different types', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
\t<key>CFBundleIdentifier</key>
\t<string>com.example.app</string>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        customInfoPlistEntries: {
          'CustomStringKey': 'CustomValue',
          'CustomBoolKey': true,
          'CustomIntKey': 42,
          'CustomArrayKey': ['item1', 'item2'],
          'CustomDictKey': {'nestedKey': 'nestedValue'},
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<key>CustomStringKey</key>'));
      expect(updatedContent, contains('<string>CustomValue</string>'));
      expect(updatedContent, contains('<key>CustomBoolKey</key>'));
      expect(updatedContent, contains('<true/>'));
      expect(updatedContent, contains('<key>CustomIntKey</key>'));
      expect(updatedContent, contains('<integer>42</integer>'));
      expect(updatedContent, contains('<key>CustomArrayKey</key>'));
      expect(updatedContent, contains('<array>'));
      expect(updatedContent, contains('<string>item1</string>'));
      expect(updatedContent, contains('<key>CustomDictKey</key>'));
      expect(updatedContent, contains('<key>nestedKey</key>'));
    });

    test('overwrites existing Info.plist entries', () async {
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
\t<key>ExistingStringKey</key>
\t<string>OldValue</string>
\t<key>ExistingBoolKey</key>
\t<false/>
\t<key>ExistingIntKey</key>
\t<integer>10</integer>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.old;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        customInfoPlistEntries: {
          'ExistingStringKey': 'NewValue',
          'ExistingBoolKey': true,
          'ExistingIntKey': 99,
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      // Verify that values were updated, not duplicated
      expect(updatedContent, contains('<key>ExistingStringKey</key>'));
      expect(updatedContent, contains('<string>NewValue</string>'));
      expect(updatedContent, isNot(contains('<string>OldValue</string>')));

      expect(updatedContent, contains('<key>ExistingBoolKey</key>'));
      expect(updatedContent, contains('<true/>'));
      expect(updatedContent, isNot(contains('<false/>')));

      expect(updatedContent, contains('<key>ExistingIntKey</key>'));
      expect(updatedContent, contains('<integer>99</integer>'));
      expect(updatedContent, isNot(contains('<integer>10</integer>')));
    });

    test('overwrites CFBundleDisplayName correctly', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>Old Name</string>
\t<key>CFBundleIdentifier</key>
\t<string>com.example.old</string>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.old;
};
''');

      const config = FlavorConfig(
        name: 'production',
        bundleId: 'com.example.prod',
        appName: 'My Production App',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      // Should update the existing value, not duplicate
      expect(updatedContent, contains('<string>My Production App</string>'));
      expect(updatedContent, isNot(contains('<string>Old Name</string>')));

      // Count occurrences of CFBundleDisplayName - should appear only once
      final displayNameCount =
          '<key>CFBundleDisplayName</key>'.allMatches(updatedContent).length;
      expect(displayNameCount, equals(1));
    });

    test('adds metadata to Info.plist', () async {
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
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        metadata: {
          'API_URL': 'https://dev.example.com',
          'DEBUG_MODE': true,
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<key>API_URL</key>'));
      expect(
        updatedContent,
        contains('<string>https://dev.example.com</string>'),
      );
      expect(updatedContent, contains('<key>DEBUG_MODE</key>'));
      expect(updatedContent, contains('<true/>'));
    });

    test('updates MinimumOSVersion when specified', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
\t<key>MinimumOSVersion</key>
\t<string>12.0</string>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        iosMinVersion: '15.0',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<string>15.0</string>'));
      expect(updatedContent, isNot(contains('<string>12.0</string>')));
    });

    test('overwrites array values in Info.plist', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
\t<key>URLSchemes</key>
\t<array>
\t\t<string>oldscheme</string>
\t</array>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        customInfoPlistEntries: {
          'URLSchemes': ['newscheme1', 'newscheme2'],
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<key>URLSchemes</key>'));
      expect(updatedContent, contains('<string>newscheme1</string>'));
      expect(updatedContent, contains('<string>newscheme2</string>'));
      expect(updatedContent, isNot(contains('<string>oldscheme</string>')));
    });

    test('overwrites dict values in Info.plist', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
\t<key>CustomConfig</key>
\t<dict>
\t\t<key>oldKey</key>
\t\t<string>oldValue</string>
\t</dict>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        customInfoPlistEntries: {
          'CustomConfig': {
            'newKey': 'newValue',
          },
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<key>CustomConfig</key>'));
      expect(updatedContent, contains('<key>newKey</key>'));
      expect(updatedContent, contains('<string>newValue</string>'));
      expect(updatedContent, isNot(contains('<key>oldKey</key>')));
      expect(updatedContent, isNot(contains('<string>oldValue</string>')));
    });

    test('overwrites bool from false to true', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
\t<key>FeatureFlag</key>
\t<false/>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        customInfoPlistEntries: {
          'FeatureFlag': true,
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<key>FeatureFlag</key>'));
      expect(updatedContent, contains('<true/>'));

      // Count occurrences - should not have duplicates
      final featureFlagCount =
          '<key>FeatureFlag</key>'.allMatches(updatedContent).length;
      expect(featureFlagCount, equals(1));
    });

    test('overwrites string to bool type change', () async {
      final runnerDir = Directory('${tempDir.path}/ios/Runner');
      await runnerDir.create(recursive: true);

      final infoPlistFile = File('${runnerDir.path}/Info.plist');
      await infoPlistFile.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleDisplayName</key>
\t<string>App</string>
\t<key>SomeKey</key>
\t<string>true</string>
</dict>
</plist>
''');

      final xcodeDir = Directory('${tempDir.path}/ios/Runner.xcodeproj');
      await xcodeDir.create(recursive: true);
      final pbxprojFile = File('${xcodeDir.path}/project.pbxproj');
      await pbxprojFile.writeAsString('''
buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
};
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        customInfoPlistEntries: {
          'SomeKey': true,
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await infoPlistFile.readAsString();

      expect(updatedContent, contains('<key>SomeKey</key>'));
      expect(updatedContent, contains('<true/>'));
      expect(updatedContent, isNot(contains('<string>true</string>')));
    });
  });
}
