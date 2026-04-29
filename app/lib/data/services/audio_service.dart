// Data layer: AudioService
//
// Wraps just_audio's AudioPlayer and notifies state changes via injected
// callbacks. The Data layer must NOT depend on the Presentation layer (no
// import of `presentation/state/providers.dart`); state plumbing into Riverpod
// providers is wired up in `audioServiceProvider` (Presentation) by passing
// closures that read/write the relevant providers. AudioService itself only
// knows about Domain types (Track) and just_audio's AudioPlayer.

import 'dart:developer' as developer;

import 'package:just_audio/just_audio.dart';

import 'package:proximity_music_app/domain/entities/track.dart';

/// Callback type aliases for state plumbing. These are deliberately defined
/// on Domain types only (no Riverpod / Flutter imports).
typedef PlayingChanged = void Function(bool playing);
typedef PositionChanged = void Function(Duration position);
typedef DurationChanged = void Function(Duration duration);
typedef NowPlayingChanged = void Function(Track? track);
typedef QueueRead = List<Track> Function();
typedef QueueWrite = void Function(List<Track> queue);

class AudioService {
  AudioService(
    this.player, {
    required this.onPlayingChanged,
    required this.onPositionChanged,
    required this.onDurationChanged,
    required this.onNowPlayingChanged,
    required this.readQueue,
    required this.writeQueue,
  });

  final AudioPlayer player;
  final PlayingChanged onPlayingChanged;
  final PositionChanged onPositionChanged;
  final DurationChanged onDurationChanged;
  final NowPlayingChanged onNowPlayingChanged;
  final QueueRead readQueue;
  final QueueWrite writeQueue;

  Future<void> play(Track track) async {
    try {
      await player.setAsset(track.filePath);
      await player.play();
      onPlayingChanged(true);
      onNowPlayingChanged(track);

      player.positionStream.listen((position) {
        onPositionChanged(position);
      });

      player.durationStream.listen((duration) {
        if (duration != null) {
          onDurationChanged(duration);
        }
      });

      player.playingStream.listen((playing) {
        onPlayingChanged(playing);
      });
    } catch (e) {
      developer.log('Error playing audio: $e', name: 'AudioService');
    }
  }

  Future<void> pause() async {
    await player.pause();
    onPlayingChanged(false);
  }

  Future<void> resume() async {
    await player.play();
    onPlayingChanged(true);
  }

  Future<void> stop() async {
    await player.stop();
    onPlayingChanged(false);
    onPositionChanged(Duration.zero);
  }

  Future<void> skipNext() async {
    final queue = readQueue();
    if (queue.isNotEmpty) {
      final updated = [...queue]..removeAt(0);
      writeQueue(updated);

      if (updated.isNotEmpty) {
        await play(updated.first);
      } else {
        await stop();
        onNowPlayingChanged(null);
      }
    }
  }
}
