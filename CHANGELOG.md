# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2026-03-08

### Added
- **`schema_version` support** — Add `schema_version: 1` at the top of your
  `flavor_config.yaml` to declare the config schema.  The parser now
  recognises this reserved key and skips it when enumerating flavors, so
  no type errors occur even on existing configs.
- **`validate --strict`** — New strict validation mode that fails when:
  - `schema_version` is missing from the config document.
  - Unknown keys are present in a flavor block (e.g. `flavors.dev.typo_key`).
  - Deprecated keys are used in a flavor block.
  - Unknown keys are present in a `provisioning` sub-block
    (e.g. `flavors.dev.provisioning.bad_key`).
- **Actionable key-path error messages** — Every schema error/warning includes
  the full dot-separated key path (e.g. `flavors.dev.provisioning.bad_key`)
  so users can locate the issue immediately.
- **Schema warnings in non-strict mode** — Without `--strict`, schema issues
  are reported as warnings (not errors) so existing configs remain
  backward-compatible.  Each flavor result in `validate --output json` now
  includes a `warnings` list alongside `errors`.
- **`validate --output json` enhancements** — The JSON payload now includes
  two new stable top-level keys: `schema_version` (integer or `null`) and
  `strict` (boolean).  The per-flavor entries now also include a `warnings`
  key (list of schema warning strings).
- **`FlavorOrchestrator.getSchemaVersion()`** — Returns the `schema_version`
  from the config document without any validation side-effects.
- **`FlavorOrchestrator.validateConfigurationsDetailed({bool strict})`** —
  `strict` parameter added (defaults to `false` for full backward
  compatibility).  Each returned entry now includes a `warnings` key.
- **`FlavorOrchestrator.validateConfigurations({bool strict})`** — `strict`
  parameter added (defaults to `false`).  Schema warnings are always logged
  in text mode; schema errors in strict mode also trigger a non-zero exit.
- **`ConfigParser.extractSchemaVersion(Map)`** — Extracts the `schema_version`
  integer from a raw YAML map.
- **`ConfigParser.parseSchemaVersion(projectRoot, {configPath})`** — Async
  convenience wrapper that loads the config file and extracts the schema
  version.
- **`ConfigParser.validateSchema(projectRoot, {configPath, strict})`** —
  Runs the full schema validation pass and returns a `SchemaValidationResult`.
- **`SchemaValidationResult`** — New model exported as public API with fields:
  `schemaVersion`, `globalErrors`, `globalWarnings`, `flavorErrors`,
  `flavorWarnings`.  Helper methods: `errorsForFlavor`, `warningsForFlavor`,
  `isValid`, `hasWarnings`.
- **`SchemaValidator`** — New public class with a single static `validate`
  method.  Exposes `knownFlavorKeys`, `knownProvisioningKeys`, and
  `deprecatedFlavorKeys` constants.
- **`SchemaMigration` interface** — Abstract interface for future schema
  migration steps (`fromVersion`, `toVersion`, `migrate`).
- **`SchemaMigrations` registry** — Holds all registered migrations; provides
  `applyMigrations(raw, fromVersion:)` helper.  A no-op v1→v1 migration is
  registered as a scaffold.

### Changed
- **`validate` command** — Gains a `--strict` flag; JSON output now includes
  `schema_version` and `strict` keys and per-flavor `warnings`.
- **`_printVersion()`** — Bumped to `v0.8.0`.
- **`example/flavor_config.yaml`** — Updated to include `schema_version: 1`.
- **`pubspec.yaml`** — Version bumped to `0.8.0`.



### Added
- **`--output json` for `apply`** — Emits a machine-readable JSON object with
  stable top-level keys: `command`, `success`, `flavor`, `platforms`, `dry_run`,
  `backup_id` (omitted in dry-run), `conflicts` (omitted when none), and `error`
  (only on failure).
