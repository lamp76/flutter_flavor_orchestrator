# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.1]: https://github.com/lamp76/flutter_flavor_orchestrator/releases/tag/v0.1.1
[0.1.0]: https://github.com/alessiolm/flutter_flavor_orchestrator/releases/tag/v0.1.0
