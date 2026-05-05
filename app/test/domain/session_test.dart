// RED phase test for Session entity.
//
// Imports not-yet-existing entities; flutter test will fail at compile time
// until GREEN adds the corresponding domain files.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';

void main() {
  final myId = SessionId(
    value: '0123456789abcdef0123456789abcdef',
    issuedAt: DateTime.utc(2026, 5, 5),
  );

  group('Session', () {
    test('constructor preserves all fields', () {
      final updated = DateTime.utc(2026, 5, 5, 12);
      final s = Session(
        peerId: 'peer-A',
        myIdAtOpen: myId,
        status: SessionStatus.connecting,
        updatedAt: updated,
      );

      expect(s.peerId, 'peer-A');
      expect(s.myIdAtOpen, myId);
      expect(s.status, SessionStatus.connecting);
      expect(s.updatedAt, updated);
      expect(s.sharedSecretHex, isNull);
      expect(s.failureReason, isNull);
    });

    test('copyWith returns new instance with overridden status only', () {
      final original = Session(
        peerId: 'peer-A',
        myIdAtOpen: myId,
        status: SessionStatus.connecting,
        updatedAt: DateTime.utc(2026, 5, 5, 12),
      );
      final later = DateTime.utc(2026, 5, 5, 12, 5);

      final updated = original.copyWith(
        status: SessionStatus.connected,
        updatedAt: later,
        sharedSecretHex: 'a' * 64,
      );

      expect(identical(updated, original), isFalse);
      expect(updated.peerId, original.peerId);
      expect(updated.myIdAtOpen, original.myIdAtOpen);
      expect(updated.status, SessionStatus.connected);
      expect(updated.updatedAt, later);
      expect(updated.sharedSecretHex, 'a' * 64);
      // Original unaffected.
      expect(original.status, SessionStatus.connecting);
      expect(original.sharedSecretHex, isNull);
    });

    test('two Sessions with same peerId+myIdAtOpen.value+status are equal', () {
      final a = Session(
        peerId: 'peer-A',
        myIdAtOpen: myId,
        status: SessionStatus.connected,
        updatedAt: DateTime.utc(2026, 5, 5, 12),
      );
      final b = Session(
        peerId: 'peer-A',
        myIdAtOpen: myId,
        status: SessionStatus.connected,
        updatedAt: DateTime.utc(2026, 5, 5, 13), // updatedAt differs
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('two Sessions with different status are not equal', () {
      final a = Session(
        peerId: 'peer-A',
        myIdAtOpen: myId,
        status: SessionStatus.connected,
        updatedAt: DateTime.utc(2026, 5, 5, 12),
      );
      final b = Session(
        peerId: 'peer-A',
        myIdAtOpen: myId,
        status: SessionStatus.failed,
        updatedAt: DateTime.utc(2026, 5, 5, 12),
      );

      expect(a == b, isFalse);
    });
  });
}
