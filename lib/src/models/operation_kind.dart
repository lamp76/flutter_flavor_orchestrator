/// The kind of operation to be performed during flavor application.
///
/// Used by [PlannedOperation] to describe what action will be taken.
enum OperationKind {
  /// Copy a single file from source to destination.
  copyFile,

  /// Copy a directory tree recursively from source to destination.
  copyDirectory,

  /// Write modified content to a native platform file (e.g. AndroidManifest).
  writeFile,

  /// No operation — the source path does not exist or step is not applicable.
  skip,
}
