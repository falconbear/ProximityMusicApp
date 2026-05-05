// RED phase test for SessionId entity.
//
// These tests intentionally import not-yet-existing source files so that
// `flutter test` fails at compile time until the GREEN phase adds the
// implementation under app/lib/domain/entities/session_id.dart.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/session_id.dart';

void main() {
  group('SessionId', () {
    test('factory generate returns 32 hex chars and propagates DateTime', () {
      final now = DateTime.utc(2026, 5, 5, 12, 0, 0);
      final rng = Random(42);
      final id = SessionId.generate(rng, now);

      expect(id.value.length, 32);
      expect(RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(id.value), isTrue);
      expect(id.issuedAt, now);
    });

    test('fingerprint returns XXXX-XXXX form derived from first 8 hex', () {
      final id = SessionId(
        value: '0123456789abcdef0123456789abcdef',
        issuedAt: DateTime.utc(2026, 5, 5),
      );
      final fp = id.fingerprint;

      expect(RegExp(r'^[0-9a-fA-F]{4}-[0-9a-fA-F]{4}$').hasMatch(fp), isTrue);
      // Fingerprint must come from the first 8 hex chars of value.
      expect(
        fp.replaceAll('-', '').toLowerCase(),
        '01234567'.toLowerCase(),
      );
    });

    test('two SessionIds with same value+issuedAt are equal', () {
      final a = SessionId(
        value: '0123456789abcdef0123456789abcdef',
        issuedAt: DateTime.utc(2026, 5, 5),
      );
      final b = SessionId(
        value: '0123456789abcdef0123456789abcdef',
        issuedAt: DateTime.utc(2026, 5, 5),
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('SessionIds with different values are not equal', () {
      final a = SessionId(
        value: '0123456789abcdef0123456789abcdef',
        issuedAt: DateTime.utc(2026, 5, 5),
      );
      final b = SessionId(
        value: 'fedcba9876543210fedcba9876543210',
        issuedAt: DateTime.utc(2026, 5, 5),
      );

      expect(a == b, isFalse);
    });

    test('generate() called 100 times produces 100 distinct values', () {
      final rng = Random.secure();
      final now = DateTime.utc(2026, 5, 5);
      final values = <String>{};

      for (var i = 0; i < 100; i++) {
        values.add(SessionId.generate(rng, now).value);
      }

      expect(values.length, 100);
    });
  });
}
