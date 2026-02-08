# Example Configs

This directory contains flavor-specific configuration files for demonstration purposes.

## Structure

```
configs/
├── dev/
│   ├── google-services.json          # Android Firebase config (dev)
│   └── GoogleService-Info.plist      # iOS Firebase config (dev)
├── staging/
│   ├── google-services.json          # Android Firebase config (staging)
│   └── GoogleService-Info.plist      # iOS Firebase config (staging)
└── production/
    ├── google-services.json          # Android Firebase config (production)
    └── GoogleService-Info.plist      # iOS Firebase config (production)
```

## Usage

The Flutter Flavor Orchestrator will automatically copy the appropriate configuration files to your Android and iOS directories based on the flavor you apply.

For example:
- When you run `flutter_flavor_orchestrator apply --flavor dev`, it will copy `configs/dev/google-services.json` to `android/app/` and `configs/dev/GoogleService-Info.plist` to `ios/Runner/`.

## Important Notes

⚠️ **Security Warning**: Never commit real Firebase configuration files to version control if they contain sensitive information!

For this example, you should:
1. Create placeholder files for demonstration
2. Add the `configs/` directory to `.gitignore` for real projects
3. Store actual configuration files securely (e.g., encrypted or in secure CI/CD variables)

## Creating Your Own Config Files

To use this with your real project:

1. Download your Firebase configuration files from the Firebase Console
2. Create the appropriate directories (`dev/`, `staging/`, `production/`)
3. Place the configuration files for each environment in their respective directories
4. Update the paths in `flavor_config.yaml` to match your structure
