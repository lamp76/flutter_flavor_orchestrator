import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../models/execution_plan.dart';
import '../models/operation_kind.dart';
import 'logger.dart';

/// A single file entry within a [BackupRecord].
///
/// Stores the original path, the relative path inside the backup directory,
/// and the SHA-256 checksums of the pre-apply and post-apply file contents.
final class BackupEntry {
  /// Creates a new [BackupEntry].
  const BackupEntry({
    required this.originalPath,
    required this.backupRelativePath,
    required this.preApplyChecksum,
    this.postApplyChecksum,
  });

  /// Creates a [BackupEntry] from a JSON map (as produced by [toJson]).
  factory BackupEntry.fromJson(Map<String, Object?> json) => BackupEntry(
        originalPath: json['original_path'] as String,
        backupRelativePath: json['backup_relative_path'] as String,
        preApplyChecksum: json['pre_apply_checksum'] as String,
        postApplyChecksum: json['post_apply_checksum'] as String?,
      );

  /// Absolute path to the original (project) file.
  final String originalPath;

  /// Path of the backed-up copy, relative to the backup directory.
  final String backupRelativePath;

  /// SHA-256 digest of the backed-up content (pre-apply state).
  ///
  /// Restored to [originalPath] on rollback.
  final String preApplyChecksum;

  /// SHA-256 digest of the file after a successful `apply`.
  ///
  /// Set by [BackupManager.finalizeBackup]. Used to detect manual edits
  /// that occurred after the apply but before a rollback is requested.
  /// `null` until [BackupManager.finalizeBackup] is called.
  final String? postApplyChecksum;

  /// Serialises this entry to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'original_path': originalPath,
        'backup_relative_path': backupRelativePath,
        'pre_apply_checksum': preApplyChecksum,
        if (postApplyChecksum != null)
          'post_apply_checksum': postApplyChecksum,
      };
}

/// An immutable record describing a complete persistent backup snapshot.
///
/// Each record corresponds to a single `apply` run for one flavor.
/// Stored as `<projectRoot>/.ffo/backups/<id>/metadata.json`.
final class BackupRecord {
  /// Creates a new [BackupRecord].
  const BackupRecord({
    required this.id,
    required this.flavorName,
    required this.createdAt,
    required this.backupDir,
    required this.entries,
    this.newPaths = const [],
  });

  /// Creates a [BackupRecord] from a JSON map (as produced by [toJson]).
  factory BackupRecord.fromJson(Map<String, Object?> json) {
    final entriesJson = json['entries'] as List<Object?>;
    return BackupRecord(
      id: json['id'] as String,
      flavorName: json['flavor'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      backupDir: json['backup_dir'] as String,
      entries: entriesJson
          .map((e) => BackupEntry.fromJson(e as Map<String, Object?>))
          .toList(),
      newPaths: (json['new_paths'] as List<Object?>?)
              ?.cast<String>()
              .toList() ??
          const [],
    );
  }

  /// Unique backup identifier derived from the timestamp and flavor name.
  final String id;

  /// The flavor name that was applied when this backup was created.
  final String flavorName;

  /// When this backup was created.
  final DateTime createdAt;

  /// Absolute path to the directory holding the backed-up files and metadata.
  final String backupDir;

  /// Per-file backup entries.
  final List<BackupEntry> entries;

  /// Absolute paths of files or directories that did **not** exist before the
  /// apply and were therefore created by the apply run.
  ///
  /// These paths are deleted during [BackupManager.restore] to bring the
  /// project back to its exact pre-apply state.
  final List<String> newPaths;

  /// Serialises this record to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'id': id,
        'flavor': flavorName,
        'created_at': createdAt.toIso8601String(),
        'backup_dir': backupDir,
        'entries': entries.map((e) => e.toJson()).toList(),
        'new_paths': newPaths,
      };
}

/// Manages persistent backups for flavor apply operations.
///
/// Before each non-dry-run `apply`, [createBackup] snapshots every
/// destination file referenced by the [ExecutionPlan] into
/// `<projectRoot>/.ffo/backups/<id>/`.  After a successful apply,
/// [finalizeBackup] records post-apply checksums so that manual edits
/// made *after* the apply can be detected before a rollback.
///
/// [restore] reverts a [BackupRecord] to its pre-apply state.  If any
/// post-apply checksum mismatches the current file (indicating a manual
/// edit), the restore aborts unless [force] is `true`.
final class BackupManager {
  /// Creates a new [BackupManager].
  ///
  /// [projectRoot] is the absolute path to the Flutter project root.
  /// [logger] is used for progress and error reporting.
  BackupManager({
    required this.projectRoot,
    required this.logger,
  });

  /// Absolute path to the Flutter project root.
  final String projectRoot;

  /// Logger instance for progress and error reporting.
  final Logger logger;

  String get _backupBaseDir =>
      path.join(projectRoot, '.ffo', 'backups');

