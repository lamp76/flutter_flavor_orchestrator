# Flutter Flavor Orchestrator

☕ **[Buy me a coffee on Ko-fi](https://ko-fi.com/lamp76)** - If this package helps you, consider supporting my work!

[![pub package](https://img.shields.io/pub/v/flutter_flavor_orchestrator.svg)](https://pub.dev/packages/flutter_flavor_orchestrator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Me-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/lamp76) 

Build-time orchestration for Flutter flavors across Android and iOS. Configure environment-specific app identity, native metadata, provisioning files, and resource mappings from a single YAML source.

## What's New (v0.1.9)

- **External YAML Config Path (`--config`)** - Load flavor configuration from a YAML file outside project root (absolute or relative path)
- **CI/CD Friendly Workflow** - Keep production config outside repository and inject it at runtime (for example Jenkins)
- **Programmatic Config Path Support** - `FlavorOrchestrator` supports `configPath` for explicit external configuration loading
- **Backward-Compatible Fallback** - Existing `flavor_config.yaml` / `pubspec.yaml` behavior remains unchanged when `--config` is not provided

## ✨ Features

- **Flavor management** - Configure dev, staging, production, and custom environments
- **Cross-platform native updates** - Apply changes to Android and iOS project files
- **Native file processors** - Update AndroidManifest, Gradle/Gradle KTS, Info.plist, and Xcode project settings
- **Format preservation** - Keep original AndroidManifest indentation and structure
- **Provisioning support** - Manage `google-services.json` and `GoogleService-Info.plist`
- **File mappings** - Copy flavor-specific files and recursive directories
- **Atomic directory replacement** - Backup/restore-safe replacement of destination directories
- **Safe operations** - Automatic backup and rollback on failures
- **YAML-driven configuration** - Single declarative config for all flavors
- **CLI workflow** - `apply`, `list`, `info`, and `validate` commands
- **Validation and error handling** - Pre-checks for config, files, and required fields
- **Documentation and examples** - Full example project and practical guides

## 📋 Table of Contents

- [Installation](#installation)
- [What's New (v0.1.9)](#whats-new-v019)
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
- [License](#license)

## 🚀 Installation

Add `flutter_flavor_orchestrator` to your `pubspec.yaml` dev dependencies:

```yaml
dev_dependencies:
  flutter_flavor_orchestrator: ^0.1.9
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

# Apply to iOS only
flutter_flavor_orchestrator apply --flavor production --platform ios

# Enable verbose output
flutter_flavor_orchestrator apply --flavor dev --verbose
```

Output includes:
- `file_mappings` count for the selected flavor
- `replace_destination_directories` value
- Mapping details (`destination <- source`) when `--verbose` is enabled

### List Command

List all available flavors:

```bash
flutter_flavor_orchestrator list

# List flavors from external YAML
flutter_flavor_orchestrator list --config ./ci/flavor_config.yaml
```

Output includes, for each flavor:
- `file_mappings` count
- `replace_destination_directories` value

### Info Command

Display detailed information about a specific flavor:

```bash
flutter_flavor_orchestrator info --flavor production

# Inspect a flavor from external YAML
flutter_flavor_orchestrator info --flavor production --config ./ci/flavor_config.yaml
```

Output includes:
- Full `file_mappings` entries (`destination <- source`)
- `replace_destination_directories` value
- Explanation of when directory replacement applies and rollback behavior

### Validate Command

Validate all flavor configurations:

```bash
flutter_flavor_orchestrator validate

# Validate external YAML
flutter_flavor_orchestrator validate --config ./ci/flavor_config.yaml
```

Output includes, for each flavor:
- `file_mappings` count
- `replace_destination_directories` value
- A note when directory replacement is enabled for directory mappings

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
│   │   ├── flavor_config.dart
│   │   └── provisioning_config.dart
│   ├── processors/          # Platform processors
│   │   ├── android_processor.dart
│   │   └── ios_processor.dart
│   ├── utils/              # Utilities
│   │   ├── file_manager.dart
│   │   └── logger.dart
│   ├── config_parser.dart  # Configuration parsing
│   └── orchestrator.dart   # Main orchestrator
└── flutter_flavor_orchestrator.dart  # Public API
```

### Key Components

- **FlavorOrchestrator**: Coordinates the entire process
- **ConfigParser**: Parses and validates YAML configurations
- **AndroidProcessor**: Handles Android-specific modifications
- **IosProcessor**: Handles iOS-specific modifications
- **FileManager**: Provides safe file operations with backup/rollback

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

  // List flavors
  final flavors = await orchestrator.listFlavors();

  // Validate configurations
  final valid = await orchestrator.validateConfigurations();
}
```

### Core Classes

- **FlavorConfig**: Represents a complete flavor configuration
- **ProvisioningConfig**: Provisioning file configuration
- **ConfigParser**: Configuration parsing and validation
- **FlavorOrchestrator**: Main orchestration logic

See the [API documentation](https://pub.dev/documentation/flutter_flavor_orchestrator/latest/) for detailed class and method documentation.

## 🔒 Safety Features

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

- Built with ❤️ by [Alessio La Mantia](https://github.com/alessiolm)
- Inspired by the need for better flavor management in Flutter projects
- Uses excellent packages: `args`, `yaml`, `xml`, `path`

## 📞 Support

- 📧 Report issues on [GitHub Issues](https://github.com/alessiolm/flutter_flavor_orchestrator/issues)
- 💬 Ask questions on [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter-flavor-orchestrator)
- 📖 Read the [documentation](https://pub.dev/documentation/flutter_flavor_orchestrator/latest/)

## 🗺️ Roadmap

- [ ] Support for additional platforms (macOS, Windows, Linux)
- [ ] Icon generation integration
- [ ] Enhanced scheme management for iOS
- [ ] Build flavor integration with flutter build commands
- [ ] Interactive CLI mode
- [ ] Configuration templates
- [ ] Migration tools from other flavor solutions

---

Made with ❤️ for the Flutter community