- **`--output json` for `list`** — Emits a machine-readable JSON object with
  stable top-level keys: `command`, `count`, `flavors` (each entry includes
  `name`, `file_mappings_count`, `replace_destination_directories`).
- **`--output json` for `info`** — Emits a JSON object with keys `command` and
  `flavor` (a fully-serialised `FlavorConfig` including all fields).
- **`--output json` for `validate`** — Emits a JSON object with keys `command`,
  `valid`, and `flavors` (per-flavor `name`, `valid`, `errors` list).  All
  flavors are evaluated — an invalid flavor no longer aborts the rest.
- **`--output json` for `rollback`** — Emits a JSON object with keys `command`,
  `success`, `backup_id`, `flavor`, `files_restored`, `new_paths_removed`.  An
  error case emits `command`, `success: false`, and `error`.
- **`plan --output json`** — Behaviour unchanged from v0.4.0; now consistently
  documented alongside the other commands.
- **`OutputFormat` enum** (`text` | `json`) — exported as public API.
- **`OutputFormatter` typedef** — `void Function(Map<String, Object?> result)`;
  exported as public API.
- **`textOutputFormatter`** — no-op formatter (human-readable output is
  produced by the Logger); exported as public API.
- **`jsonOutputFormatter`** — writes compact JSON to `stdout`; exported as
  public API.
- **`formatterFor(OutputFormat)`** — returns the appropriate formatter;
  exported as public API.
- **`parseOutputFormat(String?)`** — parses a CLI `--output` flag value into
  an `OutputFormat`; exported as public API.
- **`Logger.silent`** — new constructor parameter (`bool`, default `false`).
  When `true` all Logger methods become no-ops, keeping `stdout` clean for JSON
  output mode.
- **`FlavorOrchestrator.silent`** — new constructor parameter that creates a
  silent Logger, used automatically by CLI handlers when `--output json` is
  passed.
- **`FlavorOrchestrator.getFlavorInfo(String flavorName)`** — returns the
  `FlavorConfig` for [flavorName] without logging; used by the `info --output
  json` handler.
- **`FlavorOrchestrator.validateConfigurationsDetailed()`** — returns a
  `List<Map<String, Object?>>` with per-flavor validation results; used by the
  `validate --output json` handler.
- **`FlavorOrchestrator.applyFlavorDetailed()`** — returns a
  `Map<String, Object?>` with the full apply result including `success`,
  `flavor`, `platforms`, `dry_run`, `backup_id` (when applicable), `conflicts`
  (when applicable), and `error` (on failure); used by the `apply --output json`
  handler.
- **`FlavorConfig.toJson()`** — serialises a `FlavorConfig` to a
  JSON-compatible map with stable top-level keys (`name`, `bundle_id`,
  `app_name`, `file_mappings`, `file_mappings_count`,
  `replace_destination_directories`, plus optional fields when present).
- **`ProvisioningConfig.toJson()`** — serialises provisioning config to a
  JSON-compatible map; used by `FlavorConfig.toJson()`.
- **`ConfigParser.parseConfigUnchecked()`** — parses all flavors from YAML
  without running per-flavor validation; used by
  `validateConfigurationsDetailed()` so every flavor is evaluated rather than
  stopping at the first invalid one.
- **Tests** — `test/utils/output_formatter_test.dart` covers:
  - `OutputFormat` enum values
  - `parseOutputFormat` — text, json, null, unknown
  - `formatterFor` — correct function returned per format
  - `textOutputFormatter` — no-op, no throw
  - JSON stable key contracts for `list`, `info`, `validate`, and `rollback`
