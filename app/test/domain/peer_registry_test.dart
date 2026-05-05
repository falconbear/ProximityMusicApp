// Domain unit tests for PeerRegistry (Issue #3 — RED phase).
//
// Targets `package:proximity_music_app/domain/services/peer_registry.dart`.
// Validates the spec.md feature 3 acceptance criteria:
//   - duplicate ids do not produce duplicate peers
//   - peers older than ttl are pruned

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/peer_registry.dart';

void main() {
  group('PeerRegistry', () {
    test('empty registry returns []', () {
      final registry = PeerRegistry();
      expect(registry.peers, isEmpty);
    });

    test('upsert adds a single peer', () {
      final registry = PeerRegistry();
      final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
      registry.upsert(Peer(id: 'p1', lastSeenAt: t, avatarSeed: 1));

      expect(registry.peers.length, 1);
      expect(registry.peers.first.id, 'p1');
    });

    test('upsert with same id updates lastSeenAt instead of duplicating', () {
      final registry = PeerRegistry();
      final t1 = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final t2 = DateTime.utc(2026, 5, 1, 12, 0, 30);

      registry.upsert(Peer(id: 'p1', lastSeenAt: t1, avatarSeed: 1));
      registry.upsert(Peer(id: 'p1', lastSeenAt: t2, avatarSeed: 1));

      expect(registry.peers.length, 1);
      expect(registry.peers.first.lastSeenAt, t2);
    });

    test('prune removes peers whose lastSeenAt is older than ttl', () {
      final registry = PeerRegistry();
      final now = DateTime.utc(2026, 5, 1, 12, 1, 0);
      // 90 seconds before now → expired under 60s ttl.
      final old = now.subtract(const Duration(seconds: 90));
      registry.upsert(Peer(id: 'old', lastSeenAt: old, avatarSeed: 1));

      registry.prune(now, const Duration(seconds: 60));

      expect(registry.peers, isEmpty);
    });

    test('prune keeps peers whose lastSeenAt is within ttl', () {
      final registry = PeerRegistry();
      final now = DateTime.utc(2026, 5, 1, 12, 1, 0);
      // 30 seconds before now → fresh under 60s ttl.
      final fresh = now.subtract(const Duration(seconds: 30));
      registry.upsert(Peer(id: 'fresh', lastSeenAt: fresh, avatarSeed: 1));

      registry.prune(now, const Duration(seconds: 60));

      expect(registry.peers.length, 1);
      expect(registry.peers.first.id, 'fresh');
    });
  });
}
