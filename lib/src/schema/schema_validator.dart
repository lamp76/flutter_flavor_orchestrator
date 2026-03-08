/// Known top-level keys for a flavor configuration block.
///
/// Any key not in this set is considered unknown and will be reported
/// as an error in strict mode or a warning in non-strict mode.
const Set<String> knownFlavorKeys = {
  'bundle_id',
  'app_name',
  'icon_path',
  'metadata',
  'assets',
  'dependencies',
  'provisioning',
  'android_min_sdk_version',
  'android_target_sdk_version',
  'android_compile_sdk_version',
  'ios_min_version',
  'custom_gradle_config',
  'custom_info_plist_entries',
  'file_mappings',
  'replace_destination_directories',
};

/// Known keys inside the `provisioning` block of a flavor.
const Set<String> knownProvisioningKeys = {
  'android_google_services',
  'ios_google_service',
  'additional_files',
};

/// Keys that have been deprecated at the flavor level.
///
/// The map value is a human-readable remediation hint.
/// In strict mode, deprecated keys are treated as errors.
/// In non-strict mode, they produce warnings.
const Map<String, String> deprecatedFlavorKeys = {
  // Example (not yet applicable):
  // 'old_key': 'Replace `old_key` with `new_key` (see migration guide).',
};

/// The result of a schema-level validation pass.
///
/// Contains global issues (e.g. missing `schema_version`) and
/// per-flavor issues (e.g. unknown keys inside a specific flavor block).
final class SchemaValidationResult {
  /// Creates a [SchemaValidationResult].
  const SchemaValidationResult({
    required this.schemaVersion,
    required this.globalErrors,
    required this.globalWarnings,
    required this.flavorErrors,
    required this.flavorWarnings,
  });

  /// Parsed `schema_version` value, or `null` if absent.
  final int? schemaVersion;

  /// Schema-level errors that apply to the whole config document.
  ///
  /// Non-empty only when [SchemaValidator.validate] is called with
  /// `strict: true` and the config is missing `schema_version`.
  final List<String> globalErrors;

  /// Schema-level warnings that apply to the whole config document.
  ///
  /// Non-empty when `schema_version` is absent (non-strict mode).
  final List<String> globalWarnings;

  /// Per-flavor error lists keyed by flavor name.
  ///
  /// Non-empty entries only in strict mode (unknown / deprecated keys).
  final Map<String, List<String>> flavorErrors;

  /// Per-flavor warning lists keyed by flavor name.
  ///
  /// Non-empty entries only in non-strict mode (unknown / deprecated keys).
  final Map<String, List<String>> flavorWarnings;

  /// `true` when there are no global errors and no per-flavor errors.
  bool get isValid =>
      globalErrors.isEmpty &&
      flavorErrors.values.every((list) => list.isEmpty);

  /// `true` when there are any global or per-flavor warnings.
  bool get hasWarnings =>
      globalWarnings.isNotEmpty ||
      flavorWarnings.values.any((list) => list.isNotEmpty);

  /// Returns error messages for the given [flavorName], or an empty list.
  List<String> errorsForFlavor(String flavorName) =>
      flavorErrors[flavorName] ?? const [];

  /// Returns warning messages for the given [flavorName], or an empty list.
  List<String> warningsForFlavor(String flavorName) =>
      flavorWarnings[flavorName] ?? const [];
}

/// Validates the structural schema of a raw flavor config YAML map.
///
/// The [validate] method checks for:
/// - Presence of `schema_version` (error in strict mode, warning otherwise).
/// - Unknown keys in each flavor block (error in strict, warning otherwise).
/// - Deprecated keys in each flavor block (same severity rules as above).
/// - Unknown keys in the `provisioning` sub-block of each flavor.
///
/// This validator does **not** check semantic correctness (e.g. valid
/// `bundle_id` format). Semantic validation is handled by
/// [ConfigParser.validateConfig].
///
/// Usage:
/// ```dart
/// final result = const SchemaValidator().validate(rawFlavors, schemaVersion);
/// if (!result.isValid) { /* handle errors */ }
/// ```
final class SchemaValidator {
  /// Creates a [SchemaValidator].
  const SchemaValidator();