- **Tests** — `test/orchestrator_json_output_test.dart` covers:
  - `FlavorConfig.toJson()` — stable keys, file_mappings_count, provisioning,
    JSON-encodability
  - `ProvisioningConfig.toJson()` — android, ios, empty
  - `Logger.silent` — construction, all methods no-op
  - `FlavorOrchestrator.getFlavorInfo()` — success, unknown flavor, toJson
  - `FlavorOrchestrator.validateConfigurationsDetailed()` — count, valid
    flavor, invalid flavor, JSON-encodability
  - `FlavorOrchestrator.silent` mode — construction, listFlavors,
    getFlavorInfo, validateConfigurationsDetailed
  - JSON stable key contracts integration tests for all four commands
- **Tests** — `test/orchestrator_json_output_test.dart` extended with:
  - `FlavorOrchestrator.applyFlavorDetailed()` — stable keys, no backup_id in
    dry-run, failure returns error key, result is JSON-encodable, platforms
    field reflected correctly
  - JSON stable key contracts for `apply` — dry-run payload, conflict result

### Changed
- **CLI `apply` command** — Added `--output` (`text`|`json`, default `text`).
  When `--output json`, uses the new `applyFlavorDetailed()` and emits a stable
  JSON object.  Also propagates `silent: true` to suppress logger output.
- **CLI `list` command** — Added `--output` (`text`|`json`, default `text`).
- **CLI `info` command** — Added `--output` (`text`|`json`, default `text`).
- **CLI `validate` command** — Added `--output` (`text`|`json`, default `text`).
- **CLI `rollback` command** — Added `--output` (`text`|`json`, default `text`).
- **CLI help/usage examples** — Added `--output json` examples for `apply`,
  `list`, `info`, `validate`, and `rollback` commands.
- **`FlavorOrchestrator.applyFlavor()`** — Internally now delegates to
  `applyFlavorDetailed()` for a single implementation path; return type and
  behaviour are unchanged.
- **Version** bumped to `0.7.0`.

## [0.6.0] - 2026-03-03

### Added
- **Conflict detection before non-dry-run `apply`** — Before touching any files
  the orchestrator now runs `ConflictAnalyzer.analyze()` on the execution plan
  and fails fast if any conflict is found.  Two conflict classes are detected:
  - **`duplicate_destination`** — two or more active (non-skip) operations
    target the same destination path.  Example: a `file_mappings` entry whose
    key matches a path already written by the Android or iOS processor (e.g.
    `android/app/src/main/AndroidManifest.xml`).
  - **`overlapping_destinations`** — one destination path is a parent directory
    of another (e.g. `lib/` and `lib/config/app_config.dart` are both targets).
  Conflicts cause `applyFlavor()` to return `false` immediately, before any
  backup is created or any file is modified.
- **`apply --force`** CLI flag — Overrides conflict guardrails.  When `--force`
  is passed, detected conflicts are logged as warnings and the apply proceeds
  normally.  Exit code is `0` on overall success.
- **`FlavorOrchestrator.applyFlavor({bool force = false})`** — New optional
  `force` parameter mirrors the CLI flag for programmatic use.
- **`ConflictAnalyzer`** (`lib/src/utils/conflict_analyzer.dart`) — New public
  utility class that analyses an `ExecutionPlan` for duplicate and overlapping
  destination paths.  Can be used independently:
  ```dart
  final conflicts = const ConflictAnalyzer().analyze(plan);
  ```
- **`ConflictReport`** — Immutable conflict descriptor with stable fields
  `code`, `severity`, `message`, `conflictingPaths`, and `toJson()`.
- **`ConflictSeverity`** — Enum with values `error` and `warning`.
- **Exported as public API** — `ConflictAnalyzer`, `ConflictReport`, and
  `ConflictSeverity` are now part of the library's public API.
- **Tests** — `test/utils/conflict_analyzer_test.dart` covers:
  - Empty plan — no conflicts
  - Plan with unique destinations — no conflicts
  - Duplicate destination detection (same path written twice)
  - Overlapping destination detection (parent dir vs. nested path)
  - Child-before-parent ordering produces the same result
  - Skip operations excluded from conflict detection
  - Operations without destination paths do not produce false positives
  - No duplicate overlap reports for the same path pair
  - Sibling directories with a shared string prefix do not trigger overlaps
  - `ConflictReport.toJson()` contains required keys
  - `ConflictReport.toString()` contains code and message
