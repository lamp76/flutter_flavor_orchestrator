/// Logging utility for the flavor orchestrator.
///
/// Provides a simple, consistent logging interface with support for
/// different log levels and formatted output.
final class Logger {
  /// Creates a new [Logger] instance.
  ///
  /// [verbose] enables detailed debug output.
  const Logger({this.verbose = false});

  /// Whether to show verbose debug messages.
  final bool verbose;

  /// Logs an informational message.
  void info(String message) {
    // Use print with proper formatting to avoid avoid_print lint
    // In a production context, this would be replaced with proper logging
    // ignore: avoid_print
    print('ℹ️  $message');
  }

  /// Logs a success message.
  void success(String message) {
    // ignore: avoid_print
    print('✅ $message');
  }

  /// Logs a warning message.
  void warning(String message) {
    // ignore: avoid_print
    print('⚠️  WARNING: $message');
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print('❌ ERROR: $message');
    if (error != null) {
      // ignore: avoid_print
      print('   Details: $error');
    }
    if (stackTrace != null && verbose) {
      // ignore: avoid_print
      print('   Stack trace:\n$stackTrace');
    }
  }

  /// Logs a debug message (only shown if verbose is enabled).
  void debug(String message) {
    if (verbose) {
      // ignore: avoid_print
      print('🔍 DEBUG: $message');
    }
  }

  /// Logs a section header for better output organization.
  void section(String title) {
    // ignore: avoid_print
    print('\n${'=' * 60}');
    // ignore: avoid_print
    print('  $title');
    // ignore: avoid_print
    print('${'=' * 60}\n');
  }
}
