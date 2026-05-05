// Data: FakeTrackSource
//
// Test-friendly PlaybackTrackSource that lets the caller manually emit Track
// instances onto the controller's input stream. Used by:
//   - widget tests (override `playbackTrackSourceProvider`)
//   - `DashboardPage._simulateDiscovery` until Issue #5 plugs in the real
//     TrackReceiver.
//
// Kept in the Data layer so the Domain stays free of dart:async stream
// machinery beyond the abstract type.

import 'dart:async';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/playback_track_source.dart';

class FakeTrackSource implements PlaybackTrackSource {
  FakeTrackSource() : _controller = StreamController<Track>.broadcast();

  final StreamController<Track> _controller;

  @override
  Stream<Track> get tracks => _controller.stream;

  /// Push [track] onto the stream. Listeners (typically PlaybackController)
  /// receive it on the next microtask / pump.
  void emit(Track track) {
    if (!_controller.isClosed) {
      _controller.add(track);
    }
  }

  /// Close the underlying stream. Safe to call multiple times.
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
