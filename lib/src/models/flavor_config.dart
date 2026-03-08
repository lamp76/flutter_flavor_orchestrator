import 'provisioning_config.dart';

/// Complete flavor configuration model.
///
/// This class represents a complete flavor configuration including all
/// platform-specific settings, assets, metadata, and provisioning information.
final class FlavorConfig {
  /// Creates a new [FlavorConfig] instance.
  ///
  /// [name] is the flavor name (e.g., 'dev', 'staging', 'production').
  /// [bundleId] is the bundle identifier for iOS and package name for Android.
  /// [appName] is the display name of the application.
  const FlavorConfig({
    required this.name,
    required this.bundleId,
    required this.appName,
    this.iconPath,
    this.metadata = const {},
    this.assets = const [],
    this.dependencies = const {},
    this.provisioning,
    this.androidMinSdkVersion,
    this.androidTargetSdkVersion,
    this.androidCompileSdkVersion,
    this.iosMinVersion,
    this.customGradleConfig,
    this.customInfoPlistEntries = const {},
    this.fileMappings = const {},
    this.replaceDestinationDirectories = false,
  });

  /// Creates a [FlavorConfig] from a YAML map.
  factory FlavorConfig.fromYaml(String name, Map<dynamic, dynamic> yaml) =>
      FlavorConfig(
        name: name,
        bundleId: yaml['bundle_id'] as String? ?? '',
        appName: yaml['app_name'] as String? ?? '',
        iconPath: yaml['icon_path'] as String?,
        metadata: yaml['metadata'] != null
            ? Map<String, dynamic>.from(
                yaml['metadata'] as Map<dynamic, dynamic>,
              )
            : const {},
        assets: yaml['assets'] != null
            ? List<String>.from(yaml['assets'] as List<dynamic>)
            : const [],
        dependencies: yaml['dependencies'] != null
            ? Map<String, String>.from(
                yaml['dependencies'] as Map<dynamic, dynamic>,
              )
            : const {},
        provisioning: yaml['provisioning'] != null
            ? ProvisioningConfig.fromYaml(
                yaml['provisioning'] as Map<dynamic, dynamic>,
              )
            : null,
        androidMinSdkVersion: yaml['android_min_sdk_version'] as int?,
        androidTargetSdkVersion: yaml['android_target_sdk_version'] as int?,
        androidCompileSdkVersion: yaml['android_compile_sdk_version'] as int?,
        iosMinVersion: yaml['ios_min_version'] as String?,
        customGradleConfig: yaml['custom_gradle_config'] != null
            ? Map<String, String>.from(
                yaml['custom_gradle_config'] as Map<dynamic, dynamic>,
              )
            : null,
        customInfoPlistEntries: yaml['custom_info_plist_entries'] != null
            ? Map<String, dynamic>.from(
                yaml['custom_info_plist_entries'] as Map<dynamic, dynamic>,
              )
            : const <String, dynamic>{},
        fileMappings: yaml['file_mappings'] != null
            ? Map<String, String>.from(
                yaml['file_mappings'] as Map<dynamic, dynamic>,
              )
            : const {},
        replaceDestinationDirectories:
            yaml['replace_destination_directories'] as bool? ?? false,
      );

  /// The flavor name (e.g., 'dev', 'staging', 'production').
  final String name;

  /// Bundle identifier (iOS) / Package name (Android).
  final String bundleId;

  /// Application display name.
  final String appName;

  /// Path to the icon file or directory.
  final String? iconPath;

  /// Custom metadata to inject into platform manifests.
  ///
  /// For Android, these will be added as `<meta-data>` entries in
  /// AndroidManifest.xml.
  /// For iOS, these will be added to Info.plist.
  final Map<String, dynamic> metadata;

  /// List of asset paths to include for this flavor.
  final List<String> assets;

  /// Dependencies to add or override for this flavor.
  ///
  /// The key is the dependency name, and the value is the version constraint.
  final Map<String, String> dependencies;

  /// Provisioning configuration (Firebase, etc.).
  final ProvisioningConfig? provisioning;

  /// Android minimum SDK version.
  final int? androidMinSdkVersion;

  /// Android target SDK version.
  final int? androidTargetSdkVersion;

  /// Android compile SDK version.
  final int? androidCompileSdkVersion;

