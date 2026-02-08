/// Provisioning configuration model for Firebase and platform-specific
/// services.
///
/// This class holds the configuration for platform-specific provisioning files
/// such as Firebase configuration files (google-services.json for Android and
/// GoogleService-Info.plist for iOS).
final class ProvisioningConfig {
  /// Creates a new [ProvisioningConfig] instance.
  ///
  /// [androidGoogleServicesPath] is the path to the google-services.json file.
  /// [iosGoogleServicePath] is the path to the GoogleService-Info.plist file.
  const ProvisioningConfig({
    this.androidGoogleServicesPath,
    this.iosGoogleServicePath,
    this.additionalFiles = const {},
  });

  /// Creates a [ProvisioningConfig] from a YAML map.
  factory ProvisioningConfig.fromYaml(Map<dynamic, dynamic> yaml) =>
      ProvisioningConfig(
        androidGoogleServicesPath: yaml['android_google_services'] as String?,
        iosGoogleServicePath: yaml['ios_google_service'] as String?,
        additionalFiles: yaml['additional_files'] != null
            ? Map<String, String>.from(
                yaml['additional_files'] as Map<dynamic, dynamic>,
              )
            : const {},
      );

  /// Path to the Android google-services.json file.
  final String? androidGoogleServicesPath;

  /// Path to the iOS GoogleService-Info.plist file.
  final String? iosGoogleServicePath;

  /// Additional platform-specific files to copy.
  ///
  /// The key is the destination path (relative to platform root),
  /// and the value is the source file path.
  final Map<String, String> additionalFiles;

  /// Converts this config to a YAML-compatible map.
  Map<String, dynamic> toYaml() => {
        if (androidGoogleServicesPath != null)
          'android_google_services': androidGoogleServicesPath,
        if (iosGoogleServicePath != null)
          'ios_google_service': iosGoogleServicePath,
        if (additionalFiles.isNotEmpty) 'additional_files': additionalFiles,
      };

  @override
  String toString() => 'ProvisioningConfig('
      'androidGoogleServicesPath: $androidGoogleServicesPath, '
      'iosGoogleServicePath: $iosGoogleServicePath, '
      'additionalFiles: $additionalFiles)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ProvisioningConfig &&
        other.androidGoogleServicesPath == androidGoogleServicesPath &&
        other.iosGoogleServicePath == iosGoogleServicePath &&
        _mapsEqual(other.additionalFiles, additionalFiles);
  }

  @override
  int get hashCode => Object.hash(
        androidGoogleServicesPath,
        iosGoogleServicePath,
        Object.hashAll(additionalFiles.entries),
      );

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }
}
