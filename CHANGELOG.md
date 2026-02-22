# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.2.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.2.0
[0.1.9]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.9
[0.1.8]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.8
[0.1.1]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.1
[0.1.0]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.0
