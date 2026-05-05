// Domain unit tests for PlaybackController.
//
// TDD RED phase for Issue #6. Targets the future Domain layer files:
//   - package:proximity_music_app/domain/playback/playback_controller.dart
//   - package:proximity_music_app/domain/playback/audio_gateway.dart
//   - package:proximity_music_app/domain/playback/playback_queue.dart
//   - package:proximity_music_app/domain/playback/favorites_store.dart
//
// PlaybackController orchestrates queue + favorites + AudioGateway:
//   (a) onTrackReceived when nothing is playing  → AudioGateway.play(track)
//   (b) onTrackReceived while a track plays      → enqueue to upcoming
//   (c) skip() with non-empty queue              → play(next)
//   (d) skip() with empty queue + favorites empty → stop() and nowPlaying=null
//   (e) skip() with empty queue + favorites!=∅ + fallbackEnabled → play(fav)
//
// Pure Dart only — no Flutter / Riverpod / just_audio imports here.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/audio_gateway.dart';
import 'package:proximity_music_app/domain/playback/favorites_store.dart';
import 'package:proximity_music_app/domain/playback/playback_controller.dart';
import 'package:proximity_music_app/domain/playback/playback_queue.dart';

/// Test double for AudioGateway. Records every call as a string in [callLog]
/// so tests can assert exact ordering and arguments.
class FakeAudioGateway implements AudioGateway {
  final List<String> callLog = <String>[];

  @override
  Future<void> play(Track track) async {
    callLog.add('play(${track.title})');
  }

  @override
  Future<void> stop() async {
    callLog.add('stop()');
  }
}

void main() {
  const t1 = Track(
    title: 't1',
    from: 'A',
    filePath: 'assets/audio/t1.mp3',
  );
  const t2 = Track(
    title: 't2',
    from: 'B',
    filePath: 'assets/audio/t2.mp3',
  );
  const fav = Track(
    title: 'fav',
    from: 'F',
    filePath: 'assets/audio/fav.mp3',
  );

  PlaybackController makeController({
    bool fallbackEnabled = true,
    int seed = 42,
    FavoritesStore? favorites,
    PlaybackQueue? queue,
    FakeAudioGateway? gateway,
  }) {
    return PlaybackController(
      queue: queue ?? PlaybackQueue(),
      favorites: favorites ?? FavoritesStore(),
      gateway: gateway ?? FakeAudioGateway(),
      fallbackEnabled: () => fallbackEnabled,
      random: Random(seed),
    );
  }

  group('PlaybackController.onTrackReceived', () {
    test('(a) nowPlaying null + onTrackReceived(t1) → play(t1) once', () async {
      final gateway = FakeAudioGateway();
      final controller = makeController(gateway: gateway);

      await controller.onTrackReceived(t1);

      expect(gateway.callLog, equals(<String>['play(t1)']));
      expect(controller.nowPlaying, equals(t1));
    });

    test(
        '(b) nowPlaying non-null + onTrackReceived(t2) → no extra play, '
        'upcoming==[t2]', () async {
      final gateway = FakeAudioGateway();
      final controller = makeController(gateway: gateway);

      // First track starts playback.
      await controller.onTrackReceived(t1);
      expect(gateway.callLog, equals(<String>['play(t1)']));

      // Second track must NOT trigger another play(); it goes to upcoming.
      await controller.onTrackReceived(t2);

      expect(gateway.callLog, equals(<String>['play(t1)']));
      expect(controller.nowPlaying, equals(t1));
      expect(controller.upcoming, equals(<Track>[t2]));
    });
  });

  group('PlaybackController.skip', () {
    test('(c) skip with non-empty queue → play(next)', () async {
      final gateway = FakeAudioGateway();
      final controller = makeController(gateway: gateway);

      await controller.onTrackReceived(t1);
      await controller.onTrackReceived(t2);
      // callLog so far: ['play(t1)']

      await controller.skip();

      // Last call must be play(t2).
      expect(gateway.callLog.last, equals('play(t2)'));
      expect(controller.nowPlaying, equals(t2));
    });

    test(
        '(d) skip with empty queue + favorites empty + fallback ON → stop(), '
        'nowPlaying null', () async {
      final gateway = FakeAudioGateway();
      final controller = makeController(
        gateway: gateway,
        // favorites empty by default
      );

      await controller.onTrackReceived(t1);
      // callLog: ['play(t1)']

      await controller.skip();

      expect(gateway.callLog.last, equals('stop()'));
      expect(controller.nowPlaying, isNull);
    });

    test(
        '(d2) skip with empty queue + favorites empty + fallback OFF → stop(), '
        'nowPlaying null', () async {
      final gateway = FakeAudioGateway();
      final controller = makeController(
        gateway: gateway,
        fallbackEnabled: false,
      );

      await controller.onTrackReceived(t1);

      await controller.skip();

      expect(gateway.callLog.last, equals('stop()'));
      expect(controller.nowPlaying, isNull);
    });

    test(
        '(e) skip with empty queue + favorites 1+ + fallback ON → play(fav)',
        () async {
      final gateway = FakeAudioGateway();
      final favorites = FavoritesStore()..add(fav);
      final controller = makeController(
        gateway: gateway,
        favorites: favorites,
      );

      await controller.onTrackReceived(t1);

      await controller.skip();

      expect(gateway.callLog.last, equals('play(fav)'));
      expect(controller.nowPlaying, equals(fav));
    });

    test(
        '(e2) skip with empty queue + favorites 1+ but fallback OFF → stop()',
        () async {
      final gateway = FakeAudioGateway();
      final favorites = FavoritesStore()..add(fav);
      final controller = makeController(
        gateway: gateway,
        favorites: favorites,
        fallbackEnabled: false,
      );

      await controller.onTrackReceived(t1);

      await controller.skip();

      expect(gateway.callLog.last, equals('stop()'));
      expect(controller.nowPlaying, isNull);
    });
  });
}