- **Integration tests** — `test/orchestrator_conflict_test.dart` covers:
  - `applyFlavor` succeeds with a conflict-free plan
  - `applyFlavor` returns `false` for a duplicate-destination plan (no force)
  - `applyFlavor` succeeds with `force: true` for a duplicate-destination plan
  - No file mutations occur when `applyFlavor` aborts due to a conflict
  - `applyFlavor` succeeds with non-conflicting `file_mappings`
  - `applyFlavor` fails for overlapping `file_mappings` destinations
  - `planFlavor` returns the plan regardless of conflicts (read-only)

### Changed
- **`FlavorOrchestrator.applyFlavor()`** — Runs `ConflictAnalyzer` immediately
  after building the execution plan, before creating a backup or mutating any
  files.
- **CLI `apply` command** — Added `--force` flag.
- **CLI help / usage examples** — Added `--force` example to the `apply`
  section.
- **Version** bumped to `0.6.0`.

## [0.5.0] - 2026-02-28

### Fixed
- **`build.gradle.kts` not backed up or restored** — The execution plan
  previously hardcoded `android/app/build.gradle` as the Gradle destination,
  so projects using Kotlin DSL (`build.gradle.kts`) were not included in the
  backup and their Gradle file remained modified after a rollback.
  `_buildAndroidOperations` is now async and checks for `build.gradle.kts`
  first, mirroring the detection logic of `AndroidProcessor`.
- **Newly created files and directories not removed on rollback** — Files and
  directories that did not exist before an `apply` (e.g. a new
  `lib/config/constants.dart`, or an entire `lib/theme/` directory populated
  via `file_mappings`) remained in the project after a rollback because the
  backup only tracked files that were present before the apply.
  `BackupRecord` now carries a `newPaths` list (serialised as `new_paths` in
  `metadata.json`) of absolute paths that were tracked as non-existent at
  backup time.  `BackupManager.restore` deletes every path in `newPaths`
  after restoring the backed-up files.
- **Existing destination directories not fully backed up** — `copyDirectory`
  plan operations with an existing destination only recorded the top-level
  path in the old code; the individual files inside were never snapshotted.
  `createBackup` now iterates the directory tree and backs up each file,
  enabling full restore of any directory that was overwritten by apply.

### Added (0.5.0 original features)
- **Automatic backup before non-dry-run `apply`** — Before each `apply`
  run (when `--dry-run` is not set) the orchestrator snapshots every
  destination file referenced by the execution plan into
  `.ffo/backups/<id>/`.  A `metadata.json` file records the flavor name,
  timestamp, file list, pre-apply checksums, and (after the apply
  completes) post-apply checksums.
- **`rollback` CLI command** — Restores project files to their pre-apply
  state.
  - `rollback --latest` — Restores from the most recent backup.
  - `rollback --id <id>` — Restores from a specific backup by its
    identifier (shown in the apply log).
  - `rollback --force` — Overrides checksum conflicts when files have been
    manually edited after the last apply.
  - Exit code `0` on success; `1` if no backup is found or a conflict
    prevents the restore.
- **`FlavorOrchestrator.rollbackLatest({bool force})`** — Public method
  that restores the most recent backup programmatically.
- **`FlavorOrchestrator.rollbackById(String id, {bool force})`** — Public
  method that restores a specific backup by ID.
- **`FlavorOrchestrator.listBackups()`** — Public method returning all
  available backups sorted newest-first.
- **`BackupManager`** (`lib/src/utils/backup_manager.dart`) — New utility
  class that implements persistent backup creation, finalisation (post-apply
  checksums), listing, and file restoration with conflict detection.