  /// Backs up all destination files/directories referenced by [plan].
  ///
  /// - For destinations that already exist as **files**, the file is copied
  ///   into the backup store.
  /// - For destinations that already exist as **directories**
  ///   (`copyDirectory` operations), every file currently inside that
  ///   directory is copied into the backup store so the whole tree can be
  ///   restored.
  /// - For destinations that do **not** yet exist, the path is recorded in
  ///   [BackupRecord.newPaths] so [restore] can delete them on rollback,
  ///   returning the project to its exact pre-apply state.
  ///
  /// Returns the created [BackupRecord].
  Future<BackupRecord> createBackup(ExecutionPlan plan) async {
    final id = _generateId(plan.flavorName);
    final backupDir = path.join(_backupBaseDir, id);
    final filesDir = path.join(backupDir, 'files');
    await Directory(filesDir).create(recursive: true);

    logger.debug('Creating persistent backup: $id');

    final entries = <BackupEntry>[];
    final newPaths = <String>[];

    for (final op in plan.operations) {
      if (op.kind == OperationKind.skip) {
        continue;
      }

      final dest = op.destinationPath;
      if (dest == null) {
        continue;
      }

      final absolutePath = path.isAbsolute(dest)
          ? dest
          : path.join(projectRoot, dest);

      if (op.kind == OperationKind.copyDirectory) {
        // Directory operation: backup every existing file, or track as new.
        final destDir = Directory(absolutePath);
        if (!await destDir.exists()) {
          newPaths.add(absolutePath);
          logger.debug('  Tracked new directory: $dest');
        } else {
          await for (final entity in destDir.list(recursive: true)) {
            if (entity is! File) {
              continue;
            }
            final relFromRoot =
                path.relative(entity.path, from: projectRoot);
            final backupFilePath = path.join(filesDir, relFromRoot);
            await Directory(path.dirname(backupFilePath))
                .create(recursive: true);
            await entity.copy(backupFilePath);

            final content = await File(backupFilePath).readAsBytes();
            final checksum = sha256.convert(content).toString();

            entries.add(
              BackupEntry(
                originalPath: entity.path,
                backupRelativePath: relFromRoot,
                preApplyChecksum: checksum,
              ),
            );
          }
          logger.debug('  Backed up directory: $dest');
        }
      } else {
        // File operation (writeFile or copyFile).
        final originalFile = File(absolutePath);
        if (!await originalFile.exists()) {
          newPaths.add(absolutePath);
          logger.debug('  Tracked new file: $dest');
          continue;
        }

        // Mirror the project directory structure inside `files/`
        final relFromRoot = path.isAbsolute(dest)
            ? path.relative(dest, from: projectRoot)
            : dest;
        final backupFilePath = path.join(filesDir, relFromRoot);
        await Directory(path.dirname(backupFilePath)).create(recursive: true);
        await originalFile.copy(backupFilePath);

        final content = await File(backupFilePath).readAsBytes();
        final checksum = sha256.convert(content).toString();

        entries.add(
          BackupEntry(
            originalPath: absolutePath,
            backupRelativePath: relFromRoot,
            preApplyChecksum: checksum,
          ),
        );
        logger.debug('  Backed up: $dest');
      }
    }

    final record = BackupRecord(
      id: id,
      flavorName: plan.flavorName,
      createdAt: DateTime.now(),
      backupDir: backupDir,
      entries: entries,
      newPaths: newPaths,
    );

    await _writeMetadata(record);
    logger.info(
      'Backup created: $id '
      '(${entries.length} file(s) snapshotted, '
      '${newPaths.length} new path(s) tracked)',
    );
    return record;
  }

  /// Updates [record] with post-apply checksums for all backed-up files.
  ///
  /// Call this after a successful `apply` so that [restore] can detect
  /// manual edits that occurred between the apply and a later rollback.
  ///
  /// Returns the updated [BackupRecord].
  Future<BackupRecord> finalizeBackup(BackupRecord record) async {
    final updatedEntries = <BackupEntry>[];

    for (final entry in record.entries) {
      final currentFile = File(entry.originalPath);
      String? postApplyChecksum;

      if (await currentFile.exists()) {
        final content = await currentFile.readAsBytes();
        postApplyChecksum = sha256.convert(content).toString();
      }

      updatedEntries.add(
        BackupEntry(
          originalPath: entry.originalPath,
          backupRelativePath: entry.backupRelativePath,
          preApplyChecksum: entry.preApplyChecksum,
          postApplyChecksum: postApplyChecksum,
        ),
      );
    }

    final updated = BackupRecord(
      id: record.id,
      flavorName: record.flavorName,
      createdAt: record.createdAt,
      backupDir: record.backupDir,
      entries: updatedEntries,
      newPaths: record.newPaths,
    );

    await _writeMetadata(updated);
    logger.debug('Backup finalised: ${record.id}');
    return updated;
  }

