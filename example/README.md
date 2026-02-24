# Example Flutter App - Flavor Orchestrator Demo

This example demonstrates how to use the `flutter_flavor_orchestrator` package to manage multiple app flavors (dev, staging, production) in a Flutter project.

## Features Demonstrated

- ✅ Multiple flavor configurations (dev, staging, production)
- ✅ Platform-specific bundle IDs and app names
- ✅ Custom metadata injection
- ✅ Provisioning file management (Firebase)
- ✅ SDK version configuration
- ✅ Custom Gradle and Info.plist entries
- ✅ Flavor-specific assets
- ✅ External YAML config loading with `--config` (CI/CD friendly)
- ✅ Plan preview with `plan --flavor <name>` (no file mutations)

## Project Structure

```
example/
├── lib/
│   └── main.dart              # Simple Flutter app
├── android/                   # Android native files
├── ios/                       # iOS native files
├── configs/                   # Flavor-specific config files
│   ├── dev/
│   │   ├── google-services.json
│   │   └── GoogleService-Info.plist
│   ├── staging/
│   │   ├── google-services.json
│   │   └── GoogleService-Info.plist
│   └── production/
│       ├── google-services.json
│       └── GoogleService-Info.plist
├── assets/                    # Flavor-specific assets
│   ├── dev/
│   ├── staging/
│   └── production/
├── flavor_config.yaml         # Flavor configurations
└── pubspec.yaml
```

## Usage

### 1. List Available Flavors

```bash
flutter_flavor_orchestrator list
```

### 2. View Flavor Details

```bash
flutter_flavor_orchestrator info --flavor dev
```

### 3. Apply a Flavor

Apply dev flavor to both platforms:
```bash
flutter_flavor_orchestrator apply --flavor dev
```

Apply staging flavor to Android only:
```bash
flutter_flavor_orchestrator apply --flavor staging --platform android
```

Apply production flavor to iOS only:
```bash
flutter_flavor_orchestrator apply --flavor production --platform ios
```

### 4. Preview Operations (Plan)

Preview what would be applied without mutating any files:
```bash
flutter_flavor_orchestrator plan --flavor dev
```

Or get machine-readable JSON output:
```bash
flutter_flavor_orchestrator plan --flavor dev --output json
```

### 5. Validate Configurations

```bash
flutter_flavor_orchestrator validate
```

### 5. Use External Configuration Path (CI/CD)

Load flavor configuration from a YAML file outside the project root:

```bash
flutter_flavor_orchestrator apply --flavor production --config /secure/jenkins/flavor_config.yaml
flutter_flavor_orchestrator validate --config /secure/jenkins/flavor_config.yaml
```

## Configuration Explained

The `flavor_config.yaml` file contains three flavor configurations:

### Development (dev)
- Bundle ID: `com.example.flavorapp.dev`
- App Name: `FlavorApp Dev`
- API URL: `https://dev-api.example.com`
- Logging: Enabled
- Firebase: Dev configuration files

### Staging
- Bundle ID: `com.example.flavorapp.staging`
- App Name: `FlavorApp Staging`
- API URL: `https://staging-api.example.com`
- Logging: Enabled
- Firebase: Staging configuration files

### Production
- Bundle ID: `com.example.flavorapp`
- App Name: `FlavorApp`
- API URL: `https://api.example.com`
- Logging: Disabled
- Firebase: Production configuration files

## What Gets Modified

When you apply a flavor, the orchestrator automatically updates:

### Android
- `android/app/src/main/AndroidManifest.xml` - package name, app label, metadata
- `android/app/build.gradle` or `build.gradle.kts` - applicationId, SDK versions, custom config (supports both Groovy and Kotlin scripts)
- `android/app/google-services.json` - Firebase configuration

### iOS
- `ios/Runner/Info.plist` - bundle ID, app name, custom entries
- `ios/Runner.xcodeproj/project.pbxproj` - bundle identifier, deployment target
- `ios/Runner/GoogleService-Info.plist` - Firebase configuration

## Building the App

After applying a flavor:

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Run the app
flutter run
```

## Next Steps

1. Review the changes in your native files
2. Commit the changes or use the automatic backup/rollback feature
3. Configure your CI/CD pipeline to use different flavors for different environments
4. Customize the flavor_config.yaml to match your project needs

## Tips

- Use `--verbose` flag for detailed debug output
- The orchestrator creates automatic backups of modified files
- If something goes wrong, changes are automatically rolled back
- You can add custom metadata and configuration specific to your needs