- **`BackupRecord`** and **`BackupEntry`** — Immutable data models
  describing a backup snapshot and its per-file entries, both with
  `toJson()` / `fromJson()` support and exported as public API.
- **`crypto` package dependency** — Used for SHA-256 checksum computation.
- **`.ffo/` in `.gitignore`** — Backup artifacts are not tracked by Git.
- **Tests** — `test/utils/backup_manager_test.dart` covers:
  - Backup directory and `metadata.json` creation
  - Backed-up file content integrity
  - Pre-apply checksum correctness
  - Skipping non-existent destination files
  - Post-apply checksum persistence via `finalizeBackup`
  - `listBackups` / `latestBackup` (empty, single, newest-first ordering)
  - Successful restore with content verification
  - Empty-entries restore returning `true`
  - Conflict detection (returns `false` without `--force`)
  - `--force` overrides conflict and restores correctly
  - Restore without post-apply checksums (no false conflicts)
  - `BackupRecord` JSON roundtrip
- **Integration tests** — `test/orchestrator_rollback_test.dart` covers:
  - `rollbackLatest` returns `false` when no backups exist
  - Full apply → rollback cycle restoring original file content
  - Dry-run apply does not create a backup
  - `rollbackById` returns `false` for unknown ID
  - `listBackups` returns empty list before any apply
  - `listBackups` returns backup after a non-dry-run apply

### Changed
- **`FlavorOrchestrator.applyFlavor()`** — Now creates a persistent backup
  (via `BackupManager.createBackup`) before mutating files, and finalises
  it (via `BackupManager.finalizeBackup`) after a successful commit.
  Dry-run mode is unchanged.
- **CLI help** — `rollback` command added to `COMMANDS` section with usage
  examples.
- **Version** bumped to `0.5.0`.

## [0.4.0] - 2026-02-24

### Added
- **`plan` command** - Preview the operations that would be performed for a
  flavor without mutating any files.
  - Options: `--flavor` (required), `--config`, `--platform`, `--verbose`,
    `--output` (`text` | `json`).
  - Text output shows a per-platform summary with operation kind, description,
    source and destination paths.
  - JSON output is the serialised `ExecutionPlan.toJson()` — deterministic and
    CI-friendly.
  - Exit code `0` on success; `1` if the flavor is not found or config is
    invalid.
- **`FlavorOrchestrator.planFlavor()`** - New public method that returns the
  `ExecutionPlan` for a flavor without executing it. Reuses the private
  `_buildExecutionPlan()` pipeline, so the plan is guaranteed to match the
  operations that `applyFlavor()` would perform.
- **Tests** — `test/orchestrator_plan_test.dart` covers:
  - Flavor name and platform propagation
  - Android-only and iOS-only plan filtering
  - Asset `copyFile` operation for existing file mappings
  - `skip` operation for missing source paths
  - No-mutation guarantee (file system unchanged after `planFlavor`)
  - Operation order (android → ios → assets)
  - `toJson()` top-level key stability
  - `toJson()` operation entries contain required keys
  - Error path: unknown flavor throws `FormatException`
  - Provisioning path adds `copyFile` operation in Android plan

### Changed
- **CLI help** — `plan` command added to `COMMANDS` section and usage examples.
- **Version** bumped to `0.4.0`.

## [0.3.0] - 2026-02-22

### Added
- **Typed Operation Models** - New immutable models provide a structured representation of every step the orchestrator performs:
  - `OperationKind` enum — four operation types: `copyFile`, `copyDirectory`, `writeFile`, `skip`.
  - `PlannedOperation` — describes a single step (kind, description, source/destination paths, platform). Serialisable via `toJson()`.
  - `ExecutionPlan` — ordered collection of `PlannedOperation`s for a flavor apply, with computed counts (`totalOperations`, `activeOperations`, `skippedOperations`) and `toJson()` for machine-readable output. Includes static platform constants (`platformAndroid`, `platformIos`, `platformAssets`).
