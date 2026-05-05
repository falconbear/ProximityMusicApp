// Widget integration tests for the Issue #6 playback flow.
//
// TDD RED phase — exercises the future presentation wiring:
//   - playbackTrackSourceProvider (FakeTrackSource emits Track instances)
//   - audioGatewayProvider (overridden to a RecordingAudioGateway)
//   - PlaybackController bridging into nowPlayingProvider / queueProvider
//   - DashboardPage / MiniPlayer reacting to the controller's state
//
// Targets symbols that don't exist yet, so this file MUST fail to compile
// (which counts as a failing test under flutter_test) until the GREEN phase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/app.dart';
import 'package:proximity_music_app/data/services/fake_track_source.dart';
import 'package:proximity_music_app/data/services/recording_audio_gateway.dart';
import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/audio_gateway.dart';
import 'package:proximity_music_app/domain/playback/playback_track_source.dart';
import 'package:proximity_music_app/presentation/state/providers.dart';
import 'package:proximity_music_app/presentation/widgets/mini_player.dart';

void main() {
  const t1 = Track(
    title: 'Integ Track 1',
    from: 'Peer A',
    filePath: 'assets/audio/integ1.mp3',
  );
  const t2 = Track(
    title: 'Integ Track 2',
    from: 'Peer B',
    filePath: 'assets/audio/integ2.mp3',
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    required FakeTrackSource source,
    required RecordingAudioGateway gateway,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          audioGatewayProvider.overrideWithValue(gateway as AudioGateway),
          playbackTrackSourceProvider
              .overrideWithValue(source as PlaybackTrackSource),
        ],
        child: const ProximityMusicApp(),
      ),
    );
    // Allow router + listeners to wire up.
    await tester.pump();
  }

  testWidgets(
      'RED-4: emit(t1) on empty state → nowPlaying==t1, queue empty (instant '
      'playback)', (WidgetTester tester) async {
    final source = FakeTrackSource();
    final gateway = RecordingAudioGateway();

    await pumpApp(tester, source: source, gateway: gateway);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProximityMusicApp)),
    );

    // Pre-condition: nothing is playing, queue is empty.
    expect(container.read(nowPlayingProvider), isNull);
    expect(container.read(queueProvider), isEmpty);

    // Emit a track from the (Fake) discovery pipeline.
    source.emit(t1);
    await tester.pump();

    // Post-condition: nowPlaying mirrors t1, queue stays empty (instant play).
    expect(container.read(nowPlayingProvider), equals(t1));
    expect(container.read(queueProvider), isEmpty);
    expect(gateway.callLog, contains('play(${t1.title})'));
  });

  testWidgets(
      'RED-4: second emit while playing → nowPlaying stays t1, queue==[t2]',
      (WidgetTester tester) async {
    final source = FakeTrackSource();
    final gateway = RecordingAudioGateway();

    await pumpApp(tester, source: source, gateway: gateway);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProximityMusicApp)),
    );

    source.emit(t1);
    await tester.pump();
    source.emit(t2);
    await tester.pump();

    expect(container.read(nowPlayingProvider), equals(t1));
    expect(container.read(queueProvider), equals(<Track>[t2]));
  });

  testWidgets(
      'RED-5: skip while queue non-empty advances to next; final skip with no '
      'favorites + fallback collapses MiniPlayer to SizedBox',
      (WidgetTester tester) async {
    final source = FakeTrackSource();
    final gateway = RecordingAudioGateway();

    await pumpApp(tester, source: source, gateway: gateway);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProximityMusicApp)),
    );

    // Set up: t1 playing + t2 queued.
    source.emit(t1);
    await tester.pump();
    source.emit(t2);
    await tester.pump();

    // Skip via the controller (presentation wiring will route MiniPlayer's
    // skip button through the controller; here we drive it directly to keep
    // the test focused on state transitions).
    final controller = container.read(playbackControllerProvider);
    await controller.skip();
    await tester.pump();

    expect(container.read(nowPlayingProvider), equals(t2));
    expect(container.read(queueProvider), isEmpty);

    // Skip again: queue empty + favorites empty → nowPlaying becomes null.
    await controller.skip();
    await tester.pump();

    expect(container.read(nowPlayingProvider), isNull);

    // MiniPlayer with nowPlaying==null collapses to SizedBox.shrink.
    final miniPlayer = find.byType(MiniPlayer);
    expect(miniPlayer, findsOneWidget);
    expect(
      find.descendant(of: miniPlayer, matching: find.byType(SizedBox)),
      findsWidgets,
    );
  });
}
