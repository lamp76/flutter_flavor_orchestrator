// Development Environment Configuration
// Generated for DEV flavor

class AppConfig {
  static const String environment = 'development';
  static const String apiBaseUrl = 'https://api-dev.example.com';
  static const String apiKey = 'dev-api-key-12345';
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  static const bool debugMode = true;
  static const int timeout = 60;

  static const Map<String, dynamic> features = {
    'beta_features': true,
    'experimental': true,
    'debug_panel': true,
  };
}
