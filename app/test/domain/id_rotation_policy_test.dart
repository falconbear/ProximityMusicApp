// RED phase test for IdRotationPolicy.
//
// Imports not-yet-existing service; will fail to compile until GREEN.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/services/id_rotation_policy.dart';

void main() {
  group('IdRotationPolicy', () {
    final initialTime = DateTime.utc(2026, 5, 5, 12, 0, 0);
    final rng = Random(123);

    SessionId initialId() => SessionId.generate(rng, initialTime);

    test('isDueForRotation is false immediately after init', () {
      final policy = IdRotationPolicy(
        initial: initialId(),
        initializedAt: initialTime,
      );

      expect(policy.isDueForRotation(initialTime), isFalse);
    });

    test('isDueForRotation is false at +14m59s (under 15 min)', () {
      final policy = IdRotationPolicy(
        initial: initialId(),
        initializedAt: initialTime,
      );

      final notYet = initialTime.add(
        const Duration(minutes: 14, seconds: 59),
      );

      expect(policy.isDueForRotation(notYet), isFalse);
    });

    test('isDueForRotation is true at +15m01s (over 15 min)', () {
      final policy = IdRotationPolicy(
        initial: initialId(),
        initializedAt: initialTime,
      );

      final due = initialTime.add(
        const Duration(minutes: 15, seconds: 1),
      );

      expect(policy.isDueForRotation(due), isTrue);
    });

    test('rotate replaces current and updates lastRotatedAt', () {
      final policy = IdRotationPolicy(
        initial: initialId(),
        initializedAt: initialTime,
      );
      final before = policy.current.value;

      final rotateAt = initialTime.add(const Duration(minutes: 16));
      policy.rotate(rotateAt, rng);

      expect(policy.current.value, isNot(before));
      expect(policy.lastRotatedAt, rotateAt);
    });

    test('isDueForRotation is false at +14m59s after rotate', () {
      final policy = IdRotationPolicy(
        initial: initialId(),
        initializedAt: initialTime,
      );

      final rotateAt = initialTime.add(const Duration(minutes: 16));
      policy.rotate(rotateAt, rng);

      final notYet = rotateAt.add(
        const Duration(minutes: 14, seconds: 59),
      );

      expect(policy.isDueForRotation(notYet), isFalse);
    });
  });
}
