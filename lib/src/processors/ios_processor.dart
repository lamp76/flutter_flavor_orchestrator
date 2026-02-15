import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/flavor_config.dart';
import '../utils/file_manager.dart';
import '../utils/logger.dart';

/// Processor for iOS platform-specific configurations.
///
/// Handles manipulation of iOS native files including Info.plist,
/// project.pbxproj, and provisioning files like GoogleService-Info.plist.
final class IosProcessor {
  /// Creates a new [IosProcessor] instance.
  ///
  /// [fileManager] handles file operations.
  /// [logger] is used for logging operations and errors.
  IosProcessor({
    required this.fileManager,
    required this.logger,
  });

  /// File manager instance for file operations.
  final FileManager fileManager;

  /// Logger instance for output.
  final Logger logger;

  /// Processes iOS configuration for the given flavor.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [config] is the flavor configuration to apply.
  ///
  /// Throws [FileSystemException] if required files don't exist.
  Future<void> process(String projectRoot, FlavorConfig config) async {
    logger
      ..section('Processing iOS Configuration')
      ..info('Applying flavor: ${config.name}');

    final iosPath = path.join(projectRoot, 'ios');

    // Verify ios directory exists
    if (!await fileManager.directoryExists(iosPath)) {
      throw FileSystemException(
        'iOS directory not found',
        iosPath,
      );
    }

    // Process Info.plist
    await _processInfoPlist(iosPath, config);

    // Process project.pbxproj for bundle identifier
    await _processProjectPbxproj(iosPath, config);

    // Process GoogleService-Info.plist if configured
    if (config.provisioning?.iosGoogleServicePath != null) {
      await _processGoogleServiceInfo(projectRoot, iosPath, config);
    }

    logger.success('iOS configuration applied successfully');
  }

  /// Processes Info.plist file.
  Future<void> _processInfoPlist(String iosPath, FlavorConfig config) async {
    logger.info('Processing Info.plist...');

    final infoPlistPath = path.join(iosPath, 'Runner', 'Info.plist');

    if (!await fileManager.fileExists(infoPlistPath)) {
      logger.warning('Info.plist not found at: $infoPlistPath');
      return;
    }

    var plistContent = await fileManager.readFile(infoPlistPath);

    // Update CFBundleDisplayName (app name)
    plistContent = _updatePlistValue(
      plistContent,
      'CFBundleDisplayName',
      config.appName,
    );
    logger.debug('Updated CFBundleDisplayName to: ${config.appName}');

    // Update CFBundleIdentifier if not using variable
    if (!plistContent.contains(r'$(PRODUCT_BUNDLE_IDENTIFIER)')) {
      plistContent = _updatePlistValue(
        plistContent,
        'CFBundleIdentifier',
        config.bundleId,
      );
      logger.debug('Updated CFBundleIdentifier to: ${config.bundleId}');
    }

    // Update minimum iOS version if configured
    if (config.iosMinVersion != null) {
      plistContent = _updatePlistValue(
        plistContent,
        'MinimumOSVersion',
        config.iosMinVersion!,
      );
      logger.debug('Updated MinimumOSVersion to: ${config.iosMinVersion}');
    }

    // Add custom Info.plist entries
    if (config.customInfoPlistEntries.isNotEmpty) {
      plistContent = _addCustomPlistEntries(
        plistContent,
        config.customInfoPlistEntries,
      );
    }

    // Add metadata as custom entries
    if (config.metadata.isNotEmpty) {
      plistContent = _addCustomPlistEntries(plistContent, config.metadata);
    }

    await fileManager.writeFile(infoPlistPath, plistContent);
    logger.success('Info.plist updated');
  }

