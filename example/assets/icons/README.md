# Example Assets and Icons

This directory contains flavor-specific assets and icons for demonstrating the `file_mappings` feature of Flutter Flavor Orchestrator.

## Directory Structure

```
assets/
├── icons/
│   ├── dev/           # Development environment icons (green)
│   ├── staging/       # Staging environment icons (orange)
│   └── production/    # Production environment icons (blue)
└── ...
```

## Icon Files

Each flavor has its own set of icons with distinct colors for easy identification:

- **DEV**: Green background (#4CAF50) with "DEV" text and yellow indicator
- **STAGING**: Orange background (#FF9800) with "STAGING" text and blue indicator  
- **PRODUCTION**: Blue background (#2196F3) with "PRODUCTION" text and green indicator

## Usage

These icons are automatically copied to the appropriate platform directories when applying a flavor using the `file_mappings` configuration in `flavor_config.yaml`.

Example configuration:

```yaml
dev:
  bundle_id: com.example.app.dev
  app_name: MyApp Dev
  file_mappings:
    'lib/config/app_config.dart': 'configs/dev/app_config.dart'
    'assets/app_icon.svg': 'assets/icons/dev/app_icon.svg'
```

## Customization

To use your own icons:

1. Replace the SVG files in each flavor directory
2. Update the `file_mappings` section in `flavor_config.yaml`
3. Run `flutter_flavor_orchestrator apply --flavor <flavor_name>`

The asset processor will recursively copy files and folders as specified in your configuration.
