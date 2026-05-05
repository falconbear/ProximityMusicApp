// RED phase test for SessionRegistry.
//
// Imports not-yet-existing service; will fail to compile until GREEN.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';
import 'package:proximity_music_app/domain/services/session_registry.dart';

void main() {
  final myIdA = SessionId(
    value: '0123456789abcdef0123456789abcdef',
    issuedAt: DateTime.utc(2026, 5, 5, 12),
  );
  final myIdB = SessionId(
    value: 'fedcba9876543210fedcba9876543210',
    issuedAt: DateTime.utc(2026, 5, 5, 13),
  );

  Session sessionFor(
    String peerId,
    SessionId myId,
    SessionStatus status, {
    DateTime? at,
  }) {
    return Session(
      peerId: peerId,
      myIdAtOpen: myId,
      status: status,
      updatedAt: at ?? DateTime.utc(2026, 5, 5, 12),
    );
  }

  group('SessionRegistry', () {
    test('empty registry returns []', () {
      final r = SessionRegistry();
      expect(r.sessions, <Session>[]);
      expect(r.sessionFor('peer-A'), isNull);
    });

    test('upsert(Session A) yields sessions.length == 1', () {
      final r = SessionRegistry();
      r.upsert(sessionFor('peer-A', myIdA, SessionStatus.connecting));

      expect(r.sessions.length, 1);
      expect(r.sessionFor('peer-A')?.status, SessionStatus.connecting);
    });

    test('upsert same peerId updates status (length stays 1)', () {
      final r = SessionRegistry();
      r.upsert(sessionFor('peer-A', myIdA, SessionStatus.connecting));
      r.upsert(
        sessionFor(
          'peer-A',
          myIdA,
          SessionStatus.connected,
          at: DateTime.utc(2026, 5, 5, 12, 5),
        ),
      );

      expect(r.sessions.length, 1);
      expect(r.sessionFor('peer-A')?.status, SessionStatus.connected);
    });

    test('upsert with different myIdAtOpen replaces entry (length stays 1)',
        () {
      final r = SessionRegistry();
      r.upsert(sessionFor('peer-A', myIdA, SessionStatus.connected));
      r.upsert(
        sessionFor(
          'peer-A',
          myIdB,
          SessionStatus.connecting,
          at: DateTime.utc(2026, 5, 5, 13, 1),
        ),
      );

      expect(r.sessions.length, 1);
      expect(r.sessionFor('peer-A')?.myIdAtOpen.value, myIdB.value);
      expect(r.sessionFor('peer-A')?.status, SessionStatus.connecting);
    });

    test('disconnectAllExcept marks old-myId sessions as disconnected', () {
      final r = SessionRegistry();
      r.upsert(sessionFor('peer-A', myIdA, SessionStatus.connected));

      final now = DateTime.utc(2026, 5, 5, 13, 30);
      r.disconnectAllExcept(myIdB, now);

      expect(r.sessionFor('peer-A')?.status, SessionStatus.disconnected);
      expect(r.sessionFor('peer-A')?.updatedAt, now);
    });

    test('disconnectAllExcept leaves matching-myId sessions untouched', () {
      final r = SessionRegistry();
      r.upsert(sessionFor('peer-A', myIdA, SessionStatus.connected));

      final now = DateTime.utc(2026, 5, 5, 12, 30);
      r.disconnectAllExcept(myIdA, now);

      expect(r.sessionFor('peer-A')?.status, SessionStatus.connected);
    });
  });
}
