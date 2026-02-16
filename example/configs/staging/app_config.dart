// Staging Environment Configuration
// Generated for STAGING flavor

class AppConfig {
  static const String environment = 'staging';
  static const String apiBaseUrl = 'https://api-staging.example.com';
  static const String apiKey = 'staging-api-key-67890';
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool debugMode = false;
  static const int timeout = 30;

  static const Map<String, dynamic> features = {
    'beta_features': true,
    'experimental': false,
    'debug_panel': false,
  };
}
