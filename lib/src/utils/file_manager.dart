import 'dart:io';
import 'package:path/path.dart' as path;
import 'logger.dart';

/// File management utility with backup and rollback capabilities.
///
/// Provides safe file operations with automatic backup creation and
/// the ability to rollback changes if needed.
final class FileManager {
  /// Creates a new [FileManager] instance.
  ///
  /// [logger] is used for logging operations and errors.
  /// [createBackups] determines whether to automatically create backups.
  FileManager({
    required this.logger,
    this.createBackups = true,
    this.dryRun = false,
  });

  /// Logger instance for output.
  final Logger logger;

  /// Whether to create backups before modifying files.
  final bool createBackups;

  /// Whether to execute operations in dry-run mode.
  ///
  /// In dry-run mode, write operations are validated but no file system
  /// mutations are performed.
  bool dryRun;

  /// Map of original file paths to their backup paths.
  final Map<String, String> _backups = {};

  /// Safely copies a file from [source] to [destination].
  ///
  /// Creates a backup of the destination file if it exists and
  /// [createBackups] is true.
  ///
  /// Throws [FileSystemException] if the operation fails.
  Future<void> copyFile(String source, String destination) async {
    logger.debug('Copying file: $source -> $destination');

    final sourceFile = File(source);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Source file does not exist',
        source,
      );
    }

    final destinationFile = File(destination);

    if (dryRun) {
      if (await destinationFile.exists()) {
        logger.debug('Dry-run: validated file copy (destination exists)');
      } else {
        logger.debug(
          'Dry-run: validated file copy (destination will be created)',
        );
      }

      return;
    }

    // Create backup if destination exists
    if (await destinationFile.exists() && createBackups) {
      await _createBackup(destination);
    }

    // Create destination directory if it doesn't exist
    final destinationDir = Directory(path.dirname(destination));
    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
      logger.debug('Created directory: ${destinationDir.path}');
    }

    // Copy the file
    await sourceFile.copy(destination);
    logger.debug('File copied successfully');
  }

  /// Safely writes content to a file at [filePath].
  ///
  /// Creates a backup of the file if it exists and [createBackups] is true.
  ///
  /// Throws [FileSystemException] if the operation fails.
  Future<void> writeFile(String filePath, String content) async {
    logger.debug('Writing file: $filePath');

    final file = File(filePath);

    if (dryRun) {
      if (await file.exists()) {
        logger.debug('Dry-run: validated file write (destination exists)');
      } else {
        logger.debug(
          'Dry-run: validated file write (destination will be created)',
        );
      }

      return;
    }

    // Create backup if file exists
    if (await file.exists() && createBackups) {
      await _createBackup(filePath);
    }

    // Create directory if it doesn't exist
    final fileDir = Directory(path.dirname(filePath));
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
      logger.debug('Created directory: ${fileDir.path}');
    }

    // Write content
    await file.writeAsString(content);
    logger.debug('File written successfully');
  }

  /// Reads the content of a file at [filePath].
  ///
  /// Throws [FileSystemException] if the file doesn't exist.
  Future<String> readFile(String filePath) async {
    logger.debug('Reading file: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException(
        'File does not exist',
        filePath,
      );
    }

    return file.readAsString();
  }

  /// Checks if a file exists at [filePath].
  Future<bool> fileExists(String filePath) async => File(filePath).exists();

  /// Checks if a directory exists at [dirPath].
  Future<bool> directoryExists(String dirPath) async =>
      Directory(dirPath).exists();

  /// Rolls back all changes made since the last checkpoint.
  ///
  /// Restores all backed-up files to their original locations.
  Future<void> rollback() async {
    if (dryRun) {
      logger.debug('Dry-run: rollback skipped');
      _backups.clear();
      return;
    }

    logger.warning('Rolling back changes...');

    for (final entry in _backups.entries) {
      final originalPath = entry.key;
      final backupPath = entry.value;

      try {
        final backupFile = File(backupPath);
        if (await backupFile.exists()) {
          await backupFile.copy(originalPath);
          await backupFile.delete();
          logger.debug('Restored: $originalPath');
        }
      } on Exception catch (e) {
        logger.error('Failed to restore file: $originalPath', e);
      }
    }

    _backups.clear();
    logger.success('Rollback completed');
  }

  /// Commits all changes and removes backup files.
  ///
  /// This should be called after successfully completing all operations.
  Future<void> commit() async {
    if (dryRun) {
      logger.debug('Dry-run: commit skipped');
      _backups.clear();
      return;
    }

    logger.debug('Committing changes...');

    for (final backupPath in _backups.values) {
      try {
        final backupFile = File(backupPath);
        if (await backupFile.exists()) {
          await backupFile.delete();
          logger.debug('Deleted backup: $backupPath');
        }
      } on Exception {
        logger.warning('Failed to delete backup: $backupPath');
      }
    }

    _backups.clear();
    logger.debug('Changes committed');
  }

  /// Creates a backup of the file at [filePath].
  Future<void> _createBackup(String filePath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '$filePath.backup.$timestamp';

    final originalFile = File(filePath);
    await originalFile.copy(backupPath);

    _backups[filePath] = backupPath;
    logger.debug('Created backup: $backupPath');
  }

  /// Ensures a directory exists at [dirPath], creating it if necessary.
  Future<void> ensureDirectory(String dirPath) async {
    final dir = Directory(dirPath);

    if (dryRun) {
      if (await dir.exists()) {
        logger.debug('Dry-run: validated directory exists: $dirPath');
      } else {
        logger.debug('Dry-run: directory will be created: $dirPath');
      }

      return;
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      logger.debug('Created directory: $dirPath');
    }
  }

  /// Gets the relative path from [from] to [to].
  String getRelativePath(String from, String to) =>
      path.relative(to, from: from);

  /// Joins path segments into a single path.
  String joinPath(List<String> segments) => path.joinAll(segments);

  /// Gets the directory name from a path.
  String dirname(String filePath) => path.dirname(filePath);

  /// Gets the base name (filename) from a path.
  String basename(String filePath) => path.basename(filePath);
}
