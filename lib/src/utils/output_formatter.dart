import 'dart:convert';
import 'dart:io';

/// Supported output formats for CLI commands.
enum OutputFormat {
  /// Human-readable text output (default).
  text,

  /// Machine-readable JSON output for CI automation.
  json,
}

/// A function that writes a structured result map to the appropriate channel.
///
/// For the text format this is a no-op — human-readable output is already
/// produced by the [Logger] inside the orchestrator methods.  For the JSON
/// format the result is serialised and written to [stdout].
typedef OutputFormatter = void Function(Map<String, Object?> result);

/// Text output formatter — no-op.
///
/// Human-readable output is already produced by the [Logger] inside the
/// orchestrator methods, so this formatter has nothing additional to write.
void textOutputFormatter(Map<String, Object?> result) {
  // Text output is produced by the Logger; nothing to do here.
}

/// JSON output formatter.
///
/// Encodes [result] as a compact JSON object and writes it to [stdout].
/// All human-readable logger output should be suppressed when this formatter
/// is in use (create the orchestrator with `silent: true`).
void jsonOutputFormatter(Map<String, Object?> result) =>
    stdout.writeln(jsonEncode(result));

/// Returns the [OutputFormatter] matching [format].
OutputFormatter formatterFor(OutputFormat format) => switch (format) {
      OutputFormat.text => textOutputFormatter,
      OutputFormat.json => jsonOutputFormatter,
    };

/// Parses a CLI `--output` option string into an [OutputFormat].
///
/// Accepts `'text'` or `'json'`; defaults to [OutputFormat.text].
OutputFormat parseOutputFormat(String? value) => switch (value) {
      'json' => OutputFormat.json,
      _ => OutputFormat.text,
    };