  /// Updates a value in the plist file.
  String _updatePlistValue(String content, String key, String value) {
    // Pattern to match the key and its value
    final keyPattern = '<key>$key</key>';
    final keyIndex = content.indexOf(keyPattern);

    if (keyIndex == -1) {
      // Key not found, add it before the closing </dict>
      final closingDictIndex = content.lastIndexOf('</dict>');
      if (closingDictIndex != -1) {
        final newEntry = '''
\t<key>$key</key>
\t<string>$value</string>
''';
        return content.substring(0, closingDictIndex) +
            newEntry +
            content.substring(closingDictIndex);
      }
      logger.warning('Could not add key "$key" to Info.plist');
      return content;
    }

    // Find the value tag after the key
    final afterKey = content.substring(keyIndex + keyPattern.length);
    final stringPattern = RegExp('<string>.*?</string>');
    final match = stringPattern.firstMatch(afterKey);

    if (match != null) {
      final newValue = '<string>$value</string>';
      return content.replaceFirst(
        keyPattern + afterKey.substring(0, match.end),
        '$keyPattern\n\t$newValue',
      );
    }

    logger.warning('Could not update key "$key" in Info.plist');
    return content;
  }

  /// Adds custom entries to Info.plist.
  String _addCustomPlistEntries(
    String content,
    Map<String, dynamic> entries,
  ) {
    logger.debug('Adding custom entries to Info.plist...');

    var updatedContent = content;

    for (final entry in entries.entries) {
      final key = entry.key;
      final value = entry.value;

      // Determine the value type and format
      String valueTag;
      if (value is bool) {
        valueTag = value ? '<true/>' : '<false/>';
      } else if (value is int || value is double) {
        valueTag = '<integer>$value</integer>';
      } else if (value is List) {
        valueTag = _formatPlistArray(value);
      } else if (value is Map) {
        valueTag = _formatPlistDict(value);
      } else {
        valueTag = '<string>$value</string>';
      }

      updatedContent = _updatePlistValueWithTag(updatedContent, key, valueTag);
      logger.debug('Added/Updated custom entry: $key');
    }

    return updatedContent;
  }

  /// Updates a plist value with a custom tag.
  String _updatePlistValueWithTag(String content, String key, String valueTag) {
    final keyPattern = '<key>$key</key>';
    final keyIndex = content.indexOf(keyPattern);

    if (keyIndex == -1) {
      // Key not found, add it
      final closingDictIndex = content.lastIndexOf('</dict>');
      if (closingDictIndex != -1) {
        final newEntry = '\t<key>$key</key>\n\t$valueTag\n';
        return content.substring(0, closingDictIndex) +
            newEntry +
            content.substring(closingDictIndex);
      }
      return content;
    }

    // Key exists, find and replace the value
    final afterKey = content.substring(keyIndex + keyPattern.length);

    // Match any plist value type after the key
    final valuePattern = RegExp(
      r'[\s\n]*(<string>.*?</string>|<integer>.*?</integer>|<real>.*?</real>|<true/>|<false/>|<data>.*?</data>|<date>.*?</date>|<array>.*?</array>|<dict>.*?</dict>)',
      multiLine: true,
      dotAll: true,
    );

    final match = valuePattern.firstMatch(afterKey);

    if (match != null) {
      final beforeValue = content.substring(0, keyIndex + keyPattern.length);
      final afterValue = content.substring(
        keyIndex + keyPattern.length + match.end,
      );

      return '$beforeValue\n\t$valueTag$afterValue';
    }

    return content;
  }

  /// Formats a list as a plist array.
  String _formatPlistArray(List<dynamic> list) {
    final buffer = StringBuffer('<array>\n');
    for (final item in list) {
      if (item is String) {
        buffer.writeln('\t\t<string>$item</string>');
      } else if (item is int || item is double) {
        buffer.writeln('\t\t<integer>$item</integer>');
      } else if (item is bool) {
        buffer.writeln(item ? '\t\t<true/>' : '\t\t<false/>');
      }
    }
    buffer.write('\t</array>');
    return buffer.toString();
  }

  /// Formats a map as a plist dictionary.
  String _formatPlistDict(Map<dynamic, dynamic> map) {
    final buffer = StringBuffer('<dict>\n');
    for (final entry in map.entries) {
      buffer.writeln('\t\t<key>${entry.key}</key>');
      if (entry.value is String) {
        buffer.writeln('\t\t<string>${entry.value}</string>');
      } else if (entry.value is int || entry.value is double) {
        buffer.writeln('\t\t<integer>${entry.value}</integer>');
      } else if (entry.value is bool) {
        buffer.writeln(
          entry.value as bool ? '\t\t<true/>' : '\t\t<false/>',
        );
      }
    }
    buffer.write('\t</dict>');
    return buffer.toString();
  }