- **Shared Planning Refactor** - `FlavorOrchestrator` now builds an `ExecutionPlan` as an internal planning phase before executing operations, via the new private `_buildExecutionPlan()` method. This is the foundation reused by both `apply` and the upcoming `plan` command (`v0.4.0`).
- **`AssetProcessor.planFileMappings()`** - New method generates a `List<PlannedOperation>` describing file-mapping operations without touching the file system. Used by `_buildExecutionPlan()` and available for future preview commands.
- **Exported Models** - `ExecutionPlan`, `PlannedOperation`, and `OperationKind` are now part of the public library API.
- **Test Coverage** - New `test/models/execution_plan_test.dart` covers:
  - `OperationKind` enum values and names
  - `PlannedOperation` construction, `toJson()` serialization, and null-omission
  - `ExecutionPlan` counts, `forPlatform()` filtering, `toJson()` shape
  - `AssetProcessor.planFileMappings()` for file, directory, and missing-source scenarios, including a no-mutation guarantee

### Changed
- **`FlavorOrchestrator.applyFlavor()`** - Now calls `_buildExecutionPlan()` at the start of each apply run and logs active/skipped operation counts at debug level. Execution behavior is unchanged.
- **Documentation** - README updated with v0.3.0 highlights and architecture description.

## [0.2.0] - 2026-02-22

### Added
- **Apply Dry-run Mode** - New `--dry-run` (`-d`) option for `apply` executes the full apply flow without changing files.
- **Dry-run Destination Validation** - Dry-run now validates destination files/directories exist for write/copy operations.
- **Dry-run Test Coverage** - Added tests for dry-run validation behavior and no-write guarantees.

### Changed
- **CLI Help and Usage** - Updated command help, examples, and version output for `0.2.0`.
- **Documentation Refresh** - README updated with dry-run examples and behavior details.

## [0.1.9] - 2026-02-22

### Added
- **External YAML Configuration Path** - New CLI option `--config` (`-c`) for loading flavor configuration from a YAML file outside the project root, designed for CI/CD workflows (for example Jenkins).
- **Programmatic External Config Support** - `FlavorOrchestrator` now accepts `configPath` to load configuration from an explicit external YAML file.
- **Parser External Path Handling** - `ConfigParser` now supports explicit external config paths (absolute or project-relative) with clear missing-file errors.
- **Test Coverage for External Config** - Added parser tests for:
  - absolute external config path
  - project-relative external config path
  - missing external config file behavior

### Changed
- **CLI Commands Updated** - `apply`, `list`, `info`, and `validate` now accept `--config`.
- **Documentation Updates** - README and example docs updated with 0.1.9 references and CI/CD examples for external config usage.

## [0.1.8] - 2026-02-16

### Added
- **Enhanced Example App UI** - Completely redesigned example app to visually demonstrate flavor-specific resources:
  - **App Icon Display** - Shows flavor-specific SVG icons (dev/staging/production) with rounded corners and shadow
  - **Environment Info Section** - Displays current flavor label and debug banner status
  - **Color Showcase** - Visual color chips displaying all flavor colors (primary, accent, background, success, warning, error, text)
  - **Typography Preview** - Live examples of heading, body, and caption text with size information
  - **Configuration Display** - Shows all flavor-specific config values (API URL, environment, timeout, analytics, debug mode)
  - **Scrollable Layout** - ListView with card-based sections for better organization and readability
- **flutter_svg Dependency** - Added `flutter_svg: ^2.0.10+1` to example app for SVG icon rendering
- **Icon Assets Configuration** - Added asset paths for flavor-specific SVG icons in example pubspec.yaml
- **Fallback Files** - Created placeholder files in `lib/theme/` and `lib/config/` that display "NO FLAVOR" when orchestrator hasn't been applied
  - `lib/theme/app_theme.dart` - Fallback AppTheme class with grey colors
  - `lib/theme/colors.dart` - Fallback ColorPalette class
  - `lib/theme/typography.dart` - Fallback Typography class  
  - `lib/config/app_config.dart` - Fallback AppConfig class

