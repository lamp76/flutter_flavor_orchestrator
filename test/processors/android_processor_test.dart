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

    test('preserves AndroidManifest.xml indentation with spaces', () async {
      // Create Android directory structure
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);

      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      const originalContent = r'''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.old">
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:label="Old App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity">
        </activity>
    </application>
</manifest>''';
      await manifestFile.writeAsString(originalContent);

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await manifestFile.readAsString();

      // Verify package and label were updated
      expect(updatedContent, contains('package="com.example.dev"'));
      expect(updatedContent, contains('android:label="App Dev"'));

      // Verify indentation is preserved
      // (4 spaces for application, 8 for activity)
      expect(updatedContent, contains('\n    <application'));
      expect(updatedContent, contains('\n        <activity'));
      expect(updatedContent, contains('\n    <uses-permission'));

      // Verify structure is preserved
      expect(updatedContent, contains('<uses-permission'));
      expect(
        updatedContent,
        contains(r'android:name="${applicationName}"'),
      );
    });

    test('preserves AndroidManifest.xml indentation with tabs', () async {
      // Create Android directory structure
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);

      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      const originalContent = r'''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
	package="com.example.old">
	<application
		android:label="Old App"
		android:name="${applicationName}">
		<activity android:name=".MainActivity"/>
	</application>
</manifest>''';
      await manifestFile.writeAsString(originalContent);

      const config = FlavorConfig(
        name: 'staging',
        bundleId: 'com.example.staging',
        appName: 'App Staging',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await manifestFile.readAsString();

      // Verify package and label were updated
      expect(updatedContent, contains('package="com.example.staging"'));
      expect(updatedContent, contains('android:label="App Staging"'));

      // Verify tab indentation is preserved
      expect(updatedContent, contains('\n\t<application'));
      expect(updatedContent, contains('\n\t\t<activity'));
    });

    test('adds metadata with correct indentation detection', () async {
      // Create Android directory structure
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);

      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      const originalContent = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">
    <application
        android:label="My App">
        <activity android:name=".MainActivity"/>
    </application>
</manifest>''';
      await manifestFile.writeAsString(originalContent);

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        metadata: {
          'com.google.android.geo.API_KEY': 'test_api_key',
          'firebase.messaging.default_notification_icon':
              '@drawable/ic_notification',
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await manifestFile.readAsString();

      // Verify metadata was added
      expect(
        updatedContent,
        contains('android:name="com.google.android.geo.API_KEY"'),
      );
      expect(updatedContent, contains('android:value="test_api_key"'));
      expect(
        updatedContent,
        contains(
          'android:name="firebase.messaging.default_notification_icon"',
        ),
      );
      expect(
        updatedContent,
        contains('android:value="@drawable/ic_notification"'),
      );

      // Verify indentation is correct (should match activity's indentation)
      expect(updatedContent, contains('\n        <meta-data'));
    });

    test('updates existing metadata while preserving structure', () async {
      // Create Android directory structure
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);

      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      const originalContent = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">
    <application
        android:label="My App">
        <activity android:name=".MainActivity"/>
        <meta-data android:name="test.key" android:value="old_value" />
    </application>
</manifest>''';
      await manifestFile.writeAsString(originalContent);

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        metadata: {
          'test.key': 'new_value',
        },
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await manifestFile.readAsString();

      // Verify metadata was updated
      expect(updatedContent, contains('android:value="new_value"'));
      expect(updatedContent, isNot(contains('android:value="old_value"')));

      // Verify only one instance of the metadata exists
      expect(
        'android:name="test.key"'.allMatches(updatedContent).length,
        equals(1),
      );
    });

    test('preserves mixed whitespace in AndroidManifest.xml', () async {
      // Create Android directory structure
      final manifestDir = Directory(
        '${tempDir.path}/android/app/src/main',
      );
      await manifestDir.create(recursive: true);

      final manifestFile = File('${manifestDir.path}/AndroidManifest.xml');
      // Mixed spacing around attributes
      const originalContent = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package  =  "com.example.old"  >
    <application
        android:label   =   "Old App"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>''';
      await manifestFile.writeAsString(originalContent);

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await manifestFile.readAsString();

      // Verify values were updated
      expect(updatedContent, contains('com.example.dev'));
      expect(updatedContent, contains('App Dev'));

      // Verify other attributes and structure remain
      expect(updatedContent, contains('android:icon="@mipmap/ic_launcher"'));
    });

    test('updates SDK versions with flutter variable references in Kotlin',
        () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleKtsFile =
          File('${buildGradleDir.path}/build.gradle.kts');
      await buildGradleKtsFile.writeAsString('''
android {
    compileSdk = flutter.compileSdkVersion
    
    defaultConfig {
        applicationId = "com.example.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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
        name: 'production',
        bundleId: 'com.example.prod',
        appName: 'App Prod',
        androidMinSdkVersion: 24,
        androidTargetSdkVersion: 34,
        androidCompileSdkVersion: 34,
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleKtsFile.readAsString();

      expect(updatedContent, contains('minSdk = 24'));
      expect(updatedContent, contains('targetSdk = 34'));
      expect(updatedContent, contains('compileSdk = 34'));
      expect(updatedContent, isNot(contains('flutter.minSdkVersion')));
      expect(updatedContent, isNot(contains('flutter.targetSdkVersion')));
      expect(updatedContent, isNot(contains('flutter.compileSdkVersion')));
    });

    test('inserts SDK versions when missing in build.gradle.kts', () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleKtsFile =
          File('${buildGradleDir.path}/build.gradle.kts');
      await buildGradleKtsFile.writeAsString('''
android {
    namespace = "com.example.app"
    
    defaultConfig {
        applicationId = "com.example.app"
        versionCode = 1
        versionName = "1.0"
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

    test('inserts SDK versions when missing in build.gradle (Groovy)',
        () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleFile = File('${buildGradleDir.path}/build.gradle');
      await buildGradleFile.writeAsString('''
android {
    namespace "com.example.app"
    
    defaultConfig {
        applicationId "com.example.app"
        versionCode 1
        versionName "1.0"
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
        name: 'staging',
        bundleId: 'com.example.staging',
        appName: 'App Staging',
        androidMinSdkVersion: 22,
        androidTargetSdkVersion: 33,
        androidCompileSdkVersion: 33,
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleFile.readAsString();

      expect(updatedContent, contains('minSdkVersion 22'));
      expect(updatedContent, contains('targetSdkVersion 33'));
      expect(updatedContent, contains('compileSdkVersion 33'));
    });

    test(
        'updates SDK versions with compileSdk shorthand in build.gradle '
        '(Groovy)', () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleFile = File('${buildGradleDir.path}/build.gradle');
      await buildGradleFile.writeAsString('''
android {
    compileSdk 30
    
    defaultConfig {
        applicationId "com.example.app"
        minSdkVersion 21
        targetSdkVersion 30
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
        androidMinSdkVersion: 24,
        androidTargetSdkVersion: 34,
        androidCompileSdkVersion: 34,
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleFile.readAsString();

      expect(updatedContent, contains('minSdkVersion 24'));
      expect(updatedContent, contains('targetSdkVersion 34'));
      expect(updatedContent, contains('compileSdk 34'));
    });

    test('validates build.gradle.kts structure after modifications', () async {
      final buildGradleDir = Directory('${tempDir.path}/android/app');
      await buildGradleDir.create(recursive: true);

      final buildGradleKtsFile =
          File('${buildGradleDir.path}/build.gradle.kts');
      await buildGradleKtsFile.writeAsString('''
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.app"
    compileSdk = flutter.compileSdkVersion
    
    defaultConfig {
        applicationId = "com.example.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"
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
        name: 'production',
        bundleId: 'com.example.prod',
        appName: 'App Prod',
        androidMinSdkVersion: 23,
        androidTargetSdkVersion: 34,
        androidCompileSdkVersion: 34,
      );

      await processor.process(tempDir.path, config);

      final updatedContent = await buildGradleKtsFile.readAsString();

      // Verify SDK versions were updated
      expect(updatedContent, contains('minSdk = 23'));
      expect(updatedContent, contains('targetSdk = 34'));
      expect(updatedContent, contains('compileSdk = 34'));

      // Verify applicationId was updated
      expect(updatedContent, contains('applicationId = "com.example.prod"'));

      // Verify structure is maintained
      expect(updatedContent, contains('namespace = "com.example.app"'));
      expect(updatedContent, contains('versionCode = 1'));
      expect(updatedContent, contains('versionName = "1.0"'));

      // Ensure no duplicate entries
      expect('minSdk'.allMatches(updatedContent).length, equals(1));
      expect('targetSdk'.allMatches(updatedContent).length, equals(1));
      expect('compileSdk'.allMatches(updatedContent).length, equals(1));
    });
  });
}
