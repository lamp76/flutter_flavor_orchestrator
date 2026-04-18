import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/flavor_config.dart';
import '../utils/file_manager.dart';
import '../utils/logger.dart';

/// Processor for Android platform-specific configurations.
///
/// Handles manipulation of Android native files including AndroidManifest.xml,
/// build.gradle/build.gradle.kts, and provisioning files like
/// google-services.json.
final class AndroidProcessor {
  /// Creates a new [AndroidProcessor] instance.
  ///
  /// [fileManager] handles file operations.
  /// [logger] is used for logging operations and errors.
  AndroidProcessor({
    required this.fileManager,
    required this.logger,
  });

  /// File manager instance for file operations.
  final FileManager fileManager;

  /// Logger instance for output.
  final Logger logger;

  /// Processes Android configuration for the given flavor.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [config] is the flavor configuration to apply.
  ///
  /// Throws [FileSystemException] if required files don't exist.
  Future<void> process(String projectRoot, FlavorConfig config) async {
    logger
      ..section('Processing Android Configuration')
      ..info('Applying flavor: ${config.name}');

    final androidPath = path.join(projectRoot, 'android');

    // Verify android directory exists
    if (!await fileManager.directoryExists(androidPath)) {
      throw FileSystemException(
        'Android directory not found',
        androidPath,
      );
    }

    // Process AndroidManifest.xml
    await _processAndroidManifest(androidPath, config);

    // Process build.gradle
    await _processBuildGradle(androidPath, config);

    // Process google-services.json if configured
    if (config.provisioning?.androidGoogleServicesPath != null) {
      await _processGoogleServices(projectRoot, androidPath, config);
    }

    logger.success('Android configuration applied successfully');
  }

  /// Processes AndroidManifest.xml file.
  Future<void> _processAndroidManifest(
    String androidPath,
    FlavorConfig config,
  ) async {
    logger.info('Processing AndroidManifest.xml...');

    final manifestPath = path.join(
      androidPath,
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    );

    if (!await fileManager.fileExists(manifestPath)) {
      logger.warning('AndroidManifest.xml not found at: $manifestPath');
      return;
    }

    var manifestContent = await fileManager.readFile(manifestPath);

    // Update package name using string replacement to preserve formatting
    manifestContent = _updateManifestPackage(manifestContent, config.bundleId);

    // Update app name using string replacement to preserve formatting
    manifestContent = _updateManifestAppName(manifestContent, config.appName);

    logger
      ..debug('Updated package name to: ${config.bundleId}')
      ..debug('Updated app name to: ${config.appName}');

    // Add or update metadata entries
    if (config.metadata.isNotEmpty) {
      manifestContent =
          _addMetadataToManifest(manifestContent, config.metadata);
    }

    // Write updated manifest
    await fileManager.writeFile(manifestPath, manifestContent);

    logger.success('AndroidManifest.xml updated');
  }

  /// Updates the package attribute in the manifest element.
  String _updateManifestPackage(String content, String bundleId) {
    // Match package attribute in manifest tag with any whitespace
    final packageRegex = RegExp(
      r'(<manifest[^>]*?\s+package\s*=\s*")[^"]*(")',
      multiLine: true,
      dotAll: true,
    );

    if (packageRegex.hasMatch(content)) {
      return content.replaceFirstMapped(
        packageRegex,
        (match) => '${match.group(1)}$bundleId${match.group(2)}',
      );
    }

    // If package attribute doesn't exist, try to add it
    final manifestRegex = RegExp('<manifest([^>]*)>');
    if (manifestRegex.hasMatch(content)) {
      logger.warning('Package attribute not found, adding it to manifest');
      return content.replaceFirstMapped(
        manifestRegex,
        (match) => '<manifest${match.group(1)} package="$bundleId">',
      );
    }

    logger.warning('Could not update package name in AndroidManifest.xml');
    return content;
  }

