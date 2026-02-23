import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/execution_plan.dart';
import '../models/flavor_config.dart';
import '../models/operation_kind.dart';
import '../models/planned_operation.dart';
import '../utils/file_manager.dart';
import '../utils/logger.dart';

/// Processor for handling flavor-specific file and folder copying.
///
/// This processor handles the recursive copying of files and folders from
/// source paths to destination paths as specified in the flavor configuration.
/// All operations are logged and support automatic backup and rollback through
/// the [FileManager].
final class AssetProcessor {
  /// Creates a new [AssetProcessor] instance.
  ///
  /// [projectRoot] is the absolute path to the Flutter project root.
  /// [fileManager] handles safe file operations with backup/rollback support.
  /// [logger] is used for logging operations and errors.
  AssetProcessor({
    required this.projectRoot,
    required this.fileManager,
    required this.logger,
  });

  /// The Flutter project root directory.
  final String projectRoot;

  /// File manager for safe file operations.
  final FileManager fileManager;

  /// Logger instance for output.
  final Logger logger;

  /// Builds an ordered list of [PlannedOperation]s for the file mappings
  /// in [config] without executing any file system operations.
  ///
  /// This is the shared planning phase used by both `apply` (which then
  /// executes the plan) and the future `plan` command (which only previews).
  ///
  /// Returns a list of [PlannedOperation]s describing what would be done.
  Future<List<PlannedOperation>> planFileMappings(
    FlavorConfig config,
  ) async {
    final operations = <PlannedOperation>[];

    for (final entry in config.fileMappings.entries) {
      final destination = entry.key;
      final source = entry.value;

      final sourcePath = path.join(projectRoot, source);

      final sourceEntity = _getFileSystemEntity(sourcePath);

      if (sourceEntity == null) {
        operations.add(
          PlannedOperation(
            kind: OperationKind.skip,
            description: 'Skip missing source: $source',
            sourcePath: source,
            destinationPath: destination,
            platform: ExecutionPlan.platformAssets,
          ),
        );
        continue;
      }

      if (sourceEntity is File) {
        operations.add(
          PlannedOperation(
            kind: OperationKind.copyFile,
            description: 'Copy file: $source → $destination',
            sourcePath: source,
            destinationPath: destination,
            platform: ExecutionPlan.platformAssets,
          ),
        );
      } else if (sourceEntity is Directory) {
        operations.add(
          PlannedOperation(
            kind: OperationKind.copyDirectory,
            description: 'Copy directory: $source/ → $destination/',
            sourcePath: source,
            destinationPath: destination,
            platform: ExecutionPlan.platformAssets,
          ),
        );
      }
    }

    return operations;
  }

  /// Processes file mappings for the given flavor configuration.
  ///
  /// Iterates through all file mappings defined in [config.fileMappings] and
  /// copies files or directories from source to destination paths.
  ///
  /// Returns the number of files successfully copied.
  ///
  /// Throws [FileSystemException] if any operation fails.
  Future<int> processFileMappings(FlavorConfig config) async {
    logger.section('Processing file mappings for flavor: ${config.name}');
    if (config.fileMappings.isEmpty) {
      logger.debug('No file mappings defined for flavor: ${config.name}');
      return 0;
    }

    logger.info(
      '📁 Processing ${config.fileMappings.length} file mapping(s) '
      'for flavor: ${config.name}',
    );

    var filesProcessed = 0;

    for (final entry in config.fileMappings.entries) {
      final destination = entry.key;
      final source = entry.value;

      final sourcePath = path.join(projectRoot, source);
      final destinationPath = path.join(projectRoot, destination);

      logger.debug('Processing mapping: $source -> $destination');

      final sourceEntity = _getFileSystemEntity(sourcePath);

      if (sourceEntity == null) {
        logger.warning(
          '⚠️  Source path does not exist: $source\n'
          '   Skipping this mapping.',
        );
        continue;
      }

      if (sourceEntity is File) {
        await _copyFile(sourcePath, destinationPath, source, destination);
        filesProcessed++;
      } else if (sourceEntity is Directory) {
        final count = await _copyDirectory(
          sourcePath,
          destinationPath,
          source,
          destination,
          config.replaceDestinationDirectories,
        );
        filesProcessed += count;
      }
    }

    logger.success(
      '✅ Completed file mappings: $filesProcessed file(s) processed',
    );

    return filesProcessed;
  }

  /// Gets the file system entity at the given path.
  ///
  /// Returns [File] if path is a file, [Directory] if path is a directory,
  /// or null if the path doesn't exist.
  FileSystemEntity? _getFileSystemEntity(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      return file;
    }

    final directory = Directory(filePath);
    if (directory.existsSync()) {
      return directory;
    }

