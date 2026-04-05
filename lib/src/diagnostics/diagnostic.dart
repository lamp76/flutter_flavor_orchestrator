/// Severity level of a diagnostic finding.
enum DiagnosticSeverity {
  /// A problem that will prevent correct operation.
  error,

  /// A potential problem that may affect operation.
  warning,

  /// An informational note with no impact on operation.
  info,
}

/// A single diagnostic finding from the `doctor` command.
///
/// Each finding has a stable [code] for programmatic handling, a
/// human-readable [message], an optional [suggestion] with remediation
/// guidance, and an optional [path] pointing to the relevant file or
/// directory.
final class Diagnostic {
  /// Creates a new [Diagnostic].
  const Diagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.suggestion,
    this.path,
  });

  /// Stable, machine-readable diagnostic code.
  ///
  /// Current codes:
  /// - `no_pubspec` — `pubspec.yaml` not found; not a Flutter project.
  /// - `no_config` — No flavor config found in standard locations.
  /// - `config_parse_error` — Config file exists but cannot be parsed.
  /// - `no_flavor_config_key` — Config file loaded but contains no flavors.
  /// - `platform_dir_missing` — Expected platform directory does not exist.
  /// - `android_manifest_missing` — `android/app/src/main/AndroidManifest.xml`
  ///   not found.
  /// - `android_build_gradle_missing` — Neither `build.gradle` nor
  ///   `build.gradle.kts` found in `android/app/`.
  /// - `ios_info_plist_missing` — `ios/Runner/Info.plist` not found.
  /// - `ios_xcodeproj_missing` — `ios/Runner.xcodeproj/` not found.
  /// - `provisioning_file_missing` — A provisioning source file referenced in
  ///   the config does not exist on disk.
  /// - `file_mapping_source_missing` — A `file_mappings` source path referenced
  ///   in the config does not exist on disk.
  /// - `schema_version_missing` — `schema_version` key absent from config.
  /// - `config_valid` — Config is present and valid (info-level).
  final String code;

  /// Severity of this diagnostic.
  final DiagnosticSeverity severity;

  /// Human-readable description of the finding.
  final String message;

  /// Actionable remediation guidance.
  ///
  /// `null` when no specific action is required (e.g. info-level findings).
  final String? suggestion;

  /// Path to the file or directory most relevant to this finding.
  ///
  /// `null` when no specific path applies.
  final String? path;

  /// Serialises this diagnostic to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'code': code,
        'severity': severity.name,
        'message': message,
        if (suggestion != null) 'suggestion': suggestion,
        if (path != null) 'path': path,
      };

  @override
  String toString() => '[${severity.name}] $code: $message';
}

/// The aggregated result of a `doctor` run.
///
/// Contains all [Diagnostic] findings produced by the checks.  Use
/// [hasErrors] to decide the exit code — the `doctor` command should exit
/// with a non-zero code when any error-level finding is present.
final class DoctorResult {
  /// Creates a [DoctorResult] with the given [diagnostics].
  const DoctorResult({required this.diagnostics});

  /// All diagnostic findings, in the order they were produced.
  final List<Diagnostic> diagnostics;

  /// `true` when at least one finding has [DiagnosticSeverity.error].
  bool get hasErrors =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  /// Error-level findings.
  List<Diagnostic> get errors => diagnostics
      .where((d) => d.severity == DiagnosticSeverity.error)
      .toList();

  /// Warning-level findings.
  List<Diagnostic> get warnings => diagnostics
      .where((d) => d.severity == DiagnosticSeverity.warning)
      .toList();

  /// Info-level findings.
  List<Diagnostic> get infos => diagnostics
      .where((d) => d.severity == DiagnosticSeverity.info)
      .toList();

  /// Serialises the result to a JSON-compatible map.
  ///
  /// The returned map contains stable top-level keys suitable for the
  /// `doctor --output json` response:
  /// - `healthy` — `true` when there are no error-level findings.
  /// - `error_count` / `warning_count` / `info_count` — finding counts.
  /// - `diagnostics` — ordered list of serialised [Diagnostic] maps.
  Map<String, Object?> toJson() => {
        'healthy': !hasErrors,
        'error_count': errors.length,
        'warning_count': warnings.length,
        'info_count': infos.length,
        'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
      };
}
