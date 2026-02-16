# Example Resources

This directory contains flavor-specific resources for demonstrating the `file_mappings` feature with directory replacement capability.

## Directory Structure

```
resources/
├── dev/
│   └── themes/           # Development environment themes
│       ├── app_theme.dart
│       ├── colors.dart
│       └── typography.dart
├── staging/
│   └── themes/           # Staging environment themes
│       ├── app_theme.dart
│       ├── colors.dart
│       └── typography.dart
└── production/
    └── themes/           # Production environment themes
        ├── app_theme.dart
        ├── colors.dart
        └── typography.dart
```

## Theme Files

Each flavor has its own complete theme configuration with distinct colors:

- **DEV**: Green theme (#4CAF50) with debug banner enabled
- **STAGING**: Orange theme (#FF9800) for testing
- **PRODUCTION**: Blue theme (#2196F3) for production

## Directory Replacement Feature

When using `replace_destination_directories: true`, the entire destination theme directory will be safely replaced:

1. **Backup**: Existing `lib/theme/` directory is temporarily renamed
2. **Copy**: New theme directory tree is copied from `resources/{flavor}/themes/`
3. **Cleanup**: On success, the backup is removed; on failure, it's restored

### Example Configuration

```yaml
dev:
  replace_destination_directories: true
  file_mappings:
    'lib/theme': 'resources/dev/themes'
```

This ensures that the theme directory is completely replaced with flavor-specific files, removing any old files that might not exist in the new flavor.

## Usage

Apply a flavor to see the themes being replaced:

```bash
flutter pub run flutter_flavor_orchestrator apply --flavor dev
```

The entire `lib/theme/` directory will be replaced with the contents of `resources/dev/themes/`.
