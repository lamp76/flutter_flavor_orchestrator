import 'dart:convert';
import 'dart:io';

import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a minimal valid Flutter project in [dir] with the supplied
/// [configYaml] written to `flavor_config.yaml`.
Future<void> _setupProject(Directory dir, String configYaml) async {
  await File('${dir.path}/pubspec.yaml').writeAsString(
    'name: test_app\nflutter:\n  uses-material-design: true\n',
  );
  await File('${dir.path}/flavor_config.yaml').writeAsString(configYaml);
}

/// Writes a minimal Android project structure under [dir].
Future<void> _setupAndroid(Directory dir) async {
  final manifestDir = Directory(
    '${dir.path}/android/app/src/main',
  );
  await manifestDir.create(recursive: true);
  await File('${manifestDir.path}/AndroidManifest.xml').writeAsString(
    '<manifest package="com.example.test"></manifest>',
  );
  await File('${dir.path}/android/app/build.gradle').writeAsString(
    'android { defaultConfig { applicationId "com.example.test" } }',
  );
}

/// Writes a minimal iOS project structure under [dir].
Future<void> _setupIos(Directory dir) async {
  final runnerDir = Directory('${dir.path}/ios/Runner');
  await runnerDir.create(recursive: true);
  await File('${runnerDir.path}/Info.plist').writeAsString(
    '<?xml version="1.0"?><plist version="1.0"><dict></dict></plist>',
  );
  await Directory('${dir.path}/ios/Runner.xcodeproj').create(recursive: true);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('doctor_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ── Diagnostic model ────────────────────────────────────────────────────────

  group('Diagnostic model', () {
    test('toJson includes required fields', () {
      const d = Diagnostic(
        code: 'test_code',
        severity: DiagnosticSeverity.error,
        message: 'Something is wrong.',
        suggestion: 'Fix it.',
        path: '/some/path',
      );

      final json = d.toJson();

      expect(json, containsPair('code', 'test_code'));
      expect(json, containsPair('severity', 'error'));
      expect(json, containsPair('message', 'Something is wrong.'));
      expect(json, containsPair('suggestion', 'Fix it.'));
      expect(json, containsPair('path', '/some/path'));
    });

    test('toJson omits null suggestion and path', () {
      const d = Diagnostic(
        code: 'info_code',
        severity: DiagnosticSeverity.info,
        message: 'All good.',
      );

      final json = d.toJson();

      expect(json, isNot(contains('suggestion')));
      expect(json, isNot(contains('path')));
    });

    test('severity values are error, warning, info', () {
      expect(DiagnosticSeverity.values.map((s) => s.name), containsAll(['error', 'warning', 'info']));
    });
  });

  // ── DoctorResult model ──────────────────────────────────────────────────────

  group('DoctorResult model', () {
    test('hasErrors is false when no errors', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(code: 'a', severity: DiagnosticSeverity.info, message: 'ok'),
        Diagnostic(code: 'b', severity: DiagnosticSeverity.warning, message: 'warn'),
      ]);
      expect(result.hasErrors, isFalse);
    });

    test('hasErrors is true when any error exists', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(code: 'a', severity: DiagnosticSeverity.info, message: 'ok'),
        Diagnostic(code: 'b', severity: DiagnosticSeverity.error, message: 'err'),
      ]);
      expect(result.hasErrors, isTrue);
    });

    test('errors / warnings / infos filter correctly', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(code: 'e1', severity: DiagnosticSeverity.error, message: 'err'),
        Diagnostic(code: 'w1', severity: DiagnosticSeverity.warning, message: 'warn'),
        Diagnostic(code: 'i1', severity: DiagnosticSeverity.info, message: 'info'),
        Diagnostic(code: 'e2', severity: DiagnosticSeverity.error, message: 'err2'),
      ]);
      expect(result.errors, hasLength(2));
      expect(result.warnings, hasLength(1));
      expect(result.infos, hasLength(1));
    });

    test('toJson has stable top-level keys', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(code: 'err', severity: DiagnosticSeverity.error, message: 'm'),
      ]);

      final json = result.toJson();

      expect(json, contains('healthy'));
      expect(json, contains('error_count'));
      expect(json, contains('warning_count'));
      expect(json, contains('info_count'));
      expect(json, contains('diagnostics'));
    });

    test('toJson healthy is false when errors exist', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(code: 'err', severity: DiagnosticSeverity.error, message: 'm'),
      ]);
      expect(result.toJson()['healthy'], isFalse);
    });

    test('toJson healthy is true when no errors', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(code: 'w', severity: DiagnosticSeverity.warning, message: 'm'),
      ]);
      expect(result.toJson()['healthy'], isTrue);
    });

    test('toJson is JSON-encodable', () {
      final result = DoctorResult(diagnostics: [
        Diagnostic(
          code: 'info',
          severity: DiagnosticSeverity.info,
          message: 'All good.',
          suggestion: 'Nothing to do.',
          path: '/project',
        ),
      ]);
      expect(() => jsonEncode(result.toJson()), returnsNormally);
    });
  });

  // ── Doctor.run — project-root check ────────────────────────────────────────

  group('Doctor — project root check', () {
    test('reports error when pubspec.yaml is absent', () async {
      // No pubspec.yaml in tempDir.
      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(result.hasErrors, isTrue);
      expect(
        result.errors.map((d) => d.code),
        contains('no_pubspec'),
      );
    });

    test('returns no no_pubspec error when pubspec.yaml is present', () async {
      await _setupProject(tempDir, 'dev:\n  bundle_id: com.x.dev\n  app_name: X\n');
      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(result.errors.map((d) => d.code), isNot(contains('no_pubspec')));
    });
  });

  // ── Doctor.run — config checks ──────────────────────────────────────────────

  group('Doctor — config checks', () {
    test('reports error when flavor config is absent', () async {
      // Only pubspec.yaml, no flavor_config.yaml.
      await File('${tempDir.path}/pubspec.yaml').writeAsString(
        'name: test_app\nflutter:\n  uses-material-design: true\n',
      );

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(result.hasErrors, isTrue);
      expect(result.errors.map((d) => d.code), contains('no_config'));
    });

    test('reports error when flavor YAML is invalid', () async {
      await File('${tempDir.path}/pubspec.yaml').writeAsString(
        'name: test_app\nflutter:\n  uses-material-design: true\n',
      );
      await File('${tempDir.path}/flavor_config.yaml')
          .writeAsString('{ invalid: yaml: : : :\n');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(result.hasErrors, isTrue);
      expect(
        result.errors.map((d) => d.code),
        contains('config_parse_error'),
      );
    });

    test('reports error when no flavor definitions found', () async {
      await File('${tempDir.path}/pubspec.yaml').writeAsString(
        'name: test_app\nflutter:\n  uses-material-design: true\n',
      );
      // Valid YAML but only schema_version, no flavor blocks.
      await File('${tempDir.path}/flavor_config.yaml')
          .writeAsString('schema_version: 1\n');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(result.hasErrors, isTrue);
      expect(
        result.errors.map((d) => d.code),
        contains('no_flavor_config_key'),
      );
    });

    test('reports error for missing bundle_id in flavor', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: ""
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(result.hasErrors, isTrue);
      expect(
        result.errors.map((d) => d.code),
        contains('config_parse_error'),
      );
    });

    test('reports info when config is valid', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.infos.map((d) => d.code),
        contains('config_valid'),
      );
    });

    test('reports warning when schema_version is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.warnings.map((d) => d.code),
        contains('schema_version_missing'),
      );
    });

    test('no schema_version_missing warning when schema_version present', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.warnings.map((d) => d.code),
        isNot(contains('schema_version_missing')),
      );
    });
  });

  // ── Doctor.run — platform checks ──────────────────────────────────────────

  group('Doctor — Android platform checks', () {
    test('warns when android/ directory is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // No android/ directory.
      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.diagnostics.map((d) => d.code),
        contains('platform_dir_missing'),
      );
    });

    test('reports error when AndroidManifest.xml is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // Create android/ but without AndroidManifest.xml.
      await Directory('${tempDir.path}/android/app/src/main')
          .create(recursive: true);
      await File('${tempDir.path}/android/app/build.gradle')
          .writeAsString('');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.errors.map((d) => d.code),
        contains('android_manifest_missing'),
      );
    });

    test('reports error when build.gradle and build.gradle.kts are both absent',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // Create android/app/src/main/AndroidManifest.xml but no build.gradle.
      final manifestDir =
          Directory('${tempDir.path}/android/app/src/main');
      await manifestDir.create(recursive: true);
      await File('${manifestDir.path}/AndroidManifest.xml')
          .writeAsString('<manifest/>');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.errors.map((d) => d.code),
        contains('android_build_gradle_missing'),
      );
    });

    test('no android errors when android project is complete', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      await _setupAndroid(tempDir);

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(result.errors.map((d) => d.code), isNot(contains('android_manifest_missing')));
      expect(result.errors.map((d) => d.code), isNot(contains('android_build_gradle_missing')));
    });

    test('accepts build.gradle.kts as alternative to build.gradle', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      final manifestDir =
          Directory('${tempDir.path}/android/app/src/main');
      await manifestDir.create(recursive: true);
      await File('${manifestDir.path}/AndroidManifest.xml')
          .writeAsString('<manifest/>');
      await Directory('${tempDir.path}/android/app').create(recursive: true);
      await File('${tempDir.path}/android/app/build.gradle.kts')
          .writeAsString('android {}');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.errors.map((d) => d.code),
        isNot(contains('android_build_gradle_missing')),
      );
    });
  });

  group('Doctor — iOS platform checks', () {
    test('warns when ios/ directory is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['ios']);

      expect(
        result.diagnostics.map((d) => d.code),
        contains('platform_dir_missing'),
      );
    });

    test('reports error when Info.plist is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // Create ios/ directory but without Info.plist.
      await Directory('${tempDir.path}/ios/Runner').create(recursive: true);
      await Directory('${tempDir.path}/ios/Runner.xcodeproj')
          .create(recursive: true);

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['ios']);

      expect(
        result.errors.map((d) => d.code),
        contains('ios_info_plist_missing'),
      );
    });

    test('reports error when Runner.xcodeproj is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // Create ios/Runner with Info.plist but no .xcodeproj.
      await Directory('${tempDir.path}/ios/Runner').create(recursive: true);
      await File('${tempDir.path}/ios/Runner/Info.plist')
          .writeAsString('<plist/>');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['ios']);

      expect(
        result.errors.map((d) => d.code),
        contains('ios_xcodeproj_missing'),
      );
    });

    test('no ios errors when ios project is complete', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      await _setupIos(tempDir);

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['ios']);

      expect(result.errors.map((d) => d.code), isNot(contains('ios_info_plist_missing')));
      expect(result.errors.map((d) => d.code), isNot(contains('ios_xcodeproj_missing')));
    });
  });

  // ── Doctor.run — file reference checks ─────────────────────────────────────

  group('Doctor — file reference checks', () {
    test('warns when provisioning android_google_services source is absent',
        () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  provisioning:
    android_google_services: configs/dev/google-services.json
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.warnings.map((d) => d.code),
        contains('provisioning_file_missing'),
      );
    });

    test('no provisioning warning when source file exists', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  provisioning:
    android_google_services: configs/dev/google-services.json
''');
      // Create the provisioning source file.
      await Directory('${tempDir.path}/configs/dev').create(recursive: true);
      await File('${tempDir.path}/configs/dev/google-services.json')
          .writeAsString('{}');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.warnings.map((d) => d.code),
        isNot(contains('provisioning_file_missing')),
      );
    });

    test('warns when ios provisioning source is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  provisioning:
    ios_google_service: configs/dev/GoogleService-Info.plist
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['ios']);

      expect(
        result.warnings.map((d) => d.code),
        contains('provisioning_file_missing'),
      );
    });

    test('skips ios provisioning check when platform is android-only', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  provisioning:
    ios_google_service: configs/dev/GoogleService-Info.plist
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      // Only android — ios provisioning check should be skipped.
      final result = await doctor.run(platforms: ['android']);

      expect(
        result.warnings.map((d) => d.code),
        isNot(contains('provisioning_file_missing')),
      );
    });

    test('warns when file_mappings source is absent', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config.dart': 'configs/dev/config.dart'
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.warnings.map((d) => d.code),
        contains('file_mapping_source_missing'),
      );
    });

    test('no file_mapping warning when source file exists', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/config.dart': 'configs/dev/config.dart'
''');
      await Directory('${tempDir.path}/configs/dev').create(recursive: true);
      await File('${tempDir.path}/configs/dev/config.dart')
          .writeAsString('// config');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.warnings.map((d) => d.code),
        isNot(contains('file_mapping_source_missing')),
      );
    });

    test('no file_mapping warning when source is a directory', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
  file_mappings:
    'lib/theme': 'resources/dev/themes'
''');
      await Directory('${tempDir.path}/resources/dev/themes')
          .create(recursive: true);

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.warnings.map((d) => d.code),
        isNot(contains('file_mapping_source_missing')),
      );
    });
  });

  // ── Doctor.run — platform filtering ────────────────────────────────────────

  group('Doctor — platform filtering', () {
    test('no platform checks when platforms is empty', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // No android/ or ios/ dirs — but we don't check platforms.
      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: []);

      expect(
        result.diagnostics.map((d) => d.code),
        isNot(contains('platform_dir_missing')),
      );
    });

    test('only android checks when platforms is [android]', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['android']);

      final codes = result.diagnostics.map((d) => d.code).toSet();
      expect(codes, isNot(contains('ios_info_plist_missing')));
      expect(codes, isNot(contains('ios_xcodeproj_missing')));
    });

    test('only ios checks when platforms is [ios]', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(projectRoot: tempDir.path);
      final result = await doctor.run(platforms: ['ios']);

      final codes = result.diagnostics.map((d) => d.code).toSet();
      expect(codes, isNot(contains('android_manifest_missing')));
      expect(codes, isNot(contains('android_build_gradle_missing')));
    });
  });

  // ── FlavorOrchestrator.runDoctor ────────────────────────────────────────────

  group('FlavorOrchestrator.runDoctor', () {
    test('returns DoctorResult without mutating files', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      await _setupAndroid(tempDir);
      await _setupIos(tempDir);

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final before =
          tempDir.listSync(recursive: true).map((f) => f.path).toList()..sort();

      final result = await orchestrator.runDoctor();

      final after =
          tempDir.listSync(recursive: true).map((f) => f.path).toList()..sort();

      // No new files should be created.
      expect(after, equals(before));
      expect(result, isA<DoctorResult>());
    });

    test('returns healthy result for a complete project', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      await _setupAndroid(tempDir);
      await _setupIos(tempDir);

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.runDoctor();

      expect(result.hasErrors, isFalse);
    });

    test('respects platforms parameter', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');
      // No ios/ directory but we only check android.
      await _setupAndroid(tempDir);

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.runDoctor(platforms: ['android']);

      expect(
        result.diagnostics.map((d) => d.code),
        isNot(contains('platform_dir_missing')),
      );
    });
  });

  // ── JSON output contract ────────────────────────────────────────────────────

  group('Doctor — JSON output contract', () {
    test('toJson diagnostics list contains each diagnostic as a map', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.runDoctor(platforms: []);
      final json = result.toJson();

      final diags = json['diagnostics'] as List<dynamic>;
      expect(diags, isNotEmpty);
      for (final d in diags) {
        final map = d as Map<String, Object?>;
        expect(map, contains('code'));
        expect(map, contains('severity'));
        expect(map, contains('message'));
      }
    });

    test('toJson error_count matches actual errors', () async {
      // No pubspec — will produce a no_pubspec error.
      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.runDoctor(platforms: []);
      final json = result.toJson();

      expect(json['error_count'], equals(result.errors.length));
    });

    test('toJson is fully JSON-encodable', () async {
      await _setupProject(tempDir, '''
schema_version: 1
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.runDoctor(platforms: []);

      expect(
        () => jsonEncode({'command': 'doctor', ...result.toJson()}),
        returnsNormally,
      );
    });

    test('doctor command json payload has command key', () async {
      await _setupProject(tempDir, '''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final orchestrator = FlavorOrchestrator(projectRoot: tempDir.path);
      final result = await orchestrator.runDoctor(platforms: []);
      final payload = <String, Object?>{'command': 'doctor', ...result.toJson()};

      expect(payload, containsPair('command', 'doctor'));
      expect(payload, contains('healthy'));
      expect(payload, contains('error_count'));
      expect(payload, contains('warning_count'));
      expect(payload, contains('info_count'));
      expect(payload, contains('diagnostics'));
    });
  });

  // ── External config path ────────────────────────────────────────────────────

  group('Doctor — external config path', () {
    test('uses external config path when provided', () async {
      await File('${tempDir.path}/pubspec.yaml').writeAsString(
        'name: test_app\nflutter:\n  uses-material-design: true\n',
      );

      // Write config to a subdirectory.
      final configDir = Directory('${tempDir.path}/ci');
      await configDir.create();
      final configFile = File('${configDir.path}/flavor_config.yaml');
      await configFile.writeAsString('''
dev:
  bundle_id: com.example.dev
  app_name: App Dev
''');

      final doctor = Doctor(
        projectRoot: tempDir.path,
        configPath: '${configDir.path}/flavor_config.yaml',
      );
      final result = await doctor.run(platforms: []);

      // Should find the config and not report no_config.
      expect(result.errors.map((d) => d.code), isNot(contains('no_config')));
    });

    test('reports no_config when external config path does not exist',
        () async {
      await File('${tempDir.path}/pubspec.yaml').writeAsString(
        'name: test_app\nflutter:\n  uses-material-design: true\n',
      );

      final doctor = Doctor(
        projectRoot: tempDir.path,
        configPath: '${tempDir.path}/nonexistent.yaml',
      );
      final result = await doctor.run(platforms: []);

      expect(result.errors.map((d) => d.code), contains('no_config'));
    });
  });
}
