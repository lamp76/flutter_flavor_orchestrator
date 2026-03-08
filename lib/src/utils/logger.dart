/// Logging utility for the flavor orchestrator.
///
/// Provides a simple, consistent logging interface with support for
/// different log levels and formatted output.
final class Logger {
  /// Creates a new [Logger] instance.
  ///
  /// [verbose] enables detailed debug output.
  /// [silent] suppresses all output (used when JSON output mode is active).
  const Logger({this.verbose = false, this.silent = false});

  /// Whether to show verbose debug messages.
  final bool verbose;

  /// When `true`, all output methods become no-ops.
  ///
  /// This is used in JSON output mode to keep [stdout] clean so that only
  /// the machine-readable JSON payload appears there.
  final bool silent;

  /// Logs an informational message.
  void info(String message) {
    if (silent) {
      return;
    }
    // Use print with proper formatting to avoid avoid_print lint
    // In a production context, this would be replaced with proper logging
    // ignore: avoid_print
    print('ℹ️  $message');
  }

  /// Logs a success message.
  void success(String message) {
    if (silent) {
      return;
    }
    // ignore: avoid_print
    print('✅ $message');
  }

  /// Logs a warning message.
  void warning(String message) {
    if (silent) {
      return;
    }
    // ignore: avoid_print
    print('⚠️  WARNING: $message');
  }

  /// Logs an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (silent) {
      return;
    }
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
    if (silent || !verbose) {
      return;
    }
    // ignore: avoid_print
    print('🔍 DEBUG: $message');
  }

  /// Logs a section header for better output organization.
  void section(String title) {
    if (silent) {
      return;
    }
    // ignore: avoid_print
    print('\n${'=' * 60}');
    // ignore: avoid_print
    print('  $title');
    // ignore: avoid_print
    print('${'=' * 60}\n');
  }
}