### Changed
- **Example App Structure** - Updated `example/lib/main.dart` to use class-based theme/config imports matching the flavor orchestrator's file structure
- **Theme Integration** - App now uses `AppTheme.lightTheme` and `AppTheme.showDebugBanner` from copied flavor files
- **Color Handling** - Updated to work with hex color strings from `ColorPalette` class, converting to Flutter Color objects
- **Typography Namespace** - Added import prefix `app_typography` to avoid conflicts with Flutter's built-in Typography class
- **Example App Behavior** - App now provides immediate visual feedback when different flavors are applied, making testing more intuitive

### Fixed
- **Import Conflicts** - Resolved naming conflicts between custom Typography class and Flutter's Typography
- **Const TextStyle Issues** - Removed const modifiers where dynamic values from flavor configs are used
- **Compilation Errors** - Fixed all type mismatches and undefined reference errors when flavor files are applied

### Technical Details
- Example app now correctly imports and uses:
  - `AppTheme` class for theme configuration and environment labels
  - `ColorPalette` class for hex color definitions
  - `Typography` class for font and size specifications
  - `AppConfig` class for API and feature configuration
- Hex color string to Color conversion implemented for visual color chips
- Dynamic icon path selection based on environment label (dev/staging/production)

## [0.1.7] - 2026-02-15

### Added
- **File Mappings Feature** - New `file_mappings` configuration field in `FlavorConfig` for flavor-specific file and folder copying
- **AssetProcessor** - New processor for handling recursive file and directory copying from source to destination paths
- **Directory Replacement Mode** - New `replace_destination_directories` configuration option for safe atomic directory replacement:
  - Existing directories are temporarily renamed before copying new content
  - Automatic rollback on failure restores original directory
  - Ensures atomic replacement - destination is either completely replaced or unchanged
  - Only affects directory mappings in `file_mappings`, not individual files
- **Automatic Directory Traversal** - Supports both individual files and recursive directory copying with automatic subdirectory creation
- **Comprehensive Logging** - Detailed logging for every file and folder operation with progress tracking
- **Example Assets** - Added example icon files organized by flavor (dev/staging/production) in `example/assets/icons/`
- **Example Resources** - Added flavor-specific theme directories in `example/resources/` demonstrating directory replacement
- **Example Configuration Files** - Added flavor-specific app configuration examples in `example/configs/`
- **Extensive Test Coverage** - New test suite for `AssetProcessor` covering:
  - Single file copying
  - Multiple file mappings
  - Recursive directory copying
  - File replacement scenarios
  - Mixed file and directory operations
  - Empty directory handling
  - Non-existent source path handling
  - Multi-flavor scenarios
  - **Directory replacement with backup/restore**
  - **Failure recovery and rollback**
  - **Nested directory structure handling**

### Changed
- **FlavorConfig Model** - Extended with `fileMappings` property (Map<String, String>) for defining source→destination path mappings
- **Orchestrator Integration** - Updated `FlavorOrchestrator.applyFlavor()` to process file mappings after platform-specific processors
- **Example Configuration** - Updated `example/flavor_config.yaml` with practical `file_mappings` examples for all flavors

### Features
- Copy individual files from source to destination with automatic directory creation
- Recursively copy entire directory trees while maintaining structure
- Automatically replace existing files at destination
- Skip non-existent source paths with warning logs
- Track all operations for backup and rollback support
- Detailed logging of each copied file with relative paths

## [0.1.6] - 2026-02-15

### Fixed
- **Android SDK version handling** - Fixed regex patterns to properly match and replace SDK versions that reference variables (e.g., `flutter.minSdkVersion`)
- SDK version insertion now properly adds missing values to `defaultConfig` or `android` blocks when they don't exist
- Custom Gradle configuration now preserves proper indentation and provides warning about syntax compatibility

