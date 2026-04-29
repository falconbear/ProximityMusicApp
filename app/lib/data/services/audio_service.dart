// Data layer: AudioService
//
// Wraps just_audio's AudioPlayer and translates playback events into Riverpod
// state mutations. Imports flutter_riverpod's Ref for state plumbing and
// just_audio for the underlying player, but must NOT import flutter/material
// or go_router (data layer constraint).

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/presentation/state/providers.dart';

class AudioService {
  AudioService(this.ref);

  final Ref ref;

  Future<void> play(Track track) async {
    final player = ref.read(audioPlayerProvider);
    try {
      await player.setAsset(track.filePath);
      await player.play();
      ref.read(isPlayingProvider.notifier).state = true;
      ref.read(nowPlayingProvider.notifier).state = track;

      player.positionStream.listen((position) {
        ref.read(positionProvider.notifier).state = position;
      });

      player.durationStream.listen((duration) {
        if (duration != null) {
          ref.read(durationProvider.notifier).state = duration;
        }
      });

      player.playingStream.listen((playing) {
        ref.read(isPlayingProvider.notifier).state = playing;
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    final player = ref.read(audioPlayerProvider);
    await player.pause();
    ref.read(isPlayingProvider.notifier).state = false;
  }

  Future<void> resume() async {
    final player = ref.read(audioPlayerProvider);
    await player.play();
    ref.read(isPlayingProvider.notifier).state = true;
  }

  Future<void> stop() async {
    final player = ref.read(audioPlayerProvider);
    await player.stop();
    ref.read(isPlayingProvider.notifier).state = false;
    ref.read(positionProvider.notifier).state = Duration.zero;
  }

  Future<void> skipNext() async {
    final queue = ref.read(queueProvider);
    if (queue.isNotEmpty) {
      final updated = [...queue]..removeAt(0);
      ref.read(queueProvider.notifier).state = updated;

      if (updated.isNotEmpty) {
        await play(updated.first);
      } else {
        await stop();
        ref.read(nowPlayingProvider.notifier).state = null;
      }
    }
  }
}
