import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import '../models/flavor_config.dart';
import '../utils/file_manager.dart';
import '../utils/logger.dart';

/// Processor for Android platform-specific configurations.
///
/// Handles manipulation of Android native files including AndroidManifest.xml,
/// build.gradle/build.gradle.kts, and provisioning files like google-services.json.
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

    final manifestContent = await fileManager.readFile(manifestPath);
    final document = XmlDocument.parse(manifestContent);

    // Update package name and application label (app name)
    final manifest = document.findElements('manifest').first
      ..setAttribute('package', config.bundleId);

    final application = manifest.findElements('application').firstOrNull;
    if (application != null) {
      application.setAttribute('android:label', config.appName);
    }

    logger
      ..debug('Updated package name to: ${config.bundleId}')
      ..debug('Updated app name to: ${config.appName}');

    if (application != null) {
      // Add or update metadata entries
      if (config.metadata.isNotEmpty) {
        await _addMetadataToManifest(application, config.metadata);
      }
    }

    // Write updated manifest
    await fileManager.writeFile(
      manifestPath,
      document.toXmlString(pretty: true, indent: '    '),
    );

    logger.success('AndroidManifest.xml updated');
  }

  /// Adds metadata entries to the application element.
  Future<void> _addMetadataToManifest(
    XmlElement application,
    Map<String, dynamic> metadata,
  ) async {
    logger.debug('Adding metadata entries to AndroidManifest.xml...');

    for (final entry in metadata.entries) {
      final key = entry.key;
      final value = entry.value.toString();

      // Check if metadata already exists
      final existingMetadata = application.findElements('meta-data').where(
            (element) => element.getAttribute('android:name') == key,
          );

      if (existingMetadata.isNotEmpty) {
        // Update existing metadata
        for (final element in existingMetadata) {
          element.setAttribute('android:value', value);
        }
        logger.debug('Updated metadata: $key = $value');
      } else {
        // Add new metadata
        final metadataElement = XmlElement(
          XmlName('meta-data'),
          [
            XmlAttribute(XmlName('android:name'), key),
            XmlAttribute(XmlName('android:value'), value),
          ],
        );
        application.children.add(metadataElement);
        logger.debug('Added metadata: $key = $value');
      }
    }
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
    final groovyRegex = RegExp(r'minSdkVersion\s+\d+');
    final kotlinAssignRegex = RegExp(r'minSdk\s*=\s*\d+');
    final kotlinFunctionRegex = RegExp(r'minSdkVersion\s*\(\s*\d+\s*\)');

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
    } else {
      // Groovy syntax
      if (groovyRegex.hasMatch(content)) {
        return content.replaceFirst(groovyRegex, 'minSdkVersion $version');
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
    final groovyRegex = RegExp(r'targetSdkVersion\s+\d+');
    final kotlinAssignRegex = RegExp(r'targetSdk\s*=\s*\d+');
    final kotlinFunctionRegex = RegExp(r'targetSdkVersion\s*\(\s*\d+\s*\)');

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
    } else {
      // Groovy syntax
      if (groovyRegex.hasMatch(content)) {
        return content.replaceFirst(groovyRegex, 'targetSdkVersion $version');
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
    final groovyRegex = RegExp(r'compileSdkVersion\s+\d+');
    final groovyAltRegex = RegExp(r'compileSdk\s+\d+');
    final kotlinAssignRegex = RegExp(r'compileSdk\s*=\s*\d+');
    final kotlinFunctionRegex = RegExp(r'compileSdkVersion\s*\(\s*\d+\s*\)');

    if (isKotlinScript) {
      // Try Kotlin assignment syntax first
      if (kotlinAssignRegex.hasMatch(content)) {
        return content.replaceFirst(kotlinAssignRegex, 'compileSdk = $version');
      }
      // Try Kotlin function syntax
      if (kotlinFunctionRegex.hasMatch(content)) {
        return content.replaceFirst(
          kotlinFunctionRegex,
          'compileSdkVersion($version)',
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
    }

    logger.warning('Could not update compileSdkVersion in build gradle file');
    return content;
  }

  /// Adds custom Gradle configuration snippets.
  String _addCustomGradleConfig(
    String content,
    Map<String, String> customConfig,
  ) {
    logger.debug('Adding custom Gradle configuration...');

    var updatedContent = content;

    for (final entry in customConfig.entries) {
      final section = entry.key;
      final config = entry.value;

      logger.debug('Adding config to section: $section');

      // Find the section and add configuration
      final sectionRegex = RegExp('$section\\s*\\{');
      if (sectionRegex.hasMatch(updatedContent)) {
        updatedContent = updatedContent.replaceFirst(
          sectionRegex,
          '$section {\n        $config',
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
