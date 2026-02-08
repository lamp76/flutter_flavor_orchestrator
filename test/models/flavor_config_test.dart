import 'package:flutter_flavor_orchestrator/src/models/flavor_config.dart';
import 'package:flutter_flavor_orchestrator/src/models/provisioning_config.dart';
import 'package:test/test.dart';

void main() {
  group('FlavorConfig', () {
    test('creates instance with required fields', () {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      expect(config.name, equals('dev'));
      expect(config.bundleId, equals('com.example.dev'));
      expect(config.appName, equals('App Dev'));
    });

    test('creates instance with all fields', () {
      const provisioning = ProvisioningConfig(
        androidGoogleServicesPath: 'configs/dev/google-services.json',
        iosGoogleServicePath: 'configs/dev/GoogleService-Info.plist',
      );

      const config = FlavorConfig(
        name: 'production',
        bundleId: 'com.example.app',
        appName: 'My App',
        iconPath: 'assets/icons/prod',
        metadata: {'API_URL': 'https://api.example.com'},
        assets: ['assets/prod/'],
        dependencies: {'firebase_core': '^2.0.0'},
        provisioning: provisioning,
        androidMinSdkVersion: 21,
        androidTargetSdkVersion: 33,
        iosMinVersion: '12.0',
      );

      expect(config.name, equals('production'));
      expect(config.metadata['API_URL'], equals('https://api.example.com'));
      expect(config.assets.length, equals(1));
      expect(config.provisioning, equals(provisioning));
    });

    test('creates from YAML map', () {
      final yaml = {
        'bundle_id': 'com.example.staging',
        'app_name': 'App Staging',
        'icon_path': 'assets/icons/staging',
        'metadata': {
          'API_URL': 'https://staging-api.example.com',
          'ENABLE_LOGGING': true,
        },
        'assets': ['assets/staging/'],
        'android_min_sdk_version': 21,
        'ios_min_version': '13.0',
      };

      final config = FlavorConfig.fromYaml('staging', yaml);

      expect(config.name, equals('staging'));
      expect(config.bundleId, equals('com.example.staging'));
      expect(config.appName, equals('App Staging'));
      expect(config.iconPath, equals('assets/icons/staging'));
      expect(
        config.metadata['API_URL'],
        equals('https://staging-api.example.com'),
      );
      expect(config.androidMinSdkVersion, equals(21));
      expect(config.iosMinVersion, equals('13.0'));
    });

    test('converts to YAML map', () {
      const config = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
        metadata: {'API_URL': 'https://dev-api.example.com'},
      );

      final yaml = config.toYaml();

      expect(yaml['bundle_id'], equals('com.example.dev'));
      expect(yaml['app_name'], equals('App Dev'));
      expect(
        yaml['metadata'],
        equals({'API_URL': 'https://dev-api.example.com'}),
      );
    });

    test('equality works correctly', () {
      const config1 = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      const config2 = FlavorConfig(
        name: 'dev',
        bundleId: 'com.example.dev',
        appName: 'App Dev',
      );

      const config3 = FlavorConfig(
        name: 'prod',
        bundleId: 'com.example.prod',
        appName: 'App Prod',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });

  group('ProvisioningConfig', () {
    test('creates instance with fields', () {
      const config = ProvisioningConfig(
        androidGoogleServicesPath: 'path/to/google-services.json',
        iosGoogleServicePath: 'path/to/GoogleService-Info.plist',
      );

      expect(
        config.androidGoogleServicesPath,
        equals('path/to/google-services.json'),
      );
      expect(
        config.iosGoogleServicePath,
        equals('path/to/GoogleService-Info.plist'),
      );
    });

    test('creates from YAML map', () {
      final yaml = {
        'android_google_services': 'configs/google-services.json',
        'ios_google_service': 'configs/GoogleService-Info.plist',
        'additional_files': {
          'android/file.xml': 'configs/file.xml',
        },
      };

      final config = ProvisioningConfig.fromYaml(yaml);

      expect(
        config.androidGoogleServicesPath,
        equals('configs/google-services.json'),
      );
      expect(
        config.iosGoogleServicePath,
        equals('configs/GoogleService-Info.plist'),
      );
      expect(config.additionalFiles.length, equals(1));
    });

    test('converts to YAML map', () {
      const config = ProvisioningConfig(
        androidGoogleServicesPath: 'path/android.json',
        iosGoogleServicePath: 'path/ios.plist',
      );

      final yaml = config.toYaml();

      expect(yaml['android_google_services'], equals('path/android.json'));
      expect(yaml['ios_google_service'], equals('path/ios.plist'));
    });

    test('equality works correctly', () {
      const config1 = ProvisioningConfig(
        androidGoogleServicesPath: 'path1',
        iosGoogleServicePath: 'path2',
      );

      const config2 = ProvisioningConfig(
        androidGoogleServicesPath: 'path1',
        iosGoogleServicePath: 'path2',
      );

      const config3 = ProvisioningConfig(
        androidGoogleServicesPath: 'path3',
        iosGoogleServicePath: 'path4',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });
}
