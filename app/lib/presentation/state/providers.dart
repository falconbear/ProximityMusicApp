// Presentation state providers (Riverpod).
//
// Holds the in-memory app state used by widgets. The audio service itself
// lives in `data/services/audio_service.dart` and is exposed here.
//
// Issue #6 additions:
//   - audioGatewayProvider          : abstract AudioGateway (so widget tests
//                                      can override it with a Recording fake)
//   - favoritesStoreProvider        : in-memory FavoritesStore (Domain)
//   - favoritesFallbackEnabledProvider : StateProvider<bool>, default true.
//                                      When ON and queue is empty, skip()
//                                      pulls a random favorite to keep
//                                      playback going.
//   - playbackTrackSourceProvider   : abstract PlaybackTrackSource. Test
//                                      doubles override with FakeTrackSource;
//                                      Issue #5 will plug in the real
//                                      TrackReceiver-backed source.
//   - playbackQueueProvider         : the underlying PlaybackQueue instance
//   - playbackControllerProvider    : the orchestrator that wires queue +
//                                      favorites + gateway + fallback into a
//                                      single Domain object. Listens to the
//                                      PlaybackTrackSource on construction
//                                      and bridges its state changes back
//                                      into nowPlayingProvider /
//                                      queueProvider.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:proximity_music_app/data/services/audio_service.dart';
import 'package:proximity_music_app/data/services/fake_track_source.dart';
import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/audio_gateway.dart';
import 'package:proximity_music_app/domain/playback/favorites_store.dart';
import 'package:proximity_music_app/domain/playback/playback_controller.dart';
import 'package:proximity_music_app/domain/playback/playback_queue.dart';
import 'package:proximity_music_app/domain/playback/playback_track_source.dart';

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

/// AudioGateway port used by PlaybackController. By default this is the same
/// AudioService instance. Widget tests override it with RecordingAudioGateway
/// to capture play()/stop() calls without invoking just_audio.
final audioGatewayProvider = Provider<AudioGateway>((ref) {
  return ref.read(audioServiceProvider);
});

/// In-memory favorites set (Issue #6 Scope: persistence belongs to a future
/// Issue).
final favoritesStoreProvider = Provider<FavoritesStore>((ref) {
  return FavoritesStore();
});

/// Monotonic counter incremented every time the FavoritesStore is mutated by
/// the UI. Widgets watching this rebuild on add/remove without us having to
/// turn FavoritesStore into a StateNotifier (keeps the Domain class simple).
final favoritesTickProvider = StateProvider<int>((ref) => 0);

/// Whether the "fall back to a favorite when the queue empties" behaviour is
/// enabled. Default ON per Issue #6 Scope. Persistence / settings UI is
/// out-of-scope (handled by Issue #10).
final favoritesFallbackEnabledProvider = StateProvider<bool>((ref) => true);

/// Abstract source of newly-received tracks. Default implementation throws if
/// constructed without override — Issue #5 will provide the real source. For
/// now, widget tests override this with FakeTrackSource and DashboardPage
/// keeps a single FakeTrackSource per ProviderScope (created lazily here so
/// `_simulateDiscovery` can push into the same stream the controller is
/// subscribed to).
final playbackTrackSourceProvider = Provider<PlaybackTrackSource>((ref) {
  // Default to a FakeTrackSource so the production app can drive the existing
  // "Simulate Discovery" button through the same code path the real receiver
  // (Issue #5) will use. Widget tests override this provider with their own
  // FakeTrackSource instance.
  final source = FakeTrackSource();
  ref.onDispose(source.dispose);
  return source;
});

/// The single PlaybackQueue instance backing the controller. Held as a
/// provider so tests can override it if they want to inject pre-populated
/// state, but in normal use it's just `PlaybackQueue()`.
final playbackQueueProvider = Provider<PlaybackQueue>((ref) {
  return PlaybackQueue();
});

/// Random source for favorites fallback. Held as a provider so tests can
/// override with a deterministic seed.
final playbackRandomProvider = Provider<Random>((ref) {
  return Random();
});

/// The orchestrator (Domain object). On construction, subscribes to the
/// configured PlaybackTrackSource and forwards every emission to
/// PlaybackController.onTrackReceived. After every controller call, pushes
/// the new (nowPlaying, upcoming) snapshot back into nowPlayingProvider /
/// queueProvider so the existing UI stays reactive.
final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final queue = ref.read(playbackQueueProvider);
  final favorites = ref.read(favoritesStoreProvider);
  final gateway = ref.read(audioGatewayProvider);
  final random = ref.read(playbackRandomProvider);

  final controller = _BridgedPlaybackController(
    queue: queue,
    favorites: favorites,
    gateway: gateway,
    fallbackEnabled: () => ref.read(favoritesFallbackEnabledProvider),
    random: random,
    onSnapshot: (now, upcoming) {
      ref.read(nowPlayingProvider.notifier).state = now;
      ref.read(queueProvider.notifier).state = upcoming;
    },
  );

  // Subscribe to the source: forward each Track to the controller.
  final source = ref.read(playbackTrackSourceProvider);
  final sub = source.tracks.listen(controller.onTrackReceived);
  ref.onDispose(sub.cancel);

  return controller;
});

/// Subclass of PlaybackController that pushes its post-call snapshot to a
/// callback so Riverpod providers stay in sync without the Domain knowing
/// about Riverpod.
class _BridgedPlaybackController extends PlaybackController {
  _BridgedPlaybackController({
    required super.queue,
    required super.favorites,
    required super.gateway,
    required super.fallbackEnabled,
    required super.random,
    required this.onSnapshot,
  });

  final void Function(Track? nowPlaying, List<Track> upcoming) onSnapshot;

  @override
  Future<void> onTrackReceived(Track track) async {
    await super.onTrackReceived(track);
    onSnapshot(nowPlaying, upcoming);
  }

  @override
  Future<void> skip() async {
    await super.skip();
    onSnapshot(nowPlaying, upcoming);
  }
}

