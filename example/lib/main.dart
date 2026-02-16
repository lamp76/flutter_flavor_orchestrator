import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Import flavor-specific theme and config files
// These files are copied by the flavor orchestrator when applying a flavor
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'theme/typography.dart' as app_typography;
import 'config/app_config.dart';

void main() {
  runApp(const MyApp());
}

/// Example Flutter app demonstrating flavor orchestrator usage.
class MyApp extends StatelessWidget {
  /// Creates the app widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the flavor-specific theme
    return MaterialApp(
      title: 'Flavor Orchestrator Example',
      debugShowCheckedModeBanner: AppTheme.showDebugBanner,
      theme: AppTheme.lightTheme,
      home: const MyHomePage(),
    );
  }
}

/// Home page widget displaying all flavor-specific resources.
class MyHomePage extends StatelessWidget {
  /// Creates the home page.
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Flavor: ${AppTheme.environmentLabel}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Icon Section
          _buildAppIconSection(),
          const SizedBox(height: 24),

          // Environment Info Section
          _buildEnvironmentSection(),
          const SizedBox(height: 24),

          // Colors Section
          _buildColorsSection(),
          const SizedBox(height: 24),

          // Typography Section
          _buildTypographySection(),
          const SizedBox(height: 24),

          // Configuration Section
          _buildConfigSection(),
        ],
      ),
    );
  }

  /// Builds the app icon display section.
  Widget _buildAppIconSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'App Icon',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SvgPicture.asset(
                  _getFlavorIconPath(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the environment information section.
  Widget _buildEnvironmentSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Environment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Label', AppTheme.environmentLabel),
            _buildInfoRow('Debug Banner', AppTheme.showDebugBanner.toString()),
          ],
        ),
      ),
    );
  }

  /// Builds the colors showcase section.
  Widget _buildColorsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flavor Colors',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildColorChip('Primary', ColorPalette.primary),
                _buildColorChip('Accent', ColorPalette.accent),
                _buildColorChip('Background', ColorPalette.background),
                _buildColorChip('Success', ColorPalette.success),
                _buildColorChip('Warning', ColorPalette.warning),
                _buildColorChip('Error', ColorPalette.error),
                _buildColorChip('Text', ColorPalette.text),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the typography showcase section.
  Widget _buildTypographySection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Typography',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Heading Text',
              style: TextStyle(
                fontFamily: app_typography.Typography.fontFamily,
                fontSize: app_typography.Typography.headingSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Body Text - This is an example of body text using the flavor-specific typography settings.',
              style: TextStyle(
                fontFamily: app_typography.Typography.fontFamily,
                fontSize: app_typography.Typography.bodySize,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Caption Text - Small text for captions and labels',
              style: TextStyle(
                fontFamily: app_typography.Typography.fontFamily,
                fontSize: app_typography.Typography.captionSize,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Font Family', app_typography.Typography.fontFamily),
            _buildInfoRow(
                'Heading Size', '${app_typography.Typography.headingSize}px'),
            _buildInfoRow(
                'Body Size', '${app_typography.Typography.bodySize}px'),
            _buildInfoRow(
                'Caption Size', '${app_typography.Typography.captionSize}px'),
          ],
        ),
      ),
    );
  }

  /// Builds the configuration information section.
  Widget _buildConfigSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('API URL', AppConfig.apiBaseUrl),
            _buildInfoRow('Environment', AppConfig.environment),
            _buildInfoRow('API Key', AppConfig.apiKey),
            _buildInfoRow('Analytics', AppConfig.enableAnalytics.toString()),
            _buildInfoRow('Debug Mode', AppConfig.debugMode.toString()),
            _buildInfoRow('Timeout', '${AppConfig.timeout}s'),
          ],
        ),
      ),
    );
  }

  /// Builds a color chip widget showing the color name and value.
  Widget _buildColorChip(String name, String hexColor) {
    final color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
      ),
      label: Text(
        name,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: Colors.grey[100],
    );
  }

  /// Builds an information row with label and value.
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// Gets the flavor-specific icon path.
  String _getFlavorIconPath() {
    final env = AppTheme.environmentLabel.toLowerCase();
    if (env.contains('dev')) {
      return 'assets/icons/dev/app_icon.svg';
    } else if (env.contains('staging') || env.contains('stag')) {
      return 'assets/icons/staging/app_icon.svg';
    } else {
      return 'assets/icons/production/app_icon.svg';
    }
  }
}
