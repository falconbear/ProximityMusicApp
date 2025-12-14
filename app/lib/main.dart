import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const ProviderScope(child: ProximityMusicApp()));
}

class ProximityMusicApp extends StatelessWidget {
  const ProximityMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/player',
          builder: (context, state) => const PlayerPage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Proximity Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),     // Spotify Green
          secondary: Color(0xFF1DB954),
          surface: Color(0xFF181818),     // Card background
          background: Color(0xFF121212),   // Main background
          onPrimary: Colors.black,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF181818),
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

// Providers for discovery status, now playing, and audio player
final discoveryProvider = StateProvider<bool>((ref) => false);
final nowPlayingProvider = StateProvider<Track?>((ref) => null);
final queueProvider = StateProvider<List<Track>>((ref) => const []);

// Audio player provider
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

// Player state providers
final isPlayingProvider = StateProvider<bool>((ref) => false);
final positionProvider = StateProvider<Duration>((ref) => Duration.zero);
final durationProvider = StateProvider<Duration>((ref) => Duration.zero);

// Audio service provider
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(ref);
});

class AudioService {
  final Ref ref;
  AudioService(this.ref);
  
  Future<void> play(Track track) async {
    final player = ref.read(audioPlayerProvider);
    try {
      await player.setAsset(track.filePath);
      await player.play();
      ref.read(isPlayingProvider.notifier).state = true;
      ref.read(nowPlayingProvider.notifier).state = track;
      
      // Listen to position changes
      player.positionStream.listen((position) {
        ref.read(positionProvider.notifier).state = position;
      });
      
      // Listen to duration changes
      player.durationStream.listen((duration) {
        if (duration != null) {
          ref.read(durationProvider.notifier).state = duration;
        }
      });
      
      // Listen to player state changes
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

class Track {
  const Track({
    required this.title, 
    required this.from,
    required this.filePath,
    this.duration,
  });
  final String title;
  final String from;
  final String filePath;  // 音楽ファイルのパス
  final Duration? duration;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryOn = ref.watch(discoveryProvider);
    final nowPlaying = ref.watch(nowPlayingProvider);
    final queue = ref.watch(queueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Proximity'),
        actions: [
          IconButton(
            tooltip: 'Player',
            onPressed: () => context.go('/player'),
            icon: const Icon(Icons.music_note_rounded, color: Color(0xFF1DB954)),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1e3c32),  // Dark green gradient
              Color(0xFF121212),  // Main background
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: discoveryOn ? const Color(0xFF1DB954) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: discoveryOn 
                                ? const Color(0xFF1DB954).withOpacity(0.2) 
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            discoveryOn ? Icons.radar : Icons.radar_outlined,
                            color: discoveryOn ? const Color(0xFF1DB954) : Colors.grey,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                discoveryOn ? 'Discovery Active' : 'Discovery Mode',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                discoveryOn 
                                    ? 'Listening for nearby music...'
                                    : 'Connect with people around you',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: discoveryOn,
                          activeColor: const Color(0xFF1DB954),
                          onChanged: (value) {
                            ref.read(discoveryProvider.notifier).state = value;
                            if (value) {
                              // Simulate receiving a new track and start playback.
                              final testTracks = [
                                Track(
                                  title: 'Test Track 1',
                                  from: 'Nearby User A',
                                  filePath: 'assets/audio/test_track_1.mp3',
                                ),
                                Track(
                                  title: 'Test Track 2', 
                                  from: 'Nearby User B',
                                  filePath: 'assets/audio/test_track_2.mp3',
                                ),
                              ];
                              
                              final randomTrack = testTracks[queue.length % testTracks.length];
                              final newQueue = [randomTrack, ...queue];
                              ref.read(queueProvider.notifier).state = newQueue;
                              
                              // Auto-play if nothing is currently playing
                              if (ref.read(nowPlayingProvider) == null) {
                                final audioService = ref.read(audioServiceProvider);
                                audioService.play(randomTrack);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    if (discoveryOn) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.white.withOpacity(0.7),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${queue.length} tracks in queue',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            
              // Now Playing Section
              Text(
                'Now Playing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (nowPlaying != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Album Art Placeholder
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1DB954), Color(0xFF1ed760)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Track Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nowPlaying.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nowPlaying.from,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Skip Button
                      IconButton(
                        onPressed: () {
                          final audioService = ref.read(audioServiceProvider);
                          audioService.skipNext();
                        },
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Color(0xFF1DB954),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.music_off,
                        color: Colors.white.withOpacity(0.3),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No music playing',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Turn on Discovery to start receiving music',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Queue Section
              Text(
                'Up Next',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: queue.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.queue_music,
                              color: Colors.white.withOpacity(0.3),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your queue is empty',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Discovery new music from people around you',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final track = queue[index];
                          final isFirst = index == 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isFirst 
                                  ? const Color(0xFF1DB954).withOpacity(0.1)
                                  : const Color(0xFF181818),
                              borderRadius: BorderRadius.circular(8),
                              border: isFirst 
                                  ? Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))
                                  : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isFirst 
                                        ? [const Color(0xFF1DB954), const Color(0xFF1ed760)]
                                        : [Colors.grey.shade700, Colors.grey.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isFirst ? Icons.play_arrow : Icons.music_note,
                                  color: isFirst ? Colors.black : Colors.white,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                track.title,
                                style: TextStyle(
                                  color: isFirst ? const Color(0xFF1DB954) : Colors.white,
                                  fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                track.from,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isFirst 
                                  ? Icon(
                                      Icons.equalizer,
                                      color: const Color(0xFF1DB954),
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: discoveryOn 
          ? FloatingActionButton.extended(
              onPressed: () {
                final testTracks = [
                  Track(
                    title: 'Test Track 1',
                    from: 'Nearby User A',
                    filePath: 'assets/audio/test_track_1.mp3',
                  ),
                  Track(
                    title: 'Test Track 2',
                    from: 'Nearby User B', 
                    filePath: 'assets/audio/test_track_2.mp3',
                  ),
                ];
                
                final randomTrack = testTracks[queue.length % testTracks.length];
                final newQueue = [randomTrack, ...queue];
                ref.read(queueProvider.notifier).state = newQueue;
                
                // Auto-play if nothing is currently playing
                if (ref.read(nowPlayingProvider) == null) {
                  final audioService = ref.read(audioServiceProvider);
                  audioService.play(randomTrack);
                }
              },
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.radar),
              label: const Text(
                'Simulate Discovery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlaying = ref.watch(nowPlayingProvider);
    final queue = ref.watch(queueProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(positionProvider);
    final duration = ref.watch(durationProvider);
    final audioService = ref.read(audioServiceProvider);

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1e3c32),  // Dark green
              Color(0xFF121212),  // Spotify black
              Color(0xFF121212),
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Top Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Text(
                      'Playing Now',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Album Art Section
                if (nowPlaying != null) ...[
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Large Album Art
                        Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.width * 0.8,
                          constraints: const BoxConstraints(
                            maxWidth: 300,
                            maxHeight: 300,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1DB954),
                                Color(0xFF1ed760),
                                Color(0xFF21e065),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1DB954).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.black,
                            size: 120,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Track Info
                        Text(
                          nowPlaying.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          nowPlaying.from,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_off,
                          color: Colors.white.withOpacity(0.3),
                          size: 120,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No track selected',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Player Controls Section
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Progress Bar
                      if (nowPlaying != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF1DB954),
                                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                                  thumbColor: const Color(0xFF1DB954),
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.0,
                                  ),
                                ),
                                child: Slider(
                                  value: duration.inMilliseconds > 0 
                                      ? (position.inMilliseconds.toDouble() / duration.inMilliseconds.toDouble()).clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (value) {
                                    // TODO: Implement seek functionality
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                      
                      // Player Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: () => audioService.skipNext(),
                              icon: Icon(
                                Icons.skip_previous_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 36,
                              ),
                            ),
                            
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1DB954).withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: nowPlaying != null 
                                    ? () {
                                        if (isPlaying) {
                                          audioService.pause();
                                        } else {
                                          audioService.resume();
                                        }
                                      }
                                    : null,
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 36,
                                ),
                              ),
                            ),
                            
                            IconButton(
                              onPressed: () => audioService.skipNext(),
                              icon: Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Bottom Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.devices_rounded,
                              color: Colors.white.withOpacity(0.6),
                              size: 24,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.share_rounded,
                              color: Colors.white.withOpacity(0.6),
                              size: 24,
                            ),
                          ),
                          IconButton(
                            onPressed: nowPlaying == null
                                ? null
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF1DB954),
                                        content: Text(
                                          '${nowPlaying.from} blocked',
                                          style: const TextStyle(color: Colors.black),
                                        ),
                                      ),
                                    );
                                  },
                            icon: Icon(
                              Icons.block_rounded,
                              color: Colors.white.withOpacity(0.6),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                ],
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Mini Player Widget
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlaying = ref.watch(nowPlayingProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(positionProvider);
    final duration = ref.watch(durationProvider);
    final audioService = ref.read(audioServiceProvider);

    if (nowPlaying == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('/player'),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: duration.inMilliseconds > 0 
                ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                : 0.0,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
            minHeight: 2,
          ),
          
          // Player Controls
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Album Art
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1DB954), Color(0xFF1ed760)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Track Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          nowPlaying.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          nowPlaying.from,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Play/Pause Button
                  IconButton(
                    onPressed: () {
                      if (isPlaying) {
                        audioService.pause();
                      } else {
                        audioService.resume();
                      }
                    },
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  
                  // Skip Button
                  IconButton(
                    onPressed: () => audioService.skipNext(),
                    icon: Icon(
                      Icons.skip_next,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// Helper function to format duration
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
}
