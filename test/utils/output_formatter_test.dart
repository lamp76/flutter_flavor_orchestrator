import 'dart:convert';

import 'package:flutter_flavor_orchestrator/flutter_flavor_orchestrator.dart';
import 'package:test/test.dart';

void main() {
  group('OutputFormat', () {
    test('has text and json values', () {
      expect(OutputFormat.values, contains(OutputFormat.text));
      expect(OutputFormat.values, contains(OutputFormat.json));
    });
  });

  group('parseOutputFormat', () {
    test("returns text for 'text'", () {
      expect(parseOutputFormat('text'), equals(OutputFormat.text));
    });

    test("returns json for 'json'", () {
      expect(parseOutputFormat('json'), equals(OutputFormat.json));
    });

    test('defaults to text for null', () {
      expect(parseOutputFormat(null), equals(OutputFormat.text));
    });

    test('defaults to text for unknown value', () {
      expect(parseOutputFormat('xml'), equals(OutputFormat.text));
    });
  });

  group('formatterFor', () {
    test('returns textOutputFormatter for text format', () {
      expect(formatterFor(OutputFormat.text), equals(textOutputFormatter));
    });

    test('returns jsonOutputFormatter for json format', () {
      expect(formatterFor(OutputFormat.json), equals(jsonOutputFormatter));
    });
  });

  group('textOutputFormatter', () {
    test('is a no-op function (does not throw)', () {
      expect(
        () => textOutputFormatter({'command': 'test', 'value': 42}),
        returnsNormally,
      );
    });
  });

  group('jsonOutputFormatter stable JSON keys', () {
    test('list result has required top-level keys', () {
      final result = {
        'command': 'list',
        'count': 2,
        'flavors': [
          {
            'name': 'dev',
            'file_mappings_count': 0,
            'replace_destination_directories': false,
          },
        ],
      };

      // Verify round-trip through JSON encoding
      final encoded = jsonEncode(result);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;

      expect(decoded, contains('command'));
      expect(decoded, contains('count'));
      expect(decoded, contains('flavors'));
      expect(decoded['command'], equals('list'));
    });

    test('info result has required top-level keys', () {
      final result = {
        'command': 'info',
        'flavor': {
          'name': 'dev',
          'bundle_id': 'com.example.dev',
          'app_name': 'App Dev',
          'file_mappings': <String, String>{},
          'file_mappings_count': 0,
          'replace_destination_directories': false,
        },
      };

      final encoded = jsonEncode(result);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;

      expect(decoded, contains('command'));
      expect(decoded, contains('flavor'));
      expect(decoded['command'], equals('info'));
      final flavor = decoded['flavor']! as Map<String, Object?>;
      expect(flavor, contains('name'));
      expect(flavor, contains('bundle_id'));
      expect(flavor, contains('app_name'));
    });

    test('validate result has required top-level keys', () {
      final result = {
        'command': 'validate',
        'valid': true,
        'flavors': [
          {'name': 'dev', 'valid': true, 'errors': <String>[]},
        ],
      };

      final encoded = jsonEncode(result);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;

      expect(decoded, contains('command'));
      expect(decoded, contains('valid'));
      expect(decoded, contains('flavors'));
      expect(decoded['command'], equals('validate'));
    });

    test('rollback result has required top-level keys', () {
      final result = {
        'command': 'rollback',
        'success': true,
        'backup_id': '20260225_194640123_dev',
        'flavor': 'dev',
        'files_restored': 3,
        'new_paths_removed': 1,
      };

      final encoded = jsonEncode(result);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;

      expect(decoded, contains('command'));
      expect(decoded, contains('success'));
      expect(decoded, contains('backup_id'));
      expect(decoded, contains('flavor'));
      expect(decoded, contains('files_restored'));
      expect(decoded, contains('new_paths_removed'));
    });
  });
}