### Changed
- Improved regex patterns for `minSdk`, `targetSdk`, and `compileSdk` to match both numeric values and variable references (e.g., `[\w.]+` instead of `\d+`)
- Added fallback logic to insert SDK version entries when they are missing from build files
- Enhanced `_addCustomGradleConfig()` to detect and preserve existing indentation patterns

### Added
- Comprehensive test coverage for SDK version insertion scenarios
- Tests for updating SDK versions with variable references (e.g., `flutter.minSdkVersion`)
- Test for validating build.gradle.kts structure after modifications
- Documentation file `CUSTOM_GRADLE_CONFIG.md` in example project explaining Groovy vs Kotlin DSL syntax differences
- Fixed example project's build.gradle.kts to use proper Kotlin DSL syntax for product flavors

## [0.1.5] - 2026-02-08

### Changed
- **AndroidManifest.xml formatting preservation** - The processor now preserves the original structure, indentation, and whitespace when updating AndroidManifest.xml files
- Replaced XML document parsing and serialization with string-based regex replacements to maintain exact formatting
- Intelligent indentation detection for metadata entries (automatically detects spaces or tabs)

### Added
- New helper methods for format-preserving updates: `_updateManifestPackage()`, `_updateManifestAppName()`, and `_detectMetadataIndentation()`
- Comprehensive test coverage for formatting preservation including:
  - Tests for space-based indentation
  - Tests for tab-based indentation
  - Tests for mixed whitespace scenarios
  - Tests for metadata addition with correct indentation detection

### Fixed
- All flutter analyze issues resolved for code quality compliance

## [0.1.3] - 2026-02-08

### Added
- Support for both Groovy (`build.gradle`) and Kotlin (`build.gradle.kts`) build scripts in Android processor
- Automatic detection of build script type with preference for `.kts` files when both exist
- Comprehensive test coverage for both Groovy and Kotlin build script formats

### Changed
- Enhanced Android processor to handle multiple build script syntaxes
- Updated documentation to reflect support for both build script types

### Fixed
- Fixed all flutter analyze issues for code quality compliance

## [0.1.2] - 2026-02-08

### Fixed
- Improved code documentation and examples
- Enhanced test coverage and reliability
- Updated repository URL in pubspec.yaml

### Changed
- Refined package metadata

## [0.1.0] - 2026-02-08

### Added
- Initial release of Flutter Flavor Orchestrator
- CLI tool for managing Flutter flavor configurations
- YAML-based configuration parser supporting:
  - Bundle ID and Package Name management
  - App name customization
  - Icon asset paths configuration
  - Custom metadata injection
  - Asset management per flavor
  - Provisioning file handling (Firebase configurations)
- Android native file manipulation:
  - AndroidManifest.xml modification via XML package
  - build.gradle flavor configuration injection
  - google-services.json automatic placement
- iOS native file manipulation:
  - Info.plist configuration updates
  - Bundle identifier management
  - GoogleService-Info.plist automatic placement
  - Scheme configuration support
- File management utilities with backup and rollback capabilities
- Comprehensive error handling and logging system
- Clean architecture implementation with separation of concerns
- Full API documentation with doc comments
- Unit test suite for core functionality
- Example project demonstrating all features
- Enterprise-level code quality with strict linting rules

### Features
- Command-line interface with intuitive arguments
- Support for multiple flavors (dev, staging, production, etc.)
- Atomic file operations with automatic rollback on errors
- Detailed logging for debugging and auditing
- Extensible architecture for future enhancements

[0.6.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.6.0
[0.5.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.5.0
[0.4.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.4.0
[0.3.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.3.0
[0.2.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.2.0
[0.1.9]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.9
[0.1.8]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.8
[0.1.1]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.1
[0.1.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.0
