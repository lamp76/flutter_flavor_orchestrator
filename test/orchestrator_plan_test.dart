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
    tempDir = await Directory.systemTemp.createTemp('plan_cmd_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FlavorOrchestrator.planFlavor', () {
    test('returns ExecutionPlan with correct flavor name', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      expect(plan.flavorName, equals('dev'));
    });

    test('plan includes android and ios platforms by default', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      expect(plan.platforms, contains('android'));
      expect(plan.platforms, contains('ios'));
    });

    test('plan restricted to android contains only android operations',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor(
        'dev',
        platforms: ['android'],
      );

      expect(plan.platforms, equals(['android']));
      expect(plan.forPlatform('ios'), isEmpty);
      expect(plan.forPlatform('android'), isNotEmpty);
    });

    test('plan restricted to ios contains only ios operations', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor(
        'dev',
        platforms: ['ios'],
      );

      expect(plan.platforms, equals(['ios']));
      expect(plan.forPlatform('android'), isEmpty);
      expect(plan.forPlatform('ios'), isNotEmpty);
    });

    test('plan includes asset copyFile operation for existing file mapping',
        () async {
      // Create the source file the mapping references
      final srcDir = Directory('${tempDir.path}/configs/dev');
      await srcDir.create(recursive: true);
      await File('${srcDir.path}/config.dart').writeAsString('// config');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config.dart': 'configs/dev/config.dart'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      final assetOps = plan.forPlatform(ExecutionPlan.platformAssets);
      expect(assetOps, hasLength(1));
      expect(assetOps.first.kind, equals(OperationKind.copyFile));
      expect(assetOps.first.sourcePath, equals('configs/dev/config.dart'));
      expect(assetOps.first.destinationPath, equals('lib/config.dart'));
    });

    test('plan includes skip operation for missing file mapping source',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config.dart': 'missing/config.dart'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      final assetOps = plan.forPlatform(ExecutionPlan.platformAssets);
      expect(assetOps, hasLength(1));
      expect(assetOps.first.kind, equals(OperationKind.skip));
    });

    test('planFlavor does not mutate any files', () async {
      final srcDir = Directory('${tempDir.path}/src');
      await srcDir.create(recursive: true);
      await File('${srcDir.path}/file.txt').writeAsString('data');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/file.txt': 'src/file.txt'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      await orchestrator.planFlavor('dev');

      // Destination must NOT have been created
      final dest = File('${tempDir.path}/lib/file.txt');
      expect(await dest.exists(), isFalse);
    });

    test('operation list order: android -> ios -> assets', () async {
      final srcDir = Directory('${tempDir.path}/configs/dev');
      await srcDir.create(recursive: true);
      await File('${srcDir.path}/config.dart').writeAsString('// cfg');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config.dart': 'configs/dev/config.dart'
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');

      final platforms =
          plan.operations.map((op) => op.platform).whereType<String>().toList();

      // First android ops, then ios ops, then assets
      final firstAssetIdx =
          platforms.indexWhere((p) => p == ExecutionPlan.platformAssets);
      final lastAndroidIdx =
          platforms.lastIndexWhere((p) => p == ExecutionPlan.platformAndroid);
      final lastIosIdx =
          platforms.lastIndexWhere((p) => p == ExecutionPlan.platformIos);

      expect(firstAssetIdx, greaterThan(lastAndroidIdx));
      expect(firstAssetIdx, greaterThan(lastIosIdx));
    });

    test('toJson returns stable top-level keys', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');
      final json = plan.toJson();

      expect(json, containsPair('flavor', 'dev'));
      expect(json, contains('platforms'));
      expect(json, contains('total_operations'));
      expect(json, contains('active_operations'));
      expect(json, contains('skipped_operations'));
      expect(json, contains('operations'));
      expect(json['operations'], isA<List<Object?>>());
    });

    test('toJson operations list entries have required keys', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan = await orchestrator.planFlavor('dev');
      final ops = plan.toJson()['operations'] as List;

      expect(ops, isNotEmpty);
      for (final op in ops) {
        final opMap = op as Map<String, Object?>;
        expect(opMap, contains('kind'));
        expect(opMap, contains('description'));
      }
    });

    test('throws FormatException for unknown flavor', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);

      expect(
        () => orchestrator.planFlavor('nonexistent'),
        throwsA(isA<FormatException>()),
      );
    });

    test('plan with provisioning adds google-services copy operation',
        () async {
      final provDir = Directory('${tempDir.path}/configs/dev');
      await provDir.create(recursive: true);
      await File('${provDir.path}/google-services.json').writeAsString('{}');

      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  provisioning:
    android_google_services: configs/dev/google-services.json
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final plan =
          await orchestrator.planFlavor('dev', platforms: ['android']);

      final androidOps = plan.forPlatform(ExecutionPlan.platformAndroid);
      final copyOp = androidOps.firstWhere(
        (op) => op.kind == OperationKind.copyFile,
        orElse: () => throw StateError('No copyFile op found'),
      );
      expect(
        copyOp.sourcePath,
        equals('configs/dev/google-services.json'),
      );
    });
  });
}
