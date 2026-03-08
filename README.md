# Flutter Flavor Orchestrator

☕ **[Buy me a coffee on Ko-fi](https://ko-fi.com/lamp76)** - If this package helps you, consider supporting my work!

[![CI](https://github.com/lamp76/flutter_flavor_orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/lamp76/flutter_flavor_orchestrator/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/flutter_flavor_orchestrator.svg)](https://pub.dev/packages/flutter_flavor_orchestrator)
[![pub points](https://img.shields.io/pub/points/flutter_flavor_orchestrator)](https://pub.dev/packages/flutter_flavor_orchestrator/score)
[![popularity](https://img.shields.io/pub/popularity/flutter_flavor_orchestrator)](https://pub.dev/packages/flutter_flavor_orchestrator/score)
[![likes](https://img.shields.io/pub/likes/flutter_flavor_orchestrator)](https://pub.dev/packages/flutter_flavor_orchestrator/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Me-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/lamp76)

Build-time orchestration for Flutter flavors across Android and iOS. Configure environment-specific app identity, native metadata, provisioning files, and resource mappings from a single YAML source.

## What's New (v0.7.0)

- **`--output json` for all commands** — Every command (`list`, `info`,
  `validate`, `plan`, `rollback`) now supports `--output json` for
  machine-readable output, enabling robust CI automation.
- **Stable JSON top-level keys** — Each command emits a JSON object with a
  predictable `command` key and command-specific payload keys (see
  [CLI Usage](#-cli-usage) for details per command).
- **Silent mode** — When `--output json` is active, logger text output is
  fully suppressed so only valid JSON appears on `stdout`.
- **`FlavorConfig.toJson()` / `ProvisioningConfig.toJson()`** — New
  serialisation methods on the model classes; exported as public API.
- **`FlavorOrchestrator.getFlavorInfo()`** — Returns the `FlavorConfig` for a
  flavor without writing any text output (used by `info --output json`).
- **`FlavorOrchestrator.validateConfigurationsDetailed()`** — Returns
  per-flavor validation results as a `List<Map<String, Object?>>` (used by
  `validate --output json`).
- **`OutputFormat` / `OutputFormatter` / formatter helpers** — New shared
  utilities exported as public API for downstream programmatic use.

## Previous: What's New (v0.6.0)

- **Conflict detection before `apply`** — Every `apply` run now analyzes the
  execution plan for conflicts before touching any files.  Two classes of
  conflict are detected:
  - **Duplicate destinations** — two or more operations target the same output
    path (e.g. a `file_mappings` entry writes to the same file as a platform
    processor).
  - **Overlapping destinations** — one destination path is a parent directory
    of another (e.g. `lib/` and `lib/config/app_config.dart`).
- **`apply --force`** — Pass `--force` to override conflict guardrails and
  apply the flavor anyway (conflicts are logged as warnings).
- **`ConflictAnalyzer` public API** — New `ConflictAnalyzer` class and
  `ConflictReport` / `ConflictSeverity` models exported as public API for
  programmatic conflict checks on any `ExecutionPlan`.
- Conflicts **fail fast** before any file mutation.

## Previous: What's New (v0.5.0)

- **Automatic backup before `apply`** — Every non-dry-run `apply` now snapshots
  all destination files into `.ffo/backups/` before touching them.  Each backup
  stores file content, pre-apply checksums, and (after a successful apply)
  post-apply checksums so that manual edits can be detected.
- **`rollback` command** — Restore project files to their pre-apply state:
  `flutter_flavor_orchestrator rollback --latest`
- **`rollback --id <id>`** — Restore from a specific backup by its identifier.
- **`rollback --force`** — Override checksum conflicts when files were edited
  after the last apply.
- **`FlavorOrchestrator.rollbackLatest()` / `rollbackById()`** — New public
  API methods for programmatic rollback.

## Previous: What's New (v0.4.0)

- **`plan` command** — Preview operations without mutating files: `flutter_flavor_orchestrator plan --flavor dev`
- **`--output json`** — Machine-readable plan output: `plan --flavor dev --output json`
- **`FlavorOrchestrator.planFlavor()`** — New public method returning an `ExecutionPlan` without executing it

## Previous: What's New (v0.3.0)

- **Typed Operation Models** — `OperationKind`, `PlannedOperation`, `ExecutionPlan` added as public API; each operation is now a first-class immutable value with `toJson()` support
- **Shared Planning Foundation** — `FlavorOrchestrator` builds an `ExecutionPlan` before executing any apply; now exposed publicly via `planFlavor()` for the `plan` command
- **`AssetProcessor.planFileMappings()`** — generate file-mapping operations without touching the file system (preview without side-effects)

## Previous: What's New (v0.2.0)

- **Dry-run Apply Mode (`--dry-run`)** - Execute full apply processing without changing files
- **Destination Presence Validation** - Dry-run validates destination files/directories exist for every write/copy path
- **Safer Preflight for CI/CD** - Validate flavor application end-to-end before running a real apply

## ✨ Features

- **Flavor management** - Configure dev, staging, production, and custom environments
- **Cross-platform native updates** - Apply changes to Android and iOS project files
- **Native file processors** - Update AndroidManifest, Gradle/Gradle KTS, Info.plist, and Xcode project settings
- **Format preservation** - Keep original AndroidManifest indentation and structure
- **Provisioning support** - Manage `google-services.json` and `GoogleService-Info.plist`
- **File mappings** - Copy flavor-specific files and recursive directories
- **Atomic directory replacement** - Backup/restore-safe replacement of destination directories
- **Persistent backup & rollback** — Automatic pre-apply snapshots with checksum validation and `rollback` CLI command
- **Conflict detection** — Pre-apply duplicate-target and overlapping-destination guardrails; `--force` override
- **Machine-readable JSON output** — `--output json` for all commands (`list`, `info`, `validate`, `plan`, `rollback`); stable top-level keys for CI automation
- **YAML-driven configuration** - Single declarative config for all flavors
- **Typed execution plan** - `ExecutionPlan`, `PlannedOperation`, `OperationKind` models with `toJson()`
- **CLI workflow** - `apply`, `plan`, `rollback`, `list`, `info`, and `validate` commands
- **`plan` command** — Preview operations without file mutations; text and JSON output
- **Validation and error handling** - Pre-checks for config, files, and required fields
- **Documentation and examples** - Full example project and practical guides

## 📋 Table of Contents

- [Installation](#installation)
- [What's New (v0.7.0)](#whats-new-v070)
- [Previous: What's New (v0.6.0)](#previous-whats-new-v060)
- [Previous: What's New (v0.5.0)](#previous-whats-new-v050)
- [Previous: What's New (v0.4.0)](#previous-whats-new-v040)
- [Quick Start](#quick-start)
- [Pub.dev Workflow](#pubdev-workflow)
- [Configuration](#configuration)
- [CLI Usage](#cli-usage)
- [What Gets Modified](#what-gets-modified)
- [Advanced Configuration](#advanced-configuration)
- [Architecture](#architecture)
- [Examples](#examples)
- [Example Project Hints](#example-project-hints)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [Roadmap](#️-roadmap)
- [License](#license)

## 🚀 Installation

Add `flutter_flavor_orchestrator` to your `pubspec.yaml` dev dependencies:

```yaml
dev_dependencies:
  flutter_flavor_orchestrator: ^0.7.0
```

Then run:

```bash
flutter pub get
```

Activate the CLI tool globally (optional):

```bash
dart pub global activate flutter_flavor_orchestrator
```

## ⚡ Quick Start

### 1. Create Configuration File

Create a `flavor_config.yaml` file in your project root:

```yaml
dev:
  bundle_id: com.example.myapp.dev
  app_name: MyApp Dev
  metadata:
    API_URL: https://dev-api.example.com
  provisioning:
    android_google_services: configs/dev/google-services.json
    ios_google_service: configs/dev/GoogleService-Info.plist

production:
  bundle_id: com.example.myapp
  app_name: MyApp
  metadata:
    API_URL: https://api.example.com
  provisioning:
    android_google_services: configs/production/google-services.json
    ios_google_service: configs/production/GoogleService-Info.plist
```

### 2. Apply a Flavor

```bash
# From your project root
flutter pub run flutter_flavor_orchestrator apply --flavor dev

# Alternative (Dart-native invocation)
dart run flutter_flavor_orchestrator apply --flavor dev
```

### 3. Build Your App

```bash
flutter clean
flutter pub get
flutter build apk  # or flutter build ios
```

That's it! Your app is now configured for the dev flavor.

## Pub.dev Workflow

Use this sequence when integrating the package into a real app:

```bash
# 1) Install deps
flutter pub get

# 2) Validate configuration before applying
flutter pub run flutter_flavor_orchestrator validate

# 3) Inspect available flavors
flutter pub run flutter_flavor_orchestrator list

# 4) Apply flavor
flutter pub run flutter_flavor_orchestrator apply --flavor dev --verbose

# 5) Build or run
flutter run
```

Recommended for CI/CD:
- Run `validate` as an early pipeline step
- Use explicit flavor names (`dev`, `staging`, `production`) in build jobs
- Keep flavor-specific files under `configs/`, `assets/`, and `resources/`
- Pass `--config` to load a YAML file from a secure external path (for example Jenkins workspace/secret mounts)

## ⚙️ Configuration

### Configuration File Location

You can place your flavor configuration in either:

1. **Dedicated file**: `flavor_config.yaml` in your project root (recommended)
2. **In pubspec.yaml**: Under a `flavor_config` section
3. **External file path**: Any YAML file passed at runtime with `--config`

External path examples:

```bash
flutter_flavor_orchestrator apply --flavor production --config /secure/jenkins/flavor_config.yaml
flutter_flavor_orchestrator validate --config ./ci/flavor_config.yaml
```

### Configuration Options

Each flavor supports the following configuration options:

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `bundle_id` | String | ✅ | Bundle identifier (iOS) / Package name (Android) |
| `app_name` | String | ✅ | Display name of the application |
| `icon_path` | String | ❌ | Path to app icon assets |
| `metadata` | Map | ❌ | Custom key-value pairs to inject into manifests |
| `assets` | List | ❌ | Flavor-specific asset paths |
| `dependencies` | Map | ❌ | Flavor-specific dependency overrides |
| `provisioning` | Object | ❌ | Provisioning file configuration |
| `android_min_sdk_version` | Integer | ❌ | Android minimum SDK version |
| `android_target_sdk_version` | Integer | ❌ | Android target SDK version |
| `android_compile_sdk_version` | Integer | ❌ | Android compile SDK version |
| `ios_min_version` | String | ❌ | iOS minimum deployment target |
| `custom_gradle_config` | Map | ❌ | Custom Gradle configuration snippets |
| `custom_info_plist_entries` | Map | ❌ | Custom Info.plist entries |
| `file_mappings` | Map | ❌ | Flavor-specific file/folder copying (source→destination) |
| `replace_destination_directories` | Boolean | ❌ | Replace existing directories completely (default: false) |

### Provisioning Configuration

```yaml
provisioning:
  android_google_services: path/to/google-services.json
  ios_google_service: path/to/GoogleService-Info.plist
  additional_files:
    destination/path: source/path
```

### File Mappings (New in v0.1.7)

Copy flavor-specific files and folders from source to destination paths. Supports both individual files and recursive directory copying:

```yaml
dev:
  bundle_id: com.example.app.dev
  app_name: MyApp Dev
  
  # Enable complete directory replacement (optional, default: false)
  replace_destination_directories: true
  
  file_mappings:
    # Copy individual configuration files
    'lib/config/app_config.dart': 'configs/dev/app_config.dart'
    'lib/config/constants.dart': 'configs/shared/constants.dart'
    
    # Copy flavor-specific icons
    'assets/app_icon.svg': 'assets/icons/dev/app_icon.svg'
    
    # Recursively copy entire directories
    'android/app/src/main/res/drawable': 'assets/dev/android/drawables'
    'ios/Runner/Assets.xcassets': 'assets/dev/ios/assets'
    
    # Replace entire theme directory (useful with replace_destination_directories)
    'lib/theme': 'resources/dev/themes'

production:
  bundle_id: com.example.app
  app_name: MyApp
  replace_destination_directories: true
  file_mappings:
    'lib/config/app_config.dart': 'configs/production/app_config.dart'
    'lib/config/constants.dart': 'configs/shared/constants.dart'
    'assets/app_icon.svg': 'assets/icons/production/app_icon.svg'
    'lib/theme': 'resources/production/themes'
```

**Features:**
- 📁 Copy individual files or entire directory trees recursively
- 🔄 Automatically replaces existing files at destination
- 📂 Creates destination directories if they don't exist
- 🔍 Detailed logging for each file operation
- ⚠️ Skips non-existent source paths with warnings
- 🔙 Full backup and rollback support

**Directory Replacement Mode:**

When `replace_destination_directories: true`:
1. 🔒 **Safe Backup**: Existing destination directory is temporarily renamed
2. 📋 **Copy New**: Complete directory tree is copied from source
3. ✅ **Success**: Backup directory is removed
4. ❌ **Failure**: Original directory is automatically restored

This ensures atomic directory replacement - the destination is either completely replaced or left unchanged.

See [example/assets/icons/README.md](example/assets/icons/README.md) and [example/resources/README.md](example/resources/README.md) for practical examples.

### Complete Example

See [example/flavor_config.yaml](example/flavor_config.yaml) for a comprehensive configuration example.

## 🎮 CLI Usage

The package provides a powerful command-line interface:

### Apply Command

Apply a flavor configuration to your project:

```bash
# Apply to both platforms
flutter_flavor_orchestrator apply --flavor dev

# Apply using an external YAML config file
flutter_flavor_orchestrator apply --flavor production --config /secure/jenkins/flavor_config.yaml

# Apply to Android only
flutter_flavor_orchestrator apply --flavor staging --platform android

# Dry-run apply (execute checks without changing files)
flutter_flavor_orchestrator apply --flavor dev --dry-run

# Apply to iOS only
flutter_flavor_orchestrator apply --flavor production --platform ios

# Override conflict guardrails and apply anyway
flutter_flavor_orchestrator apply --flavor dev --force

# Enable verbose output
flutter_flavor_orchestrator apply --flavor dev --verbose
```

Output includes:
- `file_mappings` count for the selected flavor
- `replace_destination_directories` value
- Mapping details (`destination <- source`) when `--verbose` is enabled
- In `--dry-run`, all operations are validated and no files are modified

### Plan Command

Preview the operations that would be performed for a flavor, **without mutating any files**:

```bash
# Preview both platforms (text output)
flutter_flavor_orchestrator plan --flavor dev

# Preview as machine-readable JSON
flutter_flavor_orchestrator plan --flavor dev --output json

# Preview Android-only plan
flutter_flavor_orchestrator plan --flavor staging --platform android

# Preview from an external YAML config
flutter_flavor_orchestrator plan --flavor production --config /secure/jenkins/flavor_config.yaml
```

Output includes a per-platform section listing each operation with its kind (`copyFile`, `copyDirectory`, `writeFile`, `skip`), description, and source/destination paths.

JSON output (`--output json`) returns the serialised `ExecutionPlan` with stable top-level keys:
- `flavor` — flavor name
- `platforms` — target platforms
- `total_operations`, `active_operations`, `skipped_operations` — operation counts
- `operations` — ordered list of operation objects

### Rollback Command

Restore project files to their pre-apply state from a persistent backup created
by the last `apply` run:

```bash
# Rollback to the most recent backup
flutter_flavor_orchestrator rollback --latest

# Rollback to a specific backup by ID (shown in the apply log)
flutter_flavor_orchestrator rollback --id 20260225_194640123_dev

# Force rollback even if files were manually edited after the last apply
flutter_flavor_orchestrator rollback --latest --force

# Rollback and get machine-readable result
flutter_flavor_orchestrator rollback --latest --output json
```

Every non-dry-run `apply` automatically creates a snapshot in `.ffo/backups/`
before touching any files.  The backup stores:
- A copy of every destination file **before** the apply
- SHA-256 checksums of the pre-apply content
- SHA-256 checksums of the post-apply content (for detecting manual edits)

If files have been manually edited **after** the last apply, `rollback` will
report a conflict and exit with code `1`.  Pass `--force` to override.

JSON output (`--output json`) returns a stable object:
- `command` — `"rollback"`
- `success` — `true`/`false`
- `backup_id` — identifier of the restored backup
- `flavor` — flavor name from the backup
- `files_restored` — number of files restored
- `new_paths_removed` — number of newly-created paths removed

On failure (no backup found): `command`, `success: false`, `error`.

### List Command

List all available flavors:

```bash
flutter_flavor_orchestrator list

# List flavors from external YAML
flutter_flavor_orchestrator list --config ./ci/flavor_config.yaml

# Machine-readable JSON output
flutter_flavor_orchestrator list --output json
```

JSON output (`--output json`) returns a stable object:
- `command` — `"list"`
- `count` — total number of flavors
- `flavors` — array of objects, each with `name`, `file_mappings_count`,
  `replace_destination_directories`

### Info Command

Display detailed information about a specific flavor:

```bash
flutter_flavor_orchestrator info --flavor production

# Inspect a flavor from external YAML
flutter_flavor_orchestrator info --flavor production --config ./ci/flavor_config.yaml

# Machine-readable JSON output
flutter_flavor_orchestrator info --flavor production --output json
```

JSON output (`--output json`) returns a stable object:
- `command` — `"info"`
- `flavor` — fully-serialised `FlavorConfig` with all fields including
  `name`, `bundle_id`, `app_name`, `file_mappings`, `file_mappings_count`,
  `replace_destination_directories`, and any optional fields that are set

### Validate Command

Validate all flavor configurations:

```bash
flutter_flavor_orchestrator validate

# Validate external YAML
flutter_flavor_orchestrator validate --config ./ci/flavor_config.yaml

# Machine-readable JSON output
flutter_flavor_orchestrator validate --output json
```

JSON output (`--output json`) returns a stable object:
- `command` — `"validate"`
- `valid` — `true` if all flavors are valid
- `flavors` — array of per-flavor objects, each with `name`, `valid`,
  `errors` (list of error strings, empty when valid)

All flavors are evaluated regardless of errors — `--output json` never aborts
early like text mode does.

### Help

Display help information:

```bash
flutter_flavor_orchestrator --help
```

## 🔨 What Gets Modified

### Android

When you apply a flavor, the following Android files are automatically updated:

#### `android/app/src/main/AndroidManifest.xml`
- ✏️ Package name (`package` attribute)
- ✏️ Application label (`android:label`)
- ✏️ Metadata entries (`<meta-data>` tags)
- 🎨 **Preserves original formatting** - Maintains exact indentation, whitespace, and structure

#### `android/app/build.gradle` or `android/app/build.gradle.kts`
- ✏️ Application ID (`applicationId`)
- ✏️ SDK versions (`minSdkVersion`, `targetSdkVersion`, `compileSdkVersion`)
- ✏️ Custom Gradle configuration
- 🔄 Supports both Groovy (`.gradle`) and Kotlin (`.gradle.kts`) build scripts

#### `android/app/google-services.json`
- 📋 Copied from configured path

### iOS

#### `ios/Runner/Info.plist`
- ✏️ Bundle display name (`CFBundleDisplayName`)
- ✏️ Bundle identifier (`CFBundleIdentifier`)
- ✏️ Minimum OS version (`MinimumOSVersion`)
- ✏️ Custom plist entries

#### `ios/Runner.xcodeproj/project.pbxproj`
- ✏️ Product bundle identifier (`PRODUCT_BUNDLE_IDENTIFIER`)
- ✏️ Deployment target (`IPHONEOS_DEPLOYMENT_TARGET`)

#### `ios/Runner/GoogleService-Info.plist`
- 📋 Copied from configured path

## 🏗️ Advanced Configuration

### Custom Gradle Configuration

Inject custom Gradle snippets:

```yaml
custom_gradle_config:
  defaultConfig: |
    buildConfigField "String", "API_URL", "\"https://api.example.com\""
    buildConfigField "boolean", "DEBUG_MODE", "false"
  buildTypes: |
    release {
        shrinkResources true
        minifyEnabled true
    }
```

### Custom Info.plist Entries

Add custom iOS configuration:

```yaml
custom_info_plist_entries:
  NSAppTransportSecurity:
    NSAllowsArbitraryLoads: true
  UIBackgroundModes:
    - fetch
    - remote-notification
  ITSAppUsesNonExemptEncryption: false
```

### Metadata Injection

Add custom metadata to both platforms:

```yaml
metadata:
  API_URL: https://api.example.com
  API_KEY: your_api_key
  FEATURE_FLAG_X: true
  MAX_RETRIES: 3
```

**Android**: Added as `<meta-data>` tags in AndroidManifest.xml

**iOS**: Added as custom entries in Info.plist

## 🏛️ Architecture

The package follows Clean Architecture principles:

```
lib/
├── src/
│   ├── models/              # Data models
│   │   ├── execution_plan.dart      # Ordered plan of PlannedOperations (v0.3.0)
│   │   ├── flavor_config.dart       # FlavorConfig with toJson() (v0.7.0)
│   │   ├── operation_kind.dart      # OperationKind enum (v0.3.0)
│   │   ├── planned_operation.dart   # Single step descriptor (v0.3.0)
│   │   └── provisioning_config.dart # ProvisioningConfig with toJson() (v0.7.0)
│   ├── processors/          # Platform processors
│   │   ├── android_processor.dart
│   │   ├── asset_processor.dart     # planFileMappings() added (v0.3.0)
│   │   └── ios_processor.dart
│   ├── utils/              # Utilities
│   │   ├── backup_manager.dart      # Persistent backup/restore (v0.5.0)
│   │   ├── conflict_analyzer.dart   # Duplicate/overlap detection (v0.6.0)
│   │   ├── file_manager.dart
│   │   ├── logger.dart              # silent mode added (v0.7.0)
│   │   └── output_formatter.dart    # OutputFormat, OutputFormatter (v0.7.0)
│   ├── config_parser.dart  # Configuration parsing; parseConfigUnchecked() (v0.7.0)
│   └── orchestrator.dart   # Main orchestrator; getFlavorInfo(),
│                           #   validateConfigurationsDetailed(), silent (v0.7.0)
└── flutter_flavor_orchestrator.dart  # Public API
```

### Key Components

- **FlavorOrchestrator**: Coordinates the entire process; builds an `ExecutionPlan` before applying; runs conflict analysis before any file mutation
- **ConfigParser**: Parses and validates YAML configurations; `parseConfigUnchecked()` for per-flavor validation (v0.7.0)
- **AndroidProcessor**: Handles Android-specific modifications
- **IosProcessor**: Handles iOS-specific modifications
- **AssetProcessor**: Handles file-mapping copy and planning operations
- **ExecutionPlan / PlannedOperation / OperationKind**: Typed, immutable operation models with JSON serialisation
- **ConflictAnalyzer**: Pre-apply conflict detection — duplicate and overlapping destinations (v0.6.0)
- **BackupManager**: Persistent pre-apply snapshots with checksum validation and rollback
- **FileManager**: Provides safe file operations with backup/rollback
- **OutputFormatter**: `typedef` for result-writing functions; `textOutputFormatter` (no-op), `jsonOutputFormatter` (stdout JSON), `formatterFor()`, `parseOutputFormat()` — all exported as public API (v0.7.0)

## 📚 Examples

Check out the [example](example/) directory for a complete working example with:

- ✅ Multiple flavor configurations
- ✅ Firebase integration
- ✅ Custom metadata
- ✅ Platform-specific configurations
- ✅ Complete Flutter app
- ✅ File mappings and safe directory replacement
- ✅ Visual flavor verification in the running UI

## Example Project Hints

The example app is designed so you can immediately see flavor changes on screen.

### Quick demo in `example/`

```bash
cd example
flutter pub get

# Apply development flavor
flutter pub run flutter_flavor_orchestrator apply --flavor dev --verbose
flutter run
```

Then switch flavor and run again:

```bash
flutter pub run flutter_flavor_orchestrator apply --flavor staging --verbose
flutter run
```

What to look for in the UI:
- Flavor-specific SVG icon
- Environment/debug banner values
- Color and typography preview from copied theme files
- API/config values from copied `lib/config/app_config.dart`

Useful example references:
- Full config: [example/flavor_config.yaml](example/flavor_config.yaml)
- File mapping assets: [example/assets/icons/README.md](example/assets/icons/README.md)
- Theme replacement resources: [example/resources/README.md](example/resources/README.md)
- Gradle syntax notes: [example/CUSTOM_GRADLE_CONFIG.md](example/CUSTOM_GRADLE_CONFIG.md)

## 📖 API Documentation

### Programmatic Usage

You can also use the package programmatically in your Dart code:

```dart
import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';

void main() async {
  final orchestrator = FlavorOrchestrator(
    projectRoot: '/path/to/project',
    configPath: '/secure/jenkins/flavor_config.yaml',
    verbose: true,
  );

  // Apply a flavor
  final success = await orchestrator.applyFlavor(
    'dev',
    platforms: ['android', 'ios'],
  );

  // Apply overriding conflict guardrails
  final forcedSuccess = await orchestrator.applyFlavor(
    'dev',
    platforms: ['android', 'ios'],
    force: true,
  );

  // Preview operations without mutating files
  final plan = await orchestrator.planFlavor(
    'dev',
    platforms: ['android', 'ios'],
  );

  // Check for conflicts before applying
  final conflicts = const ConflictAnalyzer().analyze(plan);
  for (final conflict in conflicts) {
    print('[${conflict.severity.name}] ${conflict.code}: ${conflict.message}');
  }

  // List flavors
  final flavors = await orchestrator.listFlavors();

  // Validate configurations
  final valid = await orchestrator.validateConfigurations();
}
```

### Core Classes

- **FlavorConfig**: Represents a complete flavor configuration
- **ProvisioningConfig**: Provisioning file configuration
- **ExecutionPlan**: Ordered list of `PlannedOperation`s for a flavor; serialisable via `toJson()`
- **PlannedOperation**: Immutable descriptor of a single orchestration step with kind, paths, and platform
- **OperationKind**: Enum — `copyFile`, `copyDirectory`, `writeFile`, `skip`
- **ConflictReport**: Immutable conflict descriptor with `code`, `severity`, `message`, `conflictingPaths`, and `toJson()`
- **ConflictSeverity**: Enum — `error`, `warning`
- **ConflictAnalyzer**: Analyses an `ExecutionPlan` for duplicate and overlapping destinations
- **ConfigParser**: Configuration parsing and validation
- **FlavorOrchestrator**: Main orchestration logic

See the [API documentation](https://pub.dev/documentation/flutter_flavor_orchestrator/latest/) for detailed class and method documentation.

## 🔒 Safety Features

### Conflict Detection (New in v0.6.0)

Before touching any files, `apply` scans the execution plan for two classes
of conflict:

- **Duplicate destinations** — two operations write to the same output path.
  Example: a `file_mappings` entry that targets
  `android/app/src/main/AndroidManifest.xml` when the Android platform
  processor already writes to that path.
- **Overlapping destinations** — one destination is a parent directory of
  another (e.g. `lib/` and `lib/config/app_config.dart` both appear as
  destinations).

If any conflict is found, `apply` aborts immediately (before any mutation) and
exits with code `1`.  Pass `--force` to override and continue despite the
conflicts (conflicts are then logged as warnings).

```bash
# Abort on conflict (default)
flutter_flavor_orchestrator apply --flavor dev

# Override conflicts and apply anyway
flutter_flavor_orchestrator apply --flavor dev --force
```

You can also inspect conflicts programmatically using the public API:

```dart
final plan = await orchestrator.planFlavor('dev');
final conflicts = const ConflictAnalyzer().analyze(plan);
for (final c in conflicts) {
  print('[${c.severity.name}] ${c.code}: ${c.message}');
}
```

### Automatic Backups

The orchestrator automatically creates backups of all modified files before making changes. If an error occurs, all changes are automatically rolled back.

### Validation

All configurations are validated before being applied:

- ✅ Required fields presence
- ✅ Bundle ID format validation
- ✅ File existence checks
- ✅ YAML syntax validation

### Error Handling

Comprehensive error handling with clear, actionable error messages:

- 🔴 Missing configuration files
- 🔴 Invalid bundle ID formats
- 🔴 Missing native directories
- 🔴 File operation failures

## 🧪 Testing

The package includes a comprehensive test suite:

```bash
# Run all tests
dart test

# Run with coverage
dart test --coverage
```

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ by [Alessio La Mantia](https://github.com/lamp76)
- Inspired by the need for better flavor management in Flutter projects
- Uses excellent packages: `args`, `yaml`, `xml`, `path`

## 📞 Support

- 📧 Report issues on [GitHub Issues](https://github.com/lamp76/flutter_flavor_orchestrator/issues)
- 💬 Ask questions on [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter-flavor-orchestrator)
- 📖 Read the [documentation](https://pub.dev/documentation/flutter_flavor_orchestrator/latest/)

## 🗺️ Roadmap

The full roadmap is in [ROADMAP.md](ROADMAP.md). Here is a compact summary of progress and upcoming milestones toward the `v1.0.0` stable release.

### Released

| Version | Highlights |
|---------|-----------|
| **v0.1.x** | Initial CLI (`apply`, `list`, `info`, `validate`), Android/iOS processors, file mappings, dry-run, external config path |
| **v0.2.0** | Dry-run destination-presence validation, safer CI preflight |
| **v0.3.0** | `OperationKind`, `PlannedOperation`, `ExecutionPlan` typed models · shared `_buildExecutionPlan()` in orchestrator · `AssetProcessor.planFileMappings()` |
| **v0.4.0** | `plan` command — preview operations without mutating files; `planFlavor()` public API; `--output json` |
| **v0.5.0** | `rollback` command + timestamped backup before every non-dry-run apply; `rollbackLatest()` / `rollbackById()` public API |
| **v0.6.0** | Conflict detection — duplicate-target and overlapping-destination guardrails; `apply --force`; `ConflictAnalyzer` public API |
| **v0.7.0** | Automation contract — `--output json` for `list`, `info`, `validate`, `plan`, `rollback`; `OutputFormatter` public API; `FlavorConfig.toJson()` |

### Upcoming

| Version | Theme | Key deliverable |
|---------|-------|----------------|
| **v0.8.0** | Schema hardening | `schema_version` enforcement, `validate --strict`, migration scaffold |
| **v0.9.0** | Diagnostics | `doctor` command with categorised findings (error/warning/info) |
| **v1.0.0** | Stable | Production-ready `doctor`, docs freeze, no breaking changes without migration path |
| **v1.1.0** | Post-1.0 | Env-var interpolation (`${VAR:-default}`), `init` command |

---

Made with ❤️ for the Flutter community