  /// iOS minimum deployment target version.
  final String? iosMinVersion;

  /// Custom Gradle configuration snippets to inject.
  final Map<String, String>? customGradleConfig;

  /// Custom Info.plist entries to inject for iOS.
  final Map<String, dynamic> customInfoPlistEntries;

  /// File and folder mappings for flavor-specific asset copying.
  ///
  /// The key is the destination path (relative to project root), and the value
  /// is the source path (relative to project root). Supports both individual
  /// files and recursive directory copying.
  ///
  /// Example:
  /// ```yaml
  /// file_mappings:
  ///   'android/app/src/main/res/mipmap-hdpi': 'assets/dev/icons/hdpi'
  ///   'ios/Runner/Assets.xcassets/AppIcon.appiconset': 'assets/dev/icons/ios'
  ///   'lib/config/api_config.dart': 'configs/dev/api_config.dart'
  /// ```
  final Map<String, String> fileMappings;

  /// Whether to replace destination directories completely.
  ///
  /// When true, if a destination directory already exists for a directory
  /// mapping in [fileMappings], it will be safely replaced:
  /// 1. The existing directory is temporarily renamed
  /// 2. The new directory tree is copied
  /// 3. On success, the old directory is removed
  /// 4. On failure, the old directory is restored
  ///
  /// This ensures atomic directory replacement with automatic rollback.
  /// Only affects directory mappings, not individual file mappings.
  final bool replaceDestinationDirectories;

  /// Converts this config to a YAML-compatible map.
  Map<String, dynamic> toYaml() => {
        'bundle_id': bundleId,
        'app_name': appName,
        if (iconPath != null) 'icon_path': iconPath,
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (assets.isNotEmpty) 'assets': assets,
        if (dependencies.isNotEmpty) 'dependencies': dependencies,
        if (provisioning != null) 'provisioning': provisioning!.toYaml(),
        if (androidMinSdkVersion != null)
          'android_min_sdk_version': androidMinSdkVersion,
        if (androidTargetSdkVersion != null)
          'android_target_sdk_version': androidTargetSdkVersion,
        if (androidCompileSdkVersion != null)
          'android_compile_sdk_version': androidCompileSdkVersion,
        if (iosMinVersion != null) 'ios_min_version': iosMinVersion,
        if (customGradleConfig != null)
          'custom_gradle_config': customGradleConfig,
        if (customInfoPlistEntries.isNotEmpty)
          'custom_info_plist_entries': customInfoPlistEntries,
        if (fileMappings.isNotEmpty) 'file_mappings': fileMappings,
        if (replaceDestinationDirectories)
          'replace_destination_directories': replaceDestinationDirectories,
      };

  /// Serialises this config to a JSON-compatible map with stable top-level
  /// keys.
  Map<String, Object?> toJson() => {
        'name': name,
        'bundle_id': bundleId,
        'app_name': appName,
        if (iconPath != null) 'icon_path': iconPath,
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (assets.isNotEmpty) 'assets': assets,
        if (dependencies.isNotEmpty) 'dependencies': dependencies,
        if (provisioning != null) 'provisioning': provisioning!.toJson(),
        if (androidMinSdkVersion != null)
          'android_min_sdk_version': androidMinSdkVersion,
        if (androidTargetSdkVersion != null)
          'android_target_sdk_version': androidTargetSdkVersion,
        if (androidCompileSdkVersion != null)
          'android_compile_sdk_version': androidCompileSdkVersion,
        if (iosMinVersion != null) 'ios_min_version': iosMinVersion,
        if (customGradleConfig != null)
          'custom_gradle_config': customGradleConfig,
        if (customInfoPlistEntries.isNotEmpty)
          'custom_info_plist_entries': customInfoPlistEntries,
        'file_mappings': fileMappings,
        'file_mappings_count': fileMappings.length,
        'replace_destination_directories': replaceDestinationDirectories,
      };

  @override
  String toString() => 'FlavorConfig('
      'name: $name, '
      'bundleId: $bundleId, '
      'appName: $appName, '
      'iconPath: $iconPath)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is FlavorConfig &&
        other.name == name &&
        other.bundleId == bundleId &&
        other.appName == appName &&
        other.iconPath == iconPath;
  }

  @override
  int get hashCode => Object.hash(
        name,
        bundleId,
        appName,
        iconPath,
      );
}