  /// Returns all available backups sorted newest-first.
  ///
  /// Silently skips backup directories whose `metadata.json` is missing or
  /// malformed.
  Future<List<BackupRecord>> listBackups() async {
    final baseDir = Directory(_backupBaseDir);
    if (!await baseDir.exists()) {
      return [];
    }

    final records = <BackupRecord>[];

    await for (final entity in baseDir.list()) {
      if (entity is! Directory) {
        continue;
      }
      final metadataFile =
          File(path.join(entity.path, 'metadata.json'));
      if (!await metadataFile.exists()) {
        continue;
      }

      try {
        final decoded =
            jsonDecode(await metadataFile.readAsString()) as Object?;
        if (decoded is Map<String, Object?>) {
          records.add(BackupRecord.fromJson(decoded));
        }
      } on Object catch (e) {
        logger.warning(
          'Skipping corrupt backup at ${entity.path}: $e',
        );
      }
    }

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// Returns the most recent [BackupRecord], or `null` if no backups exist.
  Future<BackupRecord?> latestBackup() async {
    final all = await listBackups();
    return all.isEmpty ? null : all.first;
  }

  /// Restores all files in [record] to their pre-apply state.
  ///
  /// - Files that existed before the apply are restored from the backup store.
  /// - Files and directories that were **created** by the apply (recorded in
  ///   [BackupRecord.newPaths]) are deleted.
  ///
  /// If post-apply checksums are recorded and any current file differs from
  /// the expected post-apply state (indicating a manual edit), the restore
  /// aborts and returns `false` unless [force] is `true`.
  ///
  /// Returns `true` on success, `false` on unresolved conflicts.
  Future<bool> restore(
    BackupRecord record, {
    bool force = false,
  }) async {
    logger.info(
      'Restoring backup: ${record.id} '
      '(flavor: ${record.flavorName})',
    );

    // Detect post-apply manual edits
    final conflicts = <String>[];

    for (final entry in record.entries) {
      final postApply = entry.postApplyChecksum;
      if (postApply == null) {
        continue;
      }

      final currentFile = File(entry.originalPath);
      if (!await currentFile.exists()) {
        continue;
      }

      final content = await currentFile.readAsBytes();
      final currentChecksum = sha256.convert(content).toString();

      if (currentChecksum != postApply) {
        conflicts.add(entry.originalPath);
      }
    }

    if (conflicts.isNotEmpty && !force) {
      logger.error(
        'Rollback conflict: ${conflicts.length} file(s) were manually '
        'modified after the last apply. '
        'Use --force to override.',
      );
      for (final conflict in conflicts) {
        logger.info('  modified: $conflict');
      }
      return false;
    }

    if (conflicts.isNotEmpty) {
      logger.warning(
        'Overriding ${conflicts.length} manually-modified '
        'file(s) (--force)',
      );
    }

    final filesDir = path.join(record.backupDir, 'files');

    // Restore backed-up files to their pre-apply content.
    for (final entry in record.entries) {
      final backupFile =
          File(path.join(filesDir, entry.backupRelativePath));

      if (!await backupFile.exists()) {
        logger.warning(
          'Backup file missing, skipping: ${entry.originalPath}',
        );
        continue;
      }

      await Directory(path.dirname(entry.originalPath))
          .create(recursive: true);
      await backupFile.copy(entry.originalPath);
      logger.debug('Restored: ${entry.originalPath}');
    }

    // Remove files and directories that were created by the apply and did
    // not exist before it.
    for (final newPath in record.newPaths) {
      final file = File(newPath);
      if (await file.exists()) {
        await file.delete();
        logger.debug('Removed new file: $newPath');
        continue;
      }
      final dir = Directory(newPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        logger.debug('Removed new directory: $newPath');
      }
    }

    logger.success(
      'Rollback complete: '
      '${record.entries.length} file(s) restored, '
      '${record.newPaths.length} new path(s) removed',
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generates a timestamped, flavor-scoped backup identifier.
  String _generateId(String flavorName) {
    final ts = DateTime.now();
    final year = ts.year.toString().padLeft(4, '0');
    final month = ts.month.toString().padLeft(2, '0');
    final day = ts.day.toString().padLeft(2, '0');
    final hour = ts.hour.toString().padLeft(2, '0');
    final minute = ts.minute.toString().padLeft(2, '0');
    final second = ts.second.toString().padLeft(2, '0');
    final ms = ts.millisecond.toString().padLeft(3, '0');
    return '$year$month${day}_$hour$minute$second${ms}_$flavorName';
  }

  /// Writes [record] as `metadata.json` inside its backup directory.
  Future<void> _writeMetadata(BackupRecord record) async {
    final metadataFile =
        File(path.join(record.backupDir, 'metadata.json'));
    await metadataFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
  }
}