    return null;
  }

  /// Copies a single file from source to destination.
  ///
  /// Logs the operation with both relative and absolute paths for clarity.
  ///
  /// Throws [FileSystemException] if the copy operation fails.
  Future<void> _copyFile(
    String sourcePath,
    String destinationPath,
    String relativeSource,
    String relativeDestination,
  ) async {
    logger
      ..info('📄 Copying file:')
      ..info('   From: $relativeSource')
      ..info('   To:   $relativeDestination');

    await fileManager.copyFile(sourcePath, destinationPath);

    logger.success('   ✓ File copied successfully');
  }

  /// Recursively copies a directory from source to destination.
  ///
  /// Traverses the source directory tree and copies all files and
  /// subdirectories to the destination, maintaining the directory structure.
  ///
  /// If [replaceDestination] is true and the destination directory exists,
  /// it will be safely replaced using a temporary rename strategy:
  /// 1. Rename existing directory with timestamp suffix
  /// 2. Copy new directory tree
  /// 3. On success, delete the renamed directory
  /// 4. On failure, restore the renamed directory
  ///
  /// Returns the total number of files copied.
  ///
  /// Throws [FileSystemException] if any operation fails.
  Future<int> _copyDirectory(
    String sourcePath,
    String destinationPath,
    String relativeSource,
    String relativeDestination,
    bool replaceDestination,
  ) async {
    logger
      ..info('📂 Copying directory recursively:')
      ..info('   From: $relativeSource/')
      ..info('   To:   $relativeDestination/');

    final sourceDir = Directory(sourcePath);
    var filesCopied = 0;

    final destDir = Directory(destinationPath);
    final destExists = await destDir.exists();

    if (fileManager.dryRun) {
      if (destExists) {
        logger.debug(
          '   Dry-run: destination directory exists: $relativeDestination',
        );
      } else {
        logger.debug(
          '   Dry-run: destination directory will be created: '
          '$relativeDestination',
        );
      }

      await for (final entity in sourceDir.list(recursive: true)) {
        if (entity is File) {
          filesCopied++;
        }
      }

      logger.success(
        '   ✓ Dry-run validated directory mapping: $filesCopied file(s)',
      );

      return filesCopied;
    }

    String? backupPath;

    // If replace mode and destination exists, create backup
    if (replaceDestination && destExists) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      backupPath = '${destinationPath}_backup_$timestamp';

      logger
        ..info(
          '   🔄 Replacing existing directory: $relativeDestination',
        )
        ..debug('   Creating temporary backup: $backupPath');

      try {
        // Rename existing directory to backup
        await destDir.rename(backupPath);
        logger.debug('   ✓ Existing directory temporarily renamed');
      } catch (e) {
        logger.error(
          'Failed to create backup of existing directory',
          e,
        );
        rethrow;
      }
    }

    try {
      // Create destination directory if it doesn't exist
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
        logger.debug(
          '   Created destination directory: $relativeDestination',
        );
      }

      // List all entities in the source directory
      await for (final entity in sourceDir.list(recursive: true)) {
        if (entity is File) {
          // Calculate relative path from source directory
          final relativePath = path.relative(entity.path, from: sourcePath);
          final destFilePath = path.join(destinationPath, relativePath);

          // Calculate paths relative to project root for logging
          final relativeSourceFile = path.join(relativeSource, relativePath);
          final relativeDestFile = path.join(relativeDestination, relativePath);

          logger.debug(
            '   • Copying: $relativeSourceFile -> $relativeDestFile',
          );

          await fileManager.copyFile(entity.path, destFilePath);
          filesCopied++;
        } else if (entity is Directory) {
          // Ensure subdirectories exist in destination
          final relativePath = path.relative(entity.path, from: sourcePath);
          final destDirPath = path.join(destinationPath, relativePath);
          final destSubDir = Directory(destDirPath);

          if (!await destSubDir.exists()) {
            await destSubDir.create(recursive: true);
            final relativeDestSubDir =
                path.join(relativeDestination, relativePath);
            logger.debug('   Created subdirectory: $relativeDestSubDir');
          }
        }
      }

      // If we created a backup, remove it now that copy succeeded
      if (backupPath != null) {
        final backupDir = Directory(backupPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
          logger.debug('   ✓ Removed temporary backup directory');
        }
      }

      logger.success('   ✓ Directory copied: $filesCopied file(s)');

      return filesCopied;
    } catch (e) {
      // On error, restore the backup if it exists
      if (backupPath != null) {
        final backupDir = Directory(backupPath);
        if (await backupDir.exists()) {
          logger.warning('   ⚠️  Copy failed, restoring original directory...');

          // Remove partial copy if it exists
          if (await destDir.exists()) {
            await destDir.delete(recursive: true);
          }

          // Restore backup
          await backupDir.rename(destinationPath);
          logger.info('   ✓ Original directory restored');
        }
      }

      rethrow;
    }
  }
}
