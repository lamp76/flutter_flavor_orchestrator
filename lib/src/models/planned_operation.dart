import 'operation_kind.dart';

/// An immutable description of a single planned operation.
///
/// Describes what the orchestrator will do (or did) for one step of a
/// flavor apply — without encoding whether execution has happened yet.
/// This is the fundamental unit used by [ExecutionPlan].
final class PlannedOperation {
  /// Creates a new [PlannedOperation].
  ///
  /// [kind] describes the type of operation.
  /// [description] is a human-readable summary of the step.
  /// [sourcePath] is the source file or directory path (if applicable).
  /// [destinationPath] is the target file or directory path (if applicable).
  /// [platform] identifies the target platform (`'android'`, `'ios'`,
  /// `'assets'`) or `null` for cross-platform operations.
  const PlannedOperation({
    required this.kind,
    required this.description,
    this.sourcePath,
    this.destinationPath,
    this.platform,
  });

  /// The type of operation.
  final OperationKind kind;

  /// Human-readable description of what this operation does.
  final String description;

  /// Source path involved in this operation, if any.
  final String? sourcePath;

  /// Destination path involved in this operation, if any.
  final String? destinationPath;

  /// Target platform for this operation (`'android'`, `'ios'`, `'assets'`),
  /// or `null` for general operations.
  final String? platform;

  /// Serialises this operation to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'description': description,
        if (sourcePath != null) 'source_path': sourcePath,
        if (destinationPath != null) 'destination_path': destinationPath,
        if (platform != null) 'platform': platform,
      };

  @override
  String toString() => 'PlannedOperation('
      'kind: ${kind.name}, '
      'description: $description'
      ')';
}
