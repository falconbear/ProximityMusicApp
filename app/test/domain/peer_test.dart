// Domain unit tests for Peer entity (Issue #3 — RED phase).
//
// Targets the future Domain layer file
// `package:proximity_music_app/domain/entities/peer.dart`. Until GREEN
// implements that class, every test here MUST fail (compile error
// counts as failure under flutter_test).

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/peer.dart';

void main() {
  group('Peer entity', () {
    test('constructor preserves id, lastSeenAt, avatarSeed', () {
      final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final peer = Peer(id: 'peer-001', lastSeenAt: t, avatarSeed: 42);

      expect(peer.id, 'peer-001');
      expect(peer.lastSeenAt, t);
      expect(peer.avatarSeed, 42);
    });

    test('copyWith updates lastSeenAt while preserving other fields', () {
      final t1 = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final t2 = DateTime.utc(2026, 5, 1, 12, 0, 30);
      final peer = Peer(id: 'peer-001', lastSeenAt: t1, avatarSeed: 42);

      final updated = peer.copyWith(lastSeenAt: t2);

      expect(updated.id, 'peer-001');
      expect(updated.lastSeenAt, t2);
      expect(updated.avatarSeed, 42);
      // Original unchanged.
      expect(peer.lastSeenAt, t1);
      // copyWith returns a new instance.
      expect(identical(peer, updated), isFalse);
    });

    test('two Peers with identical id/lastSeenAt/avatarSeed are equal', () {
      final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final a = Peer(id: 'peer-001', lastSeenAt: t, avatarSeed: 42);
      final b = Peer(id: 'peer-001', lastSeenAt: t, avatarSeed: 42);

      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two Peers with different ids are not equal', () {
      final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final a = Peer(id: 'peer-001', lastSeenAt: t, avatarSeed: 42);
      final b = Peer(id: 'peer-002', lastSeenAt: t, avatarSeed: 42);

      expect(a == b, isFalse);
    });
  });
}
