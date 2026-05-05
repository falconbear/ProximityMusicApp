// Domain unit tests for ConsentRecord (Issue #2 RED phase).
//
// Targets future Domain file:
//   package:proximity_music_app/domain/entities/consent_record.dart
//
// Must fail until GREEN implements the type.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/consent_record.dart';

void main() {
  group('ConsentRecord entity', () {
    test('constructor preserves acceptedVersion and acceptedAt', () {
      final at = DateTime.utc(2026, 4, 30, 12, 0, 0);
      final record = ConsentRecord(
        acceptedVersion: 'v1',
        acceptedAt: at,
      );

      expect(record.acceptedVersion, 'v1');
      expect(record.acceptedAt, at);
    });

    test('currentTermsVersion is a non-empty, non-null string equal to v1',
        () {
      // currentTermsVersion is the canonical "current" terms version constant
      // exposed alongside ConsentRecord. The contract pins it at 'v1' for
      // Sprint 02; bumping it triggers reconsent flow in later sprints.
      expect(currentTermsVersion, isNotNull);
      expect(currentTermsVersion, isNotEmpty);
      expect(currentTermsVersion, 'v1');
    });

    test('two records with the same version + timestamp are equal', () {
      final t = DateTime.utc(2026, 1, 1);
      final a = ConsentRecord(acceptedVersion: 'v1', acceptedAt: t);
      final b = ConsentRecord(
        acceptedVersion: 'v1',
        acceptedAt: DateTime.utc(2026, 1, 1),
      );

      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('records differ when acceptedVersion differs', () {
      final t = DateTime.utc(2026, 1, 1);
      final a = ConsentRecord(acceptedVersion: 'v1', acceptedAt: t);
      final b = ConsentRecord(acceptedVersion: 'v2', acceptedAt: t);

      expect(a == b, isFalse);
    });
  });
}
