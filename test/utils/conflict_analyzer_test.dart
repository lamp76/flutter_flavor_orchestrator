import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';
import 'package:test/test.dart';

/// Builds a minimal [ExecutionPlan] from a list of [PlannedOperation]s for
/// use in unit tests.
ExecutionPlan _plan(List<PlannedOperation> ops) => ExecutionPlan(
      flavorName: 'test',
      operations: ops,
      platforms: const ['android', 'ios'],
    );

void main() {
  group('ConflictAnalyzer.analyze', () {
    test('returns empty list for plan with no operations', () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(_plan([]));
      expect(conflicts, isEmpty);
    });

    test('returns empty list for plan with unique destination paths', () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'op A',
            destinationPath: 'android/app/build.gradle',
            platform: 'android',
          ),
          const PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'op B',
            destinationPath: 'ios/Runner/Info.plist',
            platform: 'ios',
          ),
          const PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'op C',
            sourcePath: 'src/config.dart',
            destinationPath: 'lib/config.dart',
            platform: 'assets',
          ),
        ]),
      );
      expect(conflicts, isEmpty);
    });

    test('detects duplicate destination paths', () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'op A',
            destinationPath: 'lib/config/app_config.dart',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'op B',
            sourcePath: 'src/app_config.dart',
            destinationPath: 'lib/config/app_config.dart',
            platform: 'assets',
          ),
        ]),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.code, equals('duplicate_destination'));
      expect(conflicts.first.severity, equals(ConflictSeverity.error));
      expect(
        conflicts.first.conflictingPaths,
        contains('lib/config/app_config.dart'),
      );
    });

    test('detects overlapping destinations (parent and child)', () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.copyDirectory,
            description: 'copy lib',
            destinationPath: 'lib',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'copy nested file',
            sourcePath: 'src/config.dart',
            destinationPath: 'lib/config/app_config.dart',
            platform: 'assets',
          ),
        ]),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.code, equals('overlapping_destinations'));
      expect(conflicts.first.severity, equals(ConflictSeverity.error));
      expect(
        conflicts.first.conflictingPaths,
        containsAll(['lib', 'lib/config/app_config.dart']),
      );
    });

    test('detects overlapping destinations (child before parent)', () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'copy nested file',
            sourcePath: 'src/config.dart',
            destinationPath: 'lib/config/app_config.dart',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.copyDirectory,
            description: 'copy lib',
            destinationPath: 'lib',
            platform: 'assets',
          ),
        ]),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.code, equals('overlapping_destinations'));
    });

    test('skip operations are excluded from conflict detection', () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(
        _plan([
          // Two skip ops with the same destination — not a real conflict
          const PlannedOperation(
            kind: OperationKind.skip,
            description: 'skip A',
            destinationPath: 'lib/config.dart',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.skip,
            description: 'skip B',
            destinationPath: 'lib/config.dart',
            platform: 'assets',
          ),
        ]),
      );
      expect(conflicts, isEmpty);
    });

    test('operations without destination paths do not cause false positives',
        () {
      const analyzer = ConflictAnalyzer();
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'op with no dest',
            platform: 'android',
            // destinationPath intentionally omitted
          ),
          const PlannedOperation(
            kind: OperationKind.writeFile,
            description: 'op with no dest 2',
            platform: 'android',
            // destinationPath intentionally omitted
          ),
        ]),
      );
      expect(conflicts, isEmpty);
    });

    test('does not emit duplicate overlap reports for the same path pair', () {
      const analyzer = ConflictAnalyzer();
      // Three operations: A overlaps with B and C, but only one report per pair
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.copyDirectory,
            description: 'copy lib',
            destinationPath: 'lib',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'copy file under lib',
            destinationPath: 'lib/a.dart',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'copy another file under lib',
            destinationPath: 'lib/b.dart',
            platform: 'assets',
          ),
        ]),
      );

      // Should have two overlap reports:
      // (lib, lib/a.dart) and (lib, lib/b.dart)
      final overlapReports =
          conflicts.where((c) => c.code == 'overlapping_destinations').toList();
      expect(overlapReports, hasLength(2));
    });

    test('ConflictReport.toJson contains required keys', () {
      const report = ConflictReport(
        code: 'duplicate_destination',
        severity: ConflictSeverity.error,
        message: 'test message',
        conflictingPaths: ['lib/config.dart'],
      );
      final json = report.toJson();

      expect(json, containsPair('code', 'duplicate_destination'));
      expect(json, containsPair('severity', 'error'));
      expect(json, containsPair('message', 'test message'));
      expect(json, contains('conflicting_paths'));
      expect(json['conflicting_paths'], isA<List<String>>());
    });

    test('ConflictReport.toString includes code and message', () {
      const report = ConflictReport(
        code: 'duplicate_destination',
        severity: ConflictSeverity.error,
        message: 'Duplicate: lib/config.dart',
        conflictingPaths: ['lib/config.dart'],
      );
      expect(report.toString(), contains('duplicate_destination'));
      expect(report.toString(), contains('Duplicate: lib/config.dart'));
    });

    test('no overlap reported for paths that share a prefix but are siblings',
        () {
      const analyzer = ConflictAnalyzer();
      // lib/config and lib/core share the 'lib' prefix in their string
      // representation, but neither is a parent of the other.
      final conflicts = analyzer.analyze(
        _plan([
          const PlannedOperation(
            kind: OperationKind.copyDirectory,
            description: 'copy lib/config',
            destinationPath: 'lib/config',
            platform: 'assets',
          ),
          const PlannedOperation(
            kind: OperationKind.copyDirectory,
            description: 'copy lib/core',
            destinationPath: 'lib/core',
            platform: 'assets',
          ),
        ]),
      );
      expect(conflicts, isEmpty);
    });
  });
}