  /// Validates the schema of a raw config document.
  ///
  /// [rawFlavors] is the map of flavor names to their raw YAML data.
  /// This map must **not** include the `schema_version` key — callers
  /// should strip it with [ConfigParser.extractSchemaVersion] first.
  ///
  /// [schemaVersion] is the extracted version, or `null` if absent.
  ///
  /// [strict] controls whether unknown/deprecated keys and a missing
  /// `schema_version` are treated as errors (`true`) or warnings (`false`).
  SchemaValidationResult validate(
    Map<dynamic, dynamic> rawFlavors,
    int? schemaVersion, {
    bool strict = false,
  }) {
    final globalErrors = <String>[];
    final globalWarnings = <String>[];
    final flavorErrors = <String, List<String>>{};
    final flavorWarnings = <String, List<String>>{};

    // ── Schema version check ─────────────────────────────────────────────────
    if (schemaVersion == null) {
      const msg = 'Missing schema_version in config. '
          'Add `schema_version: 1` at the top of your flavor_config.yaml '
          'to enable strict schema validation and future migration support.';
      if (strict) {
        globalErrors.add(msg);
      } else {
        globalWarnings.add(msg);
      }
    }

    // ── Per-flavor key checks ─────────────────────────────────────────────────
    for (final entry in rawFlavors.entries) {
      final flavorName = entry.key as String;

      // Guard: skip flavors whose data is not a map (e.g. malformed YAML).
      if (entry.value is! Map<dynamic, dynamic>) {
        continue;
      }
      final flavorData = entry.value as Map<dynamic, dynamic>;

      final fErrors = <String>[];
      final fWarnings = <String>[];

      _validateFlavorKeys(
        flavorName,
        flavorData,
        errors: fErrors,
        warnings: fWarnings,
        strict: strict,
      );

      flavorErrors[flavorName] = fErrors;
      flavorWarnings[flavorName] = fWarnings;
    }

    return SchemaValidationResult(
      schemaVersion: schemaVersion,
      globalErrors: globalErrors,
      globalWarnings: globalWarnings,
      flavorErrors: flavorErrors,
      flavorWarnings: flavorWarnings,
    );
  }

  void _validateFlavorKeys(
    String flavorName,
    Map<dynamic, dynamic> flavorData, {
    required List<String> errors,
    required List<String> warnings,
    required bool strict,
  }) {
    for (final key in flavorData.keys) {
      final keyStr = key as String;
      final keyPath = 'flavors.$flavorName.$keyStr';

      if (deprecatedFlavorKeys.containsKey(keyStr)) {
        final hint = deprecatedFlavorKeys[keyStr]!;
        final msg = 'Deprecated key at $keyPath: $hint';
        if (strict) {
          errors.add(msg);
        } else {
          warnings.add(msg);
        }
      } else if (!knownFlavorKeys.contains(keyStr)) {
        final msg = 'Unknown key at $keyPath — '
            'remove it or check the documentation for valid keys.';
        if (strict) {
          errors.add(msg);
        } else {
          warnings.add(msg);
        }
      }

      // ── Provisioning sub-key check ────────────────────────────────────────
      if (keyStr == 'provisioning' && flavorData[key] is Map<dynamic, dynamic>) {
        final provData = flavorData[key] as Map<dynamic, dynamic>;
        for (final provKey in provData.keys) {
          final provKeyStr = provKey as String;
          final provKeyPath =
              'flavors.$flavorName.provisioning.$provKeyStr';
          if (!knownProvisioningKeys.contains(provKeyStr)) {
            final msg = 'Unknown key at $provKeyPath — '
                'remove it or check the documentation for valid '
                'provisioning keys.';
            if (strict) {
              errors.add(msg);
            } else {
              warnings.add(msg);
            }
          }
        }
      }
    }
  }
}