  /// Updates the android:label attribute in the application element.
  String _updateManifestAppName(String content, String appName) {
    // Match android:label attribute in application tag
    // with any whitespace
    final labelRegex = RegExp(
      r'(<application[^>]*?\s+android:label\s*=\s*")[^"]*(")',
      multiLine: true,
      dotAll: true,
    );

    if (labelRegex.hasMatch(content)) {
      return content.replaceFirstMapped(
        labelRegex,
        (match) => '${match.group(1)}$appName${match.group(2)}',
      );
    }

    // If android:label doesn't exist, try to add it
    final applicationRegex = RegExp('<application([^>]*)>');
    if (applicationRegex.hasMatch(content)) {
      logger.warning('android:label not found, adding it to application');
      return content.replaceFirstMapped(
        applicationRegex,
        (match) => '<application${match.group(1)} android:label="$appName">',
      );
    }

    logger.warning('Could not update app name in AndroidManifest.xml');
    return content;
  }

  /// Adds metadata entries to the application element.
  String _addMetadataToManifest(
    String content,
    Map<String, dynamic> metadata,
  ) {
    logger.debug('Adding metadata entries to AndroidManifest.xml...');

    var updatedContent = content;

    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value.toString();

      // Detect indentation by finding the application tag and its children
      final indent = _detectMetadataIndentation(updatedContent);

      // Check if metadata already exists
      final metadataRegex = RegExp(
        r'<meta-data\s+android:name\s*=\s*"' +
            RegExp.escape(key) +
            r'"[^>]*android:value\s*=\s*"[^"]*"[^>]*/>',
        multiLine: true,
      );

      // Alternative pattern where value comes before name
      final metadataRegexAlt = RegExp(
        '<meta-data\\s+android:value\\s*=\\s*"[^"]*"[^>]*'
        'android:name\\s*=\\s*"${RegExp.escape(key)}"[^>]*/>',
        multiLine: true,
      );

      if (metadataRegex.hasMatch(updatedContent)) {
        // Update existing metadata
        updatedContent = updatedContent.replaceFirst(
          metadataRegex,
          '<meta-data android:name="$key" android:value="$value" />',
        );
        logger.debug('Updated metadata: $key = $value');
      } else if (metadataRegexAlt.hasMatch(updatedContent)) {
        // Update existing metadata (alternative pattern)
        updatedContent = updatedContent.replaceFirst(
          metadataRegexAlt,
          '<meta-data android:name="$key" android:value="$value" />',
        );
        logger.debug('Updated metadata: $key = $value');
      } else {
        // Add new metadata before closing application tag
        final applicationEndRegex = RegExp(r'([ \t]*)</application>');
        if (applicationEndRegex.hasMatch(updatedContent)) {
          final newMetadata = '$indent<meta-data android:name="$key" '
              'android:value="$value" />\n';
          updatedContent = updatedContent.replaceFirstMapped(
            applicationEndRegex,
            (match) => '$newMetadata${match.group(1)}</application>',
          );
          logger.debug('Added metadata: $key = $value');
        } else {
          logger.warning('Could not add metadata: $key');
        }
      }
    }

