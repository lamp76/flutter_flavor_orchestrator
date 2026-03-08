/// Schema migration scaffold for flavor configuration files.
///
/// Provides an interface for future schema version migrations and a
/// migration registry.  Only a no-op v1→v1 migration is registered
/// now as a future-proof scaffold; real migrations will be added in
/// subsequent releases when breaking config changes are introduced.
library;

/// Describes a single schema migration step.
///
/// Implementations transform the raw YAML map (as returned by the
/// YAML parser, before flavor-config model construction) from one
/// schema version to the next.
abstract interface class SchemaMigration {
  /// The schema version this migration reads from.
  int get fromVersion;

  /// The schema version this migration produces.
  int get toVersion;

  /// Applies the migration to [raw] and returns the updated map.
  ///
  /// [raw] is the full config document map (including `schema_version`
  /// and all flavor keys).  The returned map must be a valid schema at
  /// [toVersion].
  Map<dynamic, dynamic> migrate(Map<dynamic, dynamic> raw);
}

/// No-op migration for schema version 1.
///
/// Registered as a scaffold to validate the migration pipeline without
/// any data transformation.  Future breaking changes will replace or
/// extend this with real migration logic.
final class _NoOpV1Migration implements SchemaMigration {
  const _NoOpV1Migration();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 1;

  @override
  Map<dynamic, dynamic> migrate(Map<dynamic, dynamic> raw) => raw;
}

/// Registry of all known [SchemaMigration]s.
///
/// Call [applyMigrations] to advance a raw config map from a given
/// version to the latest supported version.
final class SchemaMigrations {
  SchemaMigrations._();

  /// All registered migrations, ordered by [SchemaMigration.fromVersion].
  static const List<SchemaMigration> registered = [
    _NoOpV1Migration(),
  ];

  /// Applies all applicable migrations starting at [fromVersion].
  ///
  /// Iterates through [registered] and applies each migration whose
  /// [SchemaMigration.fromVersion] matches the current version.  If no
  /// migration is found for the current version the loop stops.
  ///
  /// Returns the (potentially updated) raw map together with the final
  /// version number.
  ///
  /// Example:
  /// ```dart
  /// final result = SchemaMigrations.applyMigrations(rawMap, fromVersion: 1);
  /// final migratedMap = result.$1;
  /// final finalVersion = result.$2;
  /// ```
  static (Map<dynamic, dynamic> raw, int version) applyMigrations(
    Map<dynamic, dynamic> raw, {
    required int fromVersion,
  }) {
    var current = raw;
    var version = fromVersion;

    while (true) {
      final match = registered
          .where((m) => m.fromVersion == version)
          .firstOrNull;
      if (match == null) {
        break;
      }
      current = match.migrate(current);
      // If migration is a no-op (same version in/out), stop to prevent
      // an infinite loop.
      if (match.toVersion == version) {
        break;
      }
      version = match.toVersion;
    }

    return (current, version);
  }
}
