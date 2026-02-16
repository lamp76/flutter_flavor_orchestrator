// This file will be replaced by the flavor orchestrator when applying a flavor.
// This is a fallback configuration for when no flavor has been applied yet.

class AppConfig {
  static const String environment = 'none';
  static const String apiBaseUrl = 'https://example.com/api';
  static const String apiKey = 'no-api-key';
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  static const bool debugMode = true;
  static const int timeout = 30;

  static const Map<String, dynamic> features = {
    'beta_features': false,
    'experimental': false,
    'debug_panel': false,
  };
}
