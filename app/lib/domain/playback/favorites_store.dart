// Domain: FavoritesStore
//
// In-memory set of "favorite" tracks. Pure Dart only — no persistence (that is
// a future Issue's concern), no Flutter or Riverpod imports.

import 'dart:math';

import 'package:proximity_music_app/domain/entities/track.dart';

class FavoritesStore {
  FavoritesStore();

  final Set<Track> _set = <Track>{};

  /// True when no track is favorited.
  bool get isEmpty => _set.isEmpty;

  /// Whether [track] is currently favorited.
  bool contains(Track track) => _set.contains(track);

  /// Mark [track] as favorited. Idempotent: adding the same track twice keeps
  /// the size at 1 (Set semantics).
  void add(Track track) {
    _set.add(track);
  }

  /// Unmark [track] as favorited. No-op when [track] is not present.
  void remove(Track track) {
    _set.remove(track);
  }

  /// Pick one favorite at random using [rng]. Returns null when the store is
  /// empty. Determinism comes from the caller-supplied Random — given the same
  /// seed and identical favorites the same Track is returned.
  Track? pickShuffled(Random rng) {
    if (_set.isEmpty) return null;
    final index = rng.nextInt(_set.length);
    return _set.elementAt(index);
  }
}
