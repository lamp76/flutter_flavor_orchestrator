import 'operation_kind.dart';
import 'planned_operation.dart';

/// An immutable, ordered collection of operations that the orchestrator will
/// (or would) perform to apply a flavor.
///
/// [ExecutionPlan] is the foundation for both the `apply` command
/// (which executes the plan) and the future `plan` command (which previews
/// it without mutating files).
///
/// Serialise to JSON via [toJson] for machine-readable output.
final class ExecutionPlan {
  /// Creates a new [ExecutionPlan].
  ///
  /// [flavorName] is the name of the flavor being applied.
  /// [operations] is the ordered list of planned operations.
  /// [platforms] are the target platforms included in this plan.
  const ExecutionPlan({
    required this.flavorName,
    required this.operations,
    required this.platforms,
  });

  /// Platform identifier for Android operations.
  static const String platformAndroid = 'android';

  /// Platform identifier for iOS operations.
  static const String platformIos = 'ios';

  /// Platform identifier for cross-platform asset / file-mapping operations.
  static const String platformAssets = 'assets';

  /// The flavor name this plan was built for.
  final String flavorName;

  /// Ordered list of operations to be (or already) performed.
  final List<PlannedOperation> operations;

  /// Target platforms included in this plan (e.g. `['android', 'ios']`).
  final List<String> platforms;

  /// Total number of operations in this plan.
  int get totalOperations => operations.length;

  /// Number of operations that were skipped (source not found or N/A).
  int get skippedOperations =>
      operations.where((op) => op.kind == OperationKind.skip).length;

  /// Number of operations that will mutate or create files.
  int get activeOperations => totalOperations - skippedOperations;

  /// Returns operations scoped to a specific [platform].
  List<PlannedOperation> forPlatform(String platform) =>
      operations.where((op) => op.platform == platform).toList();

  /// Serialises this plan to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'flavor': flavorName,
        'platforms': platforms,
        'total_operations': totalOperations,
        'active_operations': activeOperations,
        'skipped_operations': skippedOperations,
        'operations': operations.map((op) => op.toJson()).toList(),
      };

  @override
  String toString() => 'ExecutionPlan('
      'flavor: $flavorName, '
      'platforms: ${platforms.join(', ')}, '
      'total: $totalOperations'
      ')';
}
