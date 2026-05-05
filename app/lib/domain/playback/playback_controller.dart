// Domain: PlaybackController
//
// Orchestrates a [PlaybackQueue], a [FavoritesStore], and an [AudioGateway]
// to implement Issue #6's "instant playback + auto queue + favorites
// fallback" behaviour:
//
//   onTrackReceived(track):
//     - if nowPlaying == null  → start playing track immediately
//     - else                   → append track to upcoming
//
//   skip():
//     - if upcoming has a next → play the next track
//     - else if fallbackEnabled() && favorites not empty
//                              → play one favorite (random, deterministic
//                                given the injected Random)
//     - else                   → stop and clear nowPlaying
//
// Pure Dart only — no flutter / flutter_riverpod / just_audio imports. The
// controller exposes plain getters; reactive UI bridging (Riverpod) wires
// listeners on top.

import 'dart:math';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/audio_gateway.dart';
import 'package:proximity_music_app/domain/playback/favorites_store.dart';
import 'package:proximity_music_app/domain/playback/playback_queue.dart';

/// Returns the current value of the "favorites fallback" flag. Injected as a
/// callback (instead of a plain bool) so the Presentation layer can wire it
/// to a reactive Riverpod StateProvider without leaking Riverpod into Domain.
typedef FallbackEnabledGetter = bool Function();

class PlaybackController {
  PlaybackController({
    required PlaybackQueue queue,
    required FavoritesStore favorites,
    required AudioGateway gateway,
    required FallbackEnabledGetter fallbackEnabled,
    required Random random,
  })  : _queue = queue,
        _favorites = favorites,
        _gateway = gateway,
        _fallbackEnabled = fallbackEnabled,
        _random = random;

  final PlaybackQueue _queue;
  final FavoritesStore _favorites;
  final AudioGateway _gateway;
  final FallbackEnabledGetter _fallbackEnabled;
  final Random _random;

  Track? _nowPlaying;

  /// The track currently playing, or null when nothing is playing.
  ///
  /// Note: this is NOT always identical to [PlaybackQueue.currentTrack]. When
  /// the queue is empty and a favorite is played as fallback, [nowPlaying] is
  /// set to that favorite even though the queue stays empty.
  Track? get nowPlaying => _nowPlaying;

  /// The upcoming queue after the currently playing track. Mirrors
  /// [PlaybackQueue.upcoming] when [nowPlaying] equals the queue head; equals
  /// the entire queue when [nowPlaying] is a favorite-fallback track.
  List<Track> get upcoming {
    if (_queue.isEmpty) return const <Track>[];
    if (_nowPlaying != null && _nowPlaying == _queue.currentTrack) {
      return _queue.upcoming;
    }
    // Fallback case: nowPlaying is a favorite that isn't in the queue. Expose
    // the entire queue as "upcoming" so the UI can keep showing pending
    // tracks.
    return List<Track>.unmodifiable(<Track>[
      _queue.currentTrack as Track,
      ..._queue.upcoming,
    ]);
  }

  /// Call when a new track has finished arriving from the discovery pipeline.
  /// If nothing is playing, starts immediate playback; otherwise appends to
  /// upcoming.
  Future<void> onTrackReceived(Track track) async {
    if (_nowPlaying == null) {
      _queue.enqueue(track);
      _nowPlaying = track;
      await _gateway.play(track);
    } else {
      _queue.enqueue(track);
    }
  }

  /// Advance to the next track. See class docstring for the decision matrix.
  Future<void> skip() async {
    // Drop whatever is currently at the queue head (if anything). When the
    // current "now playing" came from favorites fallback, the queue head is
    // unrelated and we leave it alone — but if nowPlaying matches the queue
    // head, we remove it.
    if (!_queue.isEmpty &&
        _nowPlaying != null &&
        _nowPlaying == _queue.currentTrack) {
      _queue.skip();
    }

    if (!_queue.isEmpty) {
      final next = _queue.currentTrack as Track;
      _nowPlaying = next;
      await _gateway.play(next);
      return;
    }

    // Queue is empty: try favorites fallback.
    if (_fallbackEnabled() && !_favorites.isEmpty) {
      final fav = _favorites.pickShuffled(_random);
      if (fav != null) {
        _nowPlaying = fav;
        await _gateway.play(fav);
        return;
      }
    }

    _nowPlaying = null;
    await _gateway.stop();
  }
}
