import 'dart:io';
import 'package:flutter_flavor_orchestrator/src/models/flavor_config.dart';
import 'package:flutter_flavor_orchestrator/src/processors/android_processor.dart';
import 'package:flutter_flavor_orchestrator/src/utils/file_manager.dart';
import 'package:flutter_flavor_orchestrator/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late AndroidProcessor processor;
  late FileManager fileManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('android_test_');
    const logger = Logger();
    fileManager = FileManager(logger: logger, createBackups: false);
    processor = AndroidProcessor(
      fileManager: fileManager,
      logger: logger,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AndroidProcessor', () {
    test('updates AndroidManifest.xml package name', () async {
      // Create Android directory structure
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);

      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      await manifestFile.writeAsString(r'''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.old">
    <application
        android:label="Old App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await manifestFile.readAsString();

      expect(updatedContent, contains('package="com.example.dev"'));
      expect(updatedContent, contains('android:label="App Dev"'));
    });

    test('updates build.gradle applicationId', () async {
      // Create Android directory structure
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleFile = File('${buildGradleDir.path}/build.gradle');
      await buildGradleFile.writeAsString('''
android {
    compileSdkVersion 33
    
    defaultConfig {
        applicationId "com.example.old"
        minSdkVersion 21
        targetSdkVersion 33
    }
}
''');

      // Create minimal AndroidManifest.xml to avoid errors
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);
      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      await manifestFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.old">
    <application android:label="Old"></application>
</manifest>
''');

      const config = FlavorConfig(
        name: 'production',
        bundleId: 'com.example.app',
        appName: 'My App',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleFile.readAsString();

      expect(updatedContent, contains('applicationId "com.example.app"'));
    });

    test('updates SDK versions in build.gradle', () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleFile = File('${buildGradleDir.path}/build.gradle');
      await buildGradleFile.writeAsString('''
android {
    compileSdkVersion 33
    
    defaultConfig {
        applicationId "com.example.app"
        minSdkVersion 21
        targetSdkVersion 33
    }
}
''');

      // Create minimal AndroidManifest.xml
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);
      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      await manifestFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">
    <application android:label="App"></application>
</manifest>
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        androidMinSdkVersion: 23,
        androidTargetSdkVersion: 34,
        androidCompileSdkVersion: 34,
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleFile.readAsString();

      expect(updatedContent, contains('minSdkVersion 23'));
      expect(updatedContent, contains('targetSdkVersion 34'));
      expect(updatedContent, contains('compileSdkVersion 34'));
    });

    test('throws FileSystemException if android directory missing', () async {
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

    test('updates build.gradle.kts applicationId (Kotlin script)', () async {
      // Create Android directory structure
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleKtsFile =
          File('${buildGradleDir.path}/build.gradle.kts');
      await buildGradleKtsFile.writeAsString('''
android {
    compileSdk = 33
    
    defaultConfig {
        applicationId = "com.example.old"
        minSdk = 21
        targetSdk = 33
    }
}
''');

      // Create minimal AndroidManifest.xml
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);
      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      await manifestFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.old">
    <application android:label="Old"></application>
</manifest>
''');

      const config = FlavorConfig(
        name: 'production',
        bundleId: 'com.example.app',
        appName: 'My App',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleKtsFile.readAsString();

      expect(updatedContent, contains('applicationId = "com.example.app"'));
    });

    test('updates SDK versions in build.gradle.kts (Kotlin script)', () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleKtsFile =
          File('${buildGradleDir.path}/build.gradle.kts');
      await buildGradleKtsFile.writeAsString('''
android {
    compileSdk = 33
    
    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 21
        targetSdk = 33
    }
}
''');

      // Create minimal AndroidManifest.xml
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);
      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      await manifestFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">
    <application android:label="App"></application>
</manifest>
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        androidMinSdkVersion: 23,
        androidTargetSdkVersion: 34,
        androidCompileSdkVersion: 34,
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleKtsFile.readAsString();

      expect(updatedContent, contains('minSdk = 23'));
      expect(updatedContent, contains('targetSdk = 34'));
      expect(updatedContent, contains('compileSdk = 34'));
    });

    test('prefers .kts file when both build.gradle and build.gradle.kts exist',
        () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      // Create both .gradle and .gradle.kts files
      final buildGradleFile = File('${buildGradleDir.path}/build.gradle');
      await buildGradleFile.writeAsString('''
android {
    defaultConfig {
        applicationId "com.example.groovy"
    }
}
''');

      final buildGradleKtsFile =
          File('${buildGradleDir.path}/build.gradle.kts');
      await buildGradleKtsFile.writeAsString('''
android {
    defaultConfig {
        applicationId = "com.example.kotlin"
    }
}
''');

      // Create minimal AndroidManifest.xml
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);
      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      await manifestFile.writeAsString('''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.old">
    <application android:label="Old"></application>
</manifest>
''');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.new',
        appName: 'App Dev',
      );

      await processor.process(tempDir.path, config);

      // Should update .kts file (preferred)
      final ktsContent = await buildGradleKtsFile.readAsString();
      expect(ktsContent, contains('applicationId = "com.example.new"'));

      // Should NOT update .gradle file
      final gradleContent = await buildGradleFile.readAsString();
      expect(gradleContent, contains('applicationId "com.example.groovy"'));
    });
  });
}