  /// Processes project.pbxproj file to update bundle identifier.
  Future<void> _processProjectPbxproj(
    String iosPath,
    FlavorConfig config,
  ) async {
    logger.info('Processing project.pbxproj...');

    final pbxprojPath = path.join(
      iosPath,
      'Runner.xcodeproj',
      'project.pbxproj',
    );

    if (!await fileManager.fileExists(pbxprojPath)) {
      logger.warning('project.pbxproj not found at: $pbxprojPath');
      return;
    }

    var pbxprojContent = await fileManager.readFile(pbxprojPath);

    // Update PRODUCT_BUNDLE_IDENTIFIER
    pbxprojContent = _updateBundleIdentifier(pbxprojContent, config.bundleId);

    // Update PRODUCT_NAME if needed
    if (config.appName.isNotEmpty) {
      pbxprojContent = _updateProductName(pbxprojContent, config.appName);
    }

    // Update IPHONEOS_DEPLOYMENT_TARGET if configured
    if (config.iosMinVersion != null) {
      pbxprojContent = _updateDeploymentTarget(
        pbxprojContent,
        config.iosMinVersion!,
      );
    }

    await fileManager.writeFile(pbxprojPath, pbxprojContent);
    logger.success('project.pbxproj updated');
  }

  /// Updates PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj.
  String _updateBundleIdentifier(String content, String bundleId) {
    logger.debug('Updating PRODUCT_BUNDLE_IDENTIFIER to: $bundleId');

    final regex = RegExp(
      'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;',
      multiLine: true,
    );

    if (regex.hasMatch(content)) {
      return content.replaceAll(
        regex,
        'PRODUCT_BUNDLE_IDENTIFIER = $bundleId;',
      );
    }

    logger.warning('Could not update PRODUCT_BUNDLE_IDENTIFIER');
    return content;
  }

  /// Updates PRODUCT_NAME in project.pbxproj.
  String _updateProductName(String content, String productName) {
    logger.debug('Updating PRODUCT_NAME to: $productName');

    // Usually PRODUCT_NAME is set to $(TARGET_NAME), keep existing pattern
    final regex = RegExp(
      'PRODUCT_NAME = [^;]+;',
      multiLine: true,
    );

    if (regex.hasMatch(content)) {
      // Keep the existing pattern for now
      return content;
    }

    return content;
  }

  /// Updates IPHONEOS_DEPLOYMENT_TARGET in project.pbxproj.
  String _updateDeploymentTarget(String content, String version) {
    logger.debug('Updating IPHONEOS_DEPLOYMENT_TARGET to: $version');

    final regex = RegExp(
      'IPHONEOS_DEPLOYMENT_TARGET = [^;]+;',
      multiLine: true,
    );

    if (regex.hasMatch(content)) {
      return content.replaceAll(
        regex,
        'IPHONEOS_DEPLOYMENT_TARGET = $version;',
      );
    }

    logger.warning('Could not update IPHONEOS_DEPLOYMENT_TARGET');
    return content;
  }

  /// Processes GoogleService-Info.plist file.
  Future<void> _processGoogleServiceInfo(
    String projectRoot,
    String iosPath,
    FlavorConfig config,
  ) async {
    logger.info('Processing GoogleService-Info.plist...');

    final sourcePath =
        path.join(projectRoot, config.provisioning!.iosGoogleServicePath);

    if (!await fileManager.fileExists(sourcePath)) {
      logger.error('GoogleService-Info.plist not found at: $sourcePath');
      throw FileSystemException(
        'GoogleService-Info.plist file not found',
        sourcePath,
      );
    }

    final destinationPath = path.join(
      iosPath,
      'Runner',
      'GoogleService-Info.plist',
    );

    await fileManager.copyFile(sourcePath, destinationPath);
    logger.success('GoogleService-Info.plist copied successfully');
  }
}
