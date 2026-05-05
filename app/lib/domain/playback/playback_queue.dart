// Domain: PlaybackQueue
//
// Pure Dart in-memory FIFO queue of tracks. The first element (if any) is the
// "current" track; the rest are upcoming. PlaybackQueue knows nothing about
// audio playback, favorites, or fallback behaviour — those concerns live in
// PlaybackController.
//
// Constraints:
//   - Pure Dart only. No flutter / flutter_riverpod / just_audio imports.
//   - No timers, streams, or arbitrary delays (structural perf guarantee).

import 'package:proximity_music_app/domain/entities/track.dart';

class PlaybackQueue {
  PlaybackQueue();

  final List<Track> _q = <Track>[];

  /// True when the queue holds zero tracks.
  bool get isEmpty => _q.isEmpty;

  /// The track at the head of the queue, or null if empty.
  Track? get currentTrack => _q.isEmpty ? null : _q.first;

  /// All tracks except the current one, in order. Empty when the queue holds
  /// zero or one tracks.
  List<Track> get upcoming => _q.length <= 1
      ? const <Track>[]
      : List<Track>.unmodifiable(_q.sublist(1));

  /// Append a track to the end of the queue.
  void enqueue(Track track) {
    _q.add(track);
  }

  /// Drop the current track. No-op when the queue is already empty.
  void skip() {
    if (_q.isNotEmpty) {
      _q.removeAt(0);
    }
  }

  /// Drop every track.
  void clear() {
    _q.clear();
  }
}
