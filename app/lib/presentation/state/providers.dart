// Presentation state providers (Riverpod).
//
// Holds the in-memory app state used by widgets. The audio service itself
// lives in `data/services/audio_service.dart` and is exposed here.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:proximity_music_app/data/services/audio_service.dart';
import 'package:proximity_music_app/domain/entities/track.dart';

/// Whether discovery (proximity listening) is currently active.
final discoveryProvider = StateProvider<bool>((ref) => false);

/// The currently playing track (or null if nothing is playing).
final nowPlayingProvider = StateProvider<Track?>((ref) => null);

/// Upcoming queue of tracks.
final queueProvider = StateProvider<List<Track>>((ref) => const []);

/// Whether the audio player is currently in the playing state.
final isPlayingProvider = StateProvider<bool>((ref) => false);

/// Current playback position.
final positionProvider = StateProvider<Duration>((ref) => Duration.zero);

/// Total duration of the currently loaded track.
final durationProvider = StateProvider<Duration>((ref) => Duration.zero);

/// Underlying audio player. Dispose is wired through Ref.onDispose.
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Application service that orchestrates playback and queue mutations.
///
/// AudioService itself lives in the Data layer and knows nothing about
/// Riverpod providers. We wire its state-change callbacks here so the Data
/// layer stays free of Presentation imports (single-direction layering:
/// Presentation -> Data -> Domain).
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(
    ref.read(audioPlayerProvider),
    onPlayingChanged: (playing) =>
        ref.read(isPlayingProvider.notifier).state = playing,
    onPositionChanged: (position) =>
        ref.read(positionProvider.notifier).state = position,
    onDurationChanged: (duration) =>
        ref.read(durationProvider.notifier).state = duration,
    onNowPlayingChanged: (track) =>
        ref.read(nowPlayingProvider.notifier).state = track,
    readQueue: () => ref.read(queueProvider),
    writeQueue: (queue) => ref.read(queueProvider.notifier).state = queue,
  );
});
