import 'dart:io';

import 'package:flutter_flavor_orchestrator/src/models/execution_plan.dart';
import 'package:flutter_flavor_orchestrator/src/models/flavor_config.dart';
import 'package:flutter_flavor_orchestrator/src/models/operation_kind.dart';
import 'package:flutter_flavor_orchestrator/src/models/planned_operation.dart';
import 'package:flutter_flavor_orchestrator/src/processors/asset_processor.dart';
import 'package:flutter_flavor_orchestrator/src/utils/file_manager.dart';
import 'package:flutter_flavor_orchestrator/src/utils/logger.dart';
import 'package:test/test.dart';

void main() {
  group('OperationKind', () {
    test('has all expected values', () {
      expect(OperationKind.values, hasLength(4));
      expect(OperationKind.values, contains(OperationKind.copyFile));
      expect(OperationKind.values, contains(OperationKind.copyDirectory));
      expect(OperationKind.values, contains(OperationKind.writeFile));
      expect(OperationKind.values, contains(OperationKind.skip));
    });

    test('name returns lowercase string', () {
      expect(OperationKind.copyFile.name, equals('copyFile'));
      expect(OperationKind.copyDirectory.name, equals('copyDirectory'));
      expect(OperationKind.writeFile.name, equals('writeFile'));
      expect(OperationKind.skip.name, equals('skip'));
    });
  });

  group('PlannedOperation', () {
    test('creates instance with required fields', () {
      const op = PlannedOperation(
        kind: OperationKind.copyFile,
        description: 'Copy config.json',
      );

      expect(op.kind, equals(OperationKind.copyFile));
      expect(op.description, equals('Copy config.json'));
      expect(op.sourcePath, isNull);
      expect(op.destinationPath, isNull);
      expect(op.platform, isNull);
    });

    test('creates instance with all fields', () {
      const op = PlannedOperation(
        kind: OperationKind.copyFile,
        description: 'Copy google-services.json',
        sourcePath: 'configs/dev/google-services.json',
        destinationPath: 'android/app/google-services.json',
        platform: 'android',
      );

      expect(op.kind, equals(OperationKind.copyFile));
      expect(op.sourcePath, equals('configs/dev/google-services.json'));
      expect(op.destinationPath, equals('android/app/google-services.json'));
      expect(op.platform, equals('android'));
    });

    test('toJson includes all present fields', () {
      const op = PlannedOperation(
        kind: OperationKind.copyFile,
        description: 'Copy google-services.json',
        sourcePath: 'configs/dev/google-services.json',
        destinationPath: 'android/app/google-services.json',
        platform: 'android',
      );

      final json = op.toJson();

      expect(json['kind'], equals('copyFile'));
      expect(json['description'], equals('Copy google-services.json'));
      expect(json['source_path'], equals('configs/dev/google-services.json'));
      expect(
        json['destination_path'],
        equals('android/app/google-services.json'),
      );
      expect(json['platform'], equals('android'));
    });

    test('toJson omits null optional fields', () {
      const op = PlannedOperation(
        kind: OperationKind.writeFile,
        description: 'Update AndroidManifest.xml',
      );

      final json = op.toJson();

      expect(json.containsKey('source_path'), isFalse);
      expect(json.containsKey('destination_path'), isFalse);
      expect(json.containsKey('platform'), isFalse);
    });

    test('toString includes kind and description', () {
      const op = PlannedOperation(
        kind: OperationKind.skip,
        description: 'Skip missing source',
      );

      expect(op.toString(), contains('skip'));
      expect(op.toString(), contains('Skip missing source'));
    });
  });

  group('ExecutionPlan', () {
    test('creates instance with required fields', () {
      const plan = ExecutionPlan(
        flavorName: 'dev',
        operations: [],
        platforms: ['android', 'ios'],
      );

      expect(plan.flavorName, equals('dev'));
      expect(plan.operations, isEmpty);
      expect(plan.platforms, equals(['android', 'ios']));
    });

    test('totalOperations counts all operations', () {
      const plan = ExecutionPlan(
        flavorName: 'dev',
        operations: [
          PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'Copy A',
          ),
          PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'Write B',
          ),
          PlannedOperation(
            kind: OperationKind.skip,
            description: 'Skip C',
          ),
        ],
        platforms: ['android'],
      );

      expect(plan.totalOperations, equals(3));
    });

    test('skippedOperations counts only skip operations', () {
      const plan = ExecutionPlan(
        flavorName: 'dev',
        operations: [
          PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'Copy A',
          ),
          PlannedOperation(
            kind: OperationKind.skip,
            description: 'Skip B',
          ),
          PlannedOperation(
            kind: OperationKind.skip,
            description: 'Skip C',
          ),
        ],
        platforms: ['android'],
      );

      expect(plan.skippedOperations, equals(2));
    });

    test('activeOperations excludes skip operations', () {
      const plan = ExecutionPlan(
        flavorName: 'staging',
        operations: [
          PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'Write A',
          ),
          PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'Copy B',
          ),
          PlannedOperation(
            kind: OperationKind.skip,
            description: 'Skip C',
          ),
        ],
        platforms: ['ios'],
      );

      expect(plan.activeOperations, equals(2));
    });

    test('forPlatform filters by platform', () {
      const plan = ExecutionPlan(
        flavorName: 'dev',
        operations: [
          PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'Android op',
            platform: 'android',
          ),
          PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'iOS op',
            platform: 'ios',
          ),
          PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'Asset op',
            platform: 'assets',
          ),
        ],
        platforms: ['android', 'ios'],
      );

      expect(plan.forPlatform('android'), hasLength(1));
      expect(
        plan.forPlatform('android').first.description,
        equals('Android op'),
      );
      expect(plan.forPlatform('ios'), hasLength(1));
      expect(plan.forPlatform('assets'), hasLength(1));
    });

    test('toJson contains expected top-level keys', () {
      const plan = ExecutionPlan(
        flavorName: 'production',
        operations: [
          PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'Update manifest',
            platform: 'android',
          ),
        ],
        platforms: ['android'],
      );

      final json = plan.toJson();

      expect(json['flavor'], equals('production'));
      expect(json['platforms'], equals(['android']));
      expect(json['total_operations'], equals(1));
      expect(json['active_operations'], equals(1));
      expect(json['skipped_operations'], equals(0));
      expect(json['operations'], isA<List<Map<String, Object?>>>());
      expect(json['operations'], hasLength(1));
    });

    test('toJson operations list contains serialised operations', () {
      const plan = ExecutionPlan(
        flavorName: 'dev',
        operations: [
          PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'Copy config',
            sourcePath: 'src/config.dart',
            destinationPath: 'lib/config.dart',
            platform: 'assets',
          ),
        ],
        platforms: ['android', 'ios'],
      );

      final json = plan.toJson();
      final ops = json['operations'] as List;
      final firstOp = ops.first as Map<String, Object?>;

      expect(firstOp['kind'], equals('copyFile'));
      expect(firstOp['description'], equals('Copy config'));
      expect(firstOp['source_path'], equals('src/config.dart'));
    });

    test('platform constants have expected values', () {
      expect(ExecutionPlan.platformAndroid, equals('android'));
      expect(ExecutionPlan.platformIos, equals('ios'));
      expect(ExecutionPlan.platformAssets, equals('assets'));
    });

    test('toString contains flavor and platform info', () {
      const plan = ExecutionPlan(
        flavorName: 'staging',
        operations: [],
        platforms: ['android', 'ios'],
      );

      expect(plan.toString(), contains('staging'));
      expect(plan.toString(), contains('android'));
    });
  });

  group('AssetProcessor.planFileMappings', () {
    late Directory tempDir;
    late AssetProcessor processor;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('plan_test_');
      const logger = Logger();
      final fileManager = FileManager(logger: logger, createBackups: false);
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

    test('returns empty list when no file mappings defined', () async {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      final ops = await processor.planFileMappings(config);

      expect(ops, isEmpty);
    });

    test('returns copyFile operation for existing file source', () async {
      final sourceDir = Directory('${tempDir.path}/configs/dev');
      await sourceDir.create(recursive: true);
      final sourceFile = File('${sourceDir.path}/config.json');
      await sourceFile.writeAsString('{}');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {'lib/config.json': 'configs/dev/config.json'},
      );

      final ops = await processor.planFileMappings(config);

      expect(ops, hasLength(1));
      expect(ops.first.kind, equals(OperationKind.copyFile));
      expect(ops.first.sourcePath, equals('configs/dev/config.json'));
      expect(ops.first.destinationPath, equals('lib/config.json'));
      expect(ops.first.platform, equals(ExecutionPlan.platformAssets));
    });

    test('returns copyDirectory operation for existing directory source',
        () async {
      final sourceDir = await Directory('${tempDir.path}/assets/icons').create(
        recursive: true,
      );
      await File('${sourceDir.path}/icon.png').writeAsString('PNG');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {'android/res': 'assets/icons'},
      );

      final ops = await processor.planFileMappings(config);

      expect(ops, hasLength(1));
      expect(ops.first.kind, equals(OperationKind.copyDirectory));
      expect(ops.first.sourcePath, equals('assets/icons'));
      expect(ops.first.destinationPath, equals('android/res'));
    });

    test('returns skip operation for missing source path', () async {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {'lib/config.json': 'nonexistent/config.json'},
      );

      final ops = await processor.planFileMappings(config);

      expect(ops, hasLength(1));
      expect(ops.first.kind, equals(OperationKind.skip));
      expect(ops.first.sourcePath, equals('nonexistent/config.json'));
    });

    test('does not mutate file system', () async {
      final sourceDir = Directory('${tempDir.path}/src');
      await sourceDir.create(recursive: true);
      await File('${sourceDir.path}/file.txt').writeAsString('data');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {'lib/file.txt': 'src/file.txt'},
      );

      await processor.planFileMappings(config);

      // Destination should NOT have been created
      final dest = File('${tempDir.path}/lib/file.txt');
      expect(await dest.exists(), isFalse);
    });

    test('returns operations for multiple mappings in declaration order',
        () async {
      final src1 = File('${tempDir.path}/a.dart');
      await src1.writeAsString('a');
      final src2 = File('${tempDir.path}/b.dart');
      await src2.writeAsString('b');

      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        fileMappings: {
          'lib/a.dart': 'a.dart',
          'lib/b.dart': 'b.dart',
        },
      );

      final ops = await processor.planFileMappings(config);

      expect(ops, hasLength(2));
      expect(ops[0].sourcePath, equals('a.dart'));
      expect(ops[1].sourcePath, equals('b.dart'));
    });
  });
}
