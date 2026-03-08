import 'dart:io';

import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';
import 'package:test/test.dart';

/// YAML file_mappings entry targeting the Android manifest.
///
/// Defined here to avoid the 81-char line limit imposed by
/// `lines_longer_than_80_chars`. Indentation is added at each usage site.
const _kManifestMapping =
    "'android/app/src/main/AndroidManifest.xml':"
    " 'configs/dev/AndroidManifest.xml'";

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
    tempDir =
        await Directory.systemTemp.createTemp('orchestrator_conflict_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FlavorOrchestrator conflict detection — applyFlavor', () {
    test(
        'apply succeeds when there are no conflicts',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.applyFlavor('dev', platforms: []);
      expect(result, isTrue);
    });

    test(
        'apply fails (returns false) when a file_mapping destination '
        'duplicates a platform operation destination without --force',
        () async {
      // The Android processor always writes AndroidManifest.xml.
      // A file_mapping to the same path creates a duplicate_destination
      // conflict.
      final srcFile = File(
        '${tempDir.path}/configs/dev/AndroidManifest.xml',
      );
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('<!-- manifest -->');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    $_kManifestMapping
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      // Include android so the platform operation is added to the plan.
      final result = await orchestrator.applyFlavor(
        'dev',
        platforms: ['android'],
        // force is false by default
      );
      expect(result, isFalse);
    });

    test(
        'apply succeeds with --force when a duplicate destination conflict '
        'exists',
        () async {
      final srcFile = File(
        '${tempDir.path}/configs/dev/AndroidManifest.xml',
      );
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('<!-- manifest -->');

      // Create the required Android files so the processor doesn't fail.
      final manifestFile = File(
        '${tempDir.path}/android/app/src/main/AndroidManifest.xml',
      );
      await manifestFile.create(recursive: true);
      await manifestFile.writeAsString(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<manifest package="com.example.dev">\n'
        '<application android:label="App Dev"></application>\n'
        '</manifest>',
      );
      final gradleFile =
          File('${tempDir.path}/android/app/build.gradle');
      await gradleFile.create(recursive: true);
      await gradleFile.writeAsString(
        'android { defaultConfig { applicationId "com.example.dev" } }',
      );

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    $_kManifestMapping
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.applyFlavor(
        'dev',
        platforms: ['android'],
        force: true,
      );
      expect(result, isTrue);
    });

    test(
        'apply fails before any file mutation when conflicts exist',
        () async {
      final srcFile = File(
        '${tempDir.path}/configs/dev/AndroidManifest.xml',
      );
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('<!-- manifest -->');

      // Create a destination that should NOT be touched if apply aborts.
      final destFile = File(
        '${tempDir.path}/lib/output.dart',
      );
      await destFile.create(recursive: true);
      await destFile.writeAsString('// original');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    $_kManifestMapping
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      await orchestrator.applyFlavor(
        'dev',
        platforms: ['android'],
        // force: false (default)
      );

      // The non-conflicting file must be unchanged.
      expect(await destFile.readAsString(), equals('// original'));
    });

    test(
        'apply succeeds with no conflicts and file_mappings are applied',
        () async {
      final srcFile =
          File('${tempDir.path}/configs/dev/app_config.dart');
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('// dev config');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config/app_config.dart': 'configs/dev/app_config.dart'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result =
          await orchestrator.applyFlavor('dev', platforms: []);
      expect(result, isTrue);

      final destFile =
          File('${tempDir.path}/lib/config/app_config.dart');
      expect(await destFile.exists(), isTrue);
      expect(await destFile.readAsString(), equals('// dev config'));
    });

    test(
        'apply fails when two file_mappings overlap (parent dir and child)',
        () async {
      // Create source files
      final srcDir =
          Directory('${tempDir.path}/resources/dev/themes');
      await srcDir.create(recursive: true);
      await File('${srcDir.path}/colors.dart').writeAsString('// c');

      final srcFile =
          File('${tempDir.path}/configs/dev/app_config.dart');
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('// cfg');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/theme': 'resources/dev/themes'
    'lib/theme/app_config.dart': 'configs/dev/app_config.dart'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result =
          await orchestrator.applyFlavor('dev', platforms: []);
      expect(result, isFalse);
    });
  });

  group('FlavorOrchestrator conflict detection — planFlavor', () {
    test('planFlavor returns plan regardless of conflicts', () async {
      // planFlavor does not enforce conflict guardrails — it is a read-only
      // preview.
      final srcFile = File(
        '${tempDir.path}/configs/dev/AndroidManifest.xml',
      );
      await srcFile.create(recursive: true);
      await srcFile.writeAsString('<!-- manifest -->');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    $_kManifestMapping
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      // Should not throw even with a conflicting plan.
      final plan = await orchestrator.planFlavor(
        'dev',
        platforms: ['android'],
      );
      expect(plan, isNotNull);
      expect(plan.flavorName, equals('dev'));
    });
  });
}
