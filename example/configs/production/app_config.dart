// Production Environment Configuration
// Generated for PRODUCTION flavor

class AppConfig {
  static const String environment = 'production';
  static const String apiBaseUrl = 'https://api.example.com';
  static const String apiKey = 'prod-api-key-abcdef';
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool debugMode = false;
  static const int timeout = 30;

  static const Map<String, dynamic> features = {
    'beta_features': false,
    'experimental': false,
    'debug_panel': false,
  };
}