    return updatedContent;
  }

  /// Detects the indentation used for children of the application element.
  String _detectMetadataIndentation(String content) {
    // Try to find existing meta-data or activity indentation
    final metadataMatch = RegExp(r'\n([ \t]+)<meta-data').firstMatch(content);
    if (metadataMatch != null) {
      return metadataMatch.group(1)!;
    }

    final activityMatch = RegExp(r'\n([ \t]+)<activity').firstMatch(content);
    if (activityMatch != null) {
      return activityMatch.group(1)!;
    }

    // Try to find application tag and add default indentation
    final applicationMatch =
        RegExp(r'\n([ \t]*)<application').firstMatch(content);
    if (applicationMatch != null) {
      final baseIndent = applicationMatch.group(1)!;
      // Add one level of indentation (assuming 4 spaces or 1 tab)
      if (baseIndent.contains('\t')) {
        return '$baseIndent\t';
      } else {
        return '$baseIndent    '; // 4 spaces
      }
    }

    // Default to 8 spaces if nothing found
    return '        ';
  }

  /// Processes build.gradle or build.gradle.kts file to add flavor
  /// configuration.
  Future<void> _processBuildGradle(
    String androidPath,
    FlavorConfig config,
  ) async {
    logger.info('Processing build.gradle...');

    // Check for both .gradle and .gradle.kts files
    final buildGradlePath = path.join(androidPath, 'app', 'build.gradle');
    final buildGradleKtsPath =
        path.join(androidPath, 'app', 'build.gradle.kts');

    String? gradleFilePath;
    var isKotlinScript = false;

    if (await fileManager.fileExists(buildGradleKtsPath)) {
      gradleFilePath = buildGradleKtsPath;
      isKotlinScript = true;
      logger.debug('Found build.gradle.kts (Kotlin script)');
    } else if (await fileManager.fileExists(buildGradlePath)) {
      gradleFilePath = buildGradlePath;
      logger.debug('Found build.gradle (Groovy script)');
    } else {
      logger.warning('Neither build.gradle nor build.gradle.kts found');
      return;
    }

    var gradleContent = await fileManager.readFile(gradleFilePath);

    // Update applicationId in defaultConfig
    gradleContent = _updateApplicationId(
      gradleContent,
      config.bundleId,
      isKotlinScript,
    );

    // Update SDK versions if configured
    if (config.androidMinSdkVersion != null) {
      gradleContent = _updateMinSdkVersion(
        gradleContent,
        config.androidMinSdkVersion!,
        isKotlinScript,
      );
    }

    if (config.androidTargetSdkVersion != null) {
      gradleContent = _updateTargetSdkVersion(
        gradleContent,
        config.androidTargetSdkVersion!,
        isKotlinScript,
      );
    }

    if (config.androidCompileSdkVersion != null) {
      gradleContent = _updateCompileSdkVersion(
        gradleContent,
        config.androidCompileSdkVersion!,
        isKotlinScript,
      );
    }

    // Add custom gradle config if provided
    if (config.customGradleConfig != null &&
        config.customGradleConfig!.isNotEmpty) {
      gradleContent = _addCustomGradleConfig(
        gradleContent,
        config.customGradleConfig!,
      );
    }

    await fileManager.writeFile(gradleFilePath, gradleContent);
    logger.success(
      '${isKotlinScript ? 'build.gradle.kts' : 'build.gradle'} updated',
    );
  }

  /// Updates the applicationId in build.gradle or build.gradle.kts.
  String _updateApplicationId(
    String content,
    String bundleId,
    bool isKotlinScript,
  ) {
    logger.debug('Updating applicationId to: $bundleId');

    // Regex patterns for both Groovy ("value") and Kotlin
    // ("value" or = "value")
    final groovyRegex = RegExp(r'applicationId\s+"[^"]*"');
    final kotlinRegex = RegExp(r'applicationId\s*=?\s*"[^"]*"');

    final regex = isKotlinScript ? kotlinRegex : groovyRegex;
    final replacement = isKotlinScript
        ? 'applicationId = "$bundleId"'
        : 'applicationId "$bundleId"';

    if (regex.hasMatch(content)) {
      return content.replaceFirst(regex, replacement);
    }

    // If applicationId not found, try to add it to defaultConfig
    final defaultConfigRegex = RegExp(r'defaultConfig\s*\{');
    if (defaultConfigRegex.hasMatch(content)) {
      final indent = isKotlinScript ? '        ' : '        ';
      return content.replaceFirst(
        defaultConfigRegex,
        'defaultConfig {\n$indent$replacement',
      );
    }

    logger.warning('Could not update applicationId in build gradle file');
    return content;
  }

  /// Updates the minSdkVersion in build.gradle or build.gradle.kts.
  String _updateMinSdkVersion(
    String content,
    int version,
    bool isKotlinScript,
  ) {
    logger.debug('Updating minSdkVersion to: $version');

    // Groovy: minSdkVersion 21, Kotlin: minSdk = 21 or minSdkVersion(21)
    // Also handles flutter.minSdkVersion or other variable references
    final groovyRegex = RegExp(r'minSdkVersion\s+[\w.]+');
    final kotlinAssignRegex = RegExp(r'minSdk\s*=\s*[\w.]+');
    final kotlinFunctionRegex = RegExp(r'minSdkVersion\s*\([^)]+\)');

    if (isKotlinScript) {
      // Try Kotlin assignment syntax first
      if (kotlinAssignRegex.hasMatch(content)) {
        return content.replaceFirst(kotlinAssignRegex, 'minSdk = $version');
      }
      // Try Kotlin function syntax
      if (kotlinFunctionRegex.hasMatch(content)) {
        return content.replaceFirst(
          kotlinFunctionRegex,
          'minSdkVersion($version)',
        );
      }
      // If not found, try to add it to defaultConfig
      final defaultConfigRegex = RegExp(r'defaultConfig\s*\{');
      if (defaultConfigRegex.hasMatch(content)) {
        logger.debug('Adding minSdk to defaultConfig');
        return content.replaceFirst(
          defaultConfigRegex,
          'defaultConfig {\n        minSdk = $version',
        );
      }
    } else {
      // Groovy syntax
      if (groovyRegex.hasMatch(content)) {
        return content.replaceFirst(groovyRegex, 'minSdkVersion $version');
      }
      // If not found, try to add it to defaultConfig
      final defaultConfigRegex = RegExp(r'defaultConfig\s*\{');
      if (defaultConfigRegex.hasMatch(content)) {
        logger.debug('Adding minSdkVersion to defaultConfig');
        return content.replaceFirst(
          defaultConfigRegex,
          'defaultConfig {\n        minSdkVersion $version',
        );
      }
    }

    logger.warning('Could not update minSdkVersion in build gradle file');
    return content;
  }

  /// Updates the targetSdkVersion in build.gradle or build.gradle.kts.
  String _updateTargetSdkVersion(
    String content,
    int version,
    bool isKotlinScript,
  ) {
    logger.debug('Updating targetSdkVersion to: $version');

    // Groovy: targetSdkVersion 33, Kotlin: targetSdk = 33 or
    // targetSdkVersion(33)
    // Also handles flutter.targetSdkVersion or other variable references
    final groovyRegex = RegExp(r'targetSdkVersion\s+[\w.]+');
    final kotlinAssignRegex = RegExp(r'targetSdk\s*=\s*[\w.]+');
    final kotlinFunctionRegex = RegExp(r'targetSdkVersion\s*\([^)]+\)');

    if (isKotlinScript) {
      // Try Kotlin assignment syntax first
      if (kotlinAssignRegex.hasMatch(content)) {
        return content.replaceFirst(kotlinAssignRegex, 'targetSdk = $version');
      }
      // Try Kotlin function syntax
      if (kotlinFunctionRegex.hasMatch(content)) {
        return content.replaceFirst(
          kotlinFunctionRegex,
          'targetSdkVersion($version)',
        );
      }
      // If not found, try to add it to defaultConfig
      final defaultConfigRegex = RegExp(r'defaultConfig\s*\{');
      if (defaultConfigRegex.hasMatch(content)) {
        logger.debug('Adding targetSdk to defaultConfig');
        return content.replaceFirst(
          defaultConfigRegex,
          'defaultConfig {\n        targetSdk = $version',
        );
      }
    } else {
      // Groovy syntax
      if (groovyRegex.hasMatch(content)) {
        return content.replaceFirst(groovyRegex, 'targetSdkVersion $version');
      }
      // If not found, try to add it to defaultConfig
      final defaultConfigRegex = RegExp(r'defaultConfig\s*\{');
      if (defaultConfigRegex.hasMatch(content)) {
        logger.debug('Adding targetSdkVersion to defaultConfig');
        return content.replaceFirst(
          defaultConfigRegex,
          'defaultConfig {\n        targetSdkVersion $version',
        );
      }
    }

    logger.warning('Could not update targetSdkVersion in build gradle file');
    return content;
  }

  /// Updates the compileSdkVersion in build.gradle or build.gradle.kts.
  String _updateCompileSdkVersion(
    String content,
    int version,
    bool isKotlinScript,
  ) {
    logger.debug('Updating compileSdkVersion to: $version');

    // Groovy: compileSdkVersion 33 or compileSdk 33
    // Kotlin: compileSdk = 33 or compileSdkVersion(33)
    // Also handles flutter.compileSdkVersion or other variable references
    final groovyRegex = RegExp(r'compileSdkVersion\s+[\w.]+');
    final groovyAltRegex = RegExp(r'compileSdk\s+[\w.]+');
    final kotlinAssignRegex = RegExp(r'compileSdk\s*=\s*[\w.]+');
    final kotlinFunctionRegex = RegExp(r'compileSdkVersion\s*\([^)]+\)');

    if (isKotlinScript) {
      // Try Kotlin assignment syntax first
      if (kotlinAssignRegex.hasMatch(content)) {
        return content.replaceFirst(
          kotlinAssignRegex,
          'compileSdk = $version',
        );
      }
      // Try Kotlin function syntax
      if (kotlinFunctionRegex.hasMatch(content)) {
        return content.replaceFirst(
          kotlinFunctionRegex,
          'compileSdkVersion($version)',
        );
      }
      // If not found, try to add it to android block
      final androidBlockRegex = RegExp(r'android\s*\{');
      if (androidBlockRegex.hasMatch(content)) {
        logger.debug('Adding compileSdk to android block');
        return content.replaceFirst(
          androidBlockRegex,
          'android {\n    compileSdk = $version',
        );
      }
    } else {
      // Groovy syntax
      if (groovyRegex.hasMatch(content)) {
        return content.replaceFirst(groovyRegex, 'compileSdkVersion $version');
      }
      // Alternative Groovy format
      if (groovyAltRegex.hasMatch(content)) {
        return content.replaceFirst(groovyAltRegex, 'compileSdk $version');
      }
      // If not found, try to add it to android block
      final androidBlockRegex = RegExp(r'android\s*\{');
      if (androidBlockRegex.hasMatch(content)) {
        logger.debug('Adding compileSdkVersion to android block');
        return content.replaceFirst(
          androidBlockRegex,
          'android {\n    compileSdkVersion $version',
        );
      }
    }

    logger.warning('Could not update compileSdkVersion in build gradle file');
    return content;
  }

  /// Adds custom Gradle configuration snippets.
  String _addCustomGradleConfig(
    String content,
    Map<String, String> customConfig,
  ) {
    logger
      ..debug('Adding custom Gradle configuration...')
      ..warning(
        'Custom Gradle configuration is provided as raw code snippets. '
        'Ensure the syntax matches your build file type '
        '(Groovy vs Kotlin DSL).',
      );

    var updatedContent = content;

    for (final entry in customConfig.entries) {
      final section = entry.key;
      final config = entry.value.trim();

      logger.debug('Adding config to section: $section');

      // Ensure proper indentation by preserving existing indentation
      final sectionRegex = RegExp('$section\\s*\\{');
      final match = sectionRegex.firstMatch(updatedContent);

      if (match != null) {
        // Detect the indentation level after the opening brace
        final startPos = match.end;
        final afterBrace = updatedContent.substring(startPos);
        final nextLineMatch = RegExp(r'\n([ \t]+)').firstMatch(afterBrace);

        var indent = '        '; // Default 8 spaces
        if (nextLineMatch != null && nextLineMatch.group(1)!.isNotEmpty) {
          indent = nextLineMatch.group(1)!;
        }

        // Add proper indentation to each line of the config
        final indentedConfig = config
            .split(r'\n')
            .map((line) => line.trim().isEmpty ? '' : '$indent$line')
            .join(r'\n');

        updatedContent = updatedContent.replaceFirst(
          sectionRegex,
          '$section {\\n$indentedConfig\\n',
        );
      } else {
        logger.warning('Section "$section" not found in build.gradle');
      }
    }

    return updatedContent;
  }

  /// Processes google-services.json file.
  Future<void> _processGoogleServices(
    String projectRoot,
    String androidPath,
    FlavorConfig config,
  ) async {
    logger.info('Processing google-services.json...');

    final sourcePath = path.join(
      projectRoot,
      config.provisioning!.androidGoogleServicesPath,
    );

    if (!await fileManager.fileExists(sourcePath)) {
      logger.error('google-services.json not found at: $sourcePath');
      throw FileSystemException(
        'google-services.json file not found',
        sourcePath,
      );
    }

    final destinationPath = path.join(
      androidPath,
      'app',
      'google-services.json',
    );

    await fileManager.copyFile(sourcePath, destinationPath);
    logger.success('google-services.json copied successfully');
  }
}
