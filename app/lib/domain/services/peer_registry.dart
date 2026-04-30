// Domain service: PeerRegistry.
//
// Pure Dart in-memory registry. Keyed by Peer.id; duplicate ids
// collapse into a single entry whose lastSeenAt is updated to the
// most recent detection. `prune` removes peers whose lastSeenAt is
// older than `now - ttl` (spec.md feature 3 — 60s default).

import 'package:proximity_music_app/domain/entities/peer.dart';

class PeerRegistry {
  final Map<String, Peer> _byId = <String, Peer>{};

  /// Insert or update a peer keyed on id. If a peer with the same id
  /// already exists, its lastSeenAt is updated to the new value
  /// (avatarSeed is preserved from the existing entry to avoid
  /// avatar flicker on re-detection).
  void upsert(Peer p) {
    final existing = _byId[p.id];
    if (existing == null) {
      _byId[p.id] = p;
    } else {
      _byId[p.id] = existing.copyWith(lastSeenAt: p.lastSeenAt);
    }
  }

  /// Remove peers whose lastSeenAt is older than `now - ttl`.
  void prune(DateTime now, Duration ttl) {
    final cutoff = now.subtract(ttl);
    _byId.removeWhere((_, peer) => peer.lastSeenAt.isBefore(cutoff));
  }

  /// Snapshot of the current peers, sorted by lastSeenAt descending
  /// (most-recently-seen first). Returns a new list each call.
  List<Peer> get peers {
    final list = _byId.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return list;
  }
}
