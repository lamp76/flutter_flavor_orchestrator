import '../models/execution_plan.dart';
import '../models/operation_kind.dart';

/// The severity of a detected conflict.
enum ConflictSeverity {
  /// The conflict will cause data loss or undefined behavior if not resolved.
  error,

  /// The conflict is suspicious but may be intentional.
  warning,
}

/// A conflict detected during pre-apply conflict analysis.
///
/// Each report carries a stable [code] for programmatic handling, a
/// human-readable [message], and the [conflictingPaths] involved.
final class ConflictReport {
  /// Creates a new [ConflictReport].
  const ConflictReport({
    required this.code,
    required this.severity,
    required this.message,
    required this.conflictingPaths,
  });

  /// Stable, machine-readable conflict code.
  ///
  /// Current codes:
  /// - `duplicate_destination` — two or more operations target the same path.
  /// - `overlapping_destinations` — one destination is a parent directory of
  ///   another, creating potential write order ambiguity.
  final String code;

  /// Severity of this conflict.
  final ConflictSeverity severity;

  /// Human-readable description of the conflict.
  final String message;

  /// Destination paths involved in this conflict.
  final List<String> conflictingPaths;

  /// Serialises this report to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'code': code,
        'severity': severity.name,
        'message': message,
        'conflicting_paths': conflictingPaths,
      };

  @override
  String toString() => '[${severity.name}] $code: $message';
}

/// Analyzes an [ExecutionPlan] for conflicts before any file mutations occur.
///
/// Two conflict classes are detected:
///
/// 1. **Duplicate destinations** (`duplicate_destination`) — two or more
///    active (non-skip) operations write to the same destination path.
///    This always overwrites silently and is classified as [ConflictSeverity.error].
///
/// 2. **Overlapping destinations** (`overlapping_destinations`) — one
///    destination path is a parent directory of another destination path,
///    creating ambiguity about the final state of the parent directory.
///    Classified as [ConflictSeverity.error].
///
/// Usage:
/// ```dart
/// final analyzer = ConflictAnalyzer();
/// final conflicts = analyzer.analyze(plan);
/// if (conflicts.isNotEmpty && !force) {
///   // abort apply
/// }
/// ```
final class ConflictAnalyzer {
  /// Creates a new [ConflictAnalyzer].
  const ConflictAnalyzer();

  /// Analyzes [plan] for conflicts.
  ///
  /// Returns a (possibly empty) list of [ConflictReport]s describing every
  /// conflict found.  An empty list means the plan is conflict-free.
  List<ConflictReport> analyze(ExecutionPlan plan) {
    final conflicts = <ConflictReport>[];
    conflicts.addAll(_detectDuplicateDestinations(plan));
    conflicts.addAll(_detectOverlappingDestinations(plan));
    return conflicts;
  }

  /// Detects operations that share the same destination path.
  List<ConflictReport> _detectDuplicateDestinations(ExecutionPlan plan) {
    final seen = <String>{};
    final duplicates = <String>{};

    for (final op in plan.operations) {
      if (op.kind == OperationKind.skip) continue;
      final dst = op.destinationPath;
      if (dst == null) continue;

      if (!seen.add(dst)) {
        duplicates.add(dst);
      }
    }

    return duplicates
        .map(
          (path) => ConflictReport(
            code: 'duplicate_destination',
            severity: ConflictSeverity.error,
            message:
                'Multiple operations target the same destination: "$path"',
            conflictingPaths: [path],
          ),
        )
        .toList();
  }

  /// Detects pairs of destination paths where one is a parent of the other.
  List<ConflictReport> _detectOverlappingDestinations(ExecutionPlan plan) {
    final paths = plan.operations
        .where(
          (op) =>
              op.kind != OperationKind.skip && op.destinationPath != null,
        )
        .map((op) => op.destinationPath!)
        .toList();

    final conflicts = <ConflictReport>[];

    for (var i = 0; i < paths.length; i++) {
      for (var j = i + 1; j < paths.length; j++) {
        final a = paths[i];
        final b = paths[j];

        if (_isParentPath(a, b) || _isParentPath(b, a)) {
          // Avoid emitting a duplicate report for the same pair.
          final alreadyReported = conflicts.any(
            (c) =>
                c.conflictingPaths.contains(a) &&
                c.conflictingPaths.contains(b),
          );
          if (!alreadyReported) {
            conflicts.add(
              ConflictReport(
                code: 'overlapping_destinations',
                severity: ConflictSeverity.error,
                message:
                    'Destination paths overlap: "$a" and "$b"',
                conflictingPaths: [a, b],
              ),
            );
          }
        }
      }
    }

    return conflicts;
  }

  /// Returns `true` when [parent] is a strict parent directory of [child].
  ///
  /// Uses a trailing-slash normalisation so that `lib` does not match itself,
  /// but does match `lib/config`.
  bool _isParentPath(String parent, String child) {
    final normalised =
        parent.endsWith('/') ? parent : '$parent/';
    return child.startsWith(normalised);
  }
}
