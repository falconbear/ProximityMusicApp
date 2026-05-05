// Presentation page: DashboardPage
//
// Home screen: discovery toggle, now-playing summary, queue list, mini-player.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';
import 'package:proximity_music_app/presentation/state/providers.dart';
import 'package:proximity_music_app/presentation/widgets/mini_player.dart';
import 'package:proximity_music_app/presentation/widgets/permission_denied_banner.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryOn = ref.watch(discoveryProvider);
    final nowPlaying = ref.watch(nowPlayingProvider);
    final queue = ref.watch(queueProvider);
    final permissionStatuses = ref.watch(permissionStatusesProvider);
    final bluetoothStatus = permissionStatuses[AppPermission.bluetooth];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Music'),
        actions: [
          IconButton(
            tooltip: 'Anonymous Session',
            onPressed: () => context.go('/session'),
            icon: const Icon(
              Icons.fingerprint,
              color: Color(0xFF1DB954),
            ),
          ),
          IconButton(
            tooltip: 'Player',
            onPressed: () => context.go('/player'),
            icon: const Icon(
              Icons.queue_music,
              color: Color(0xFF1DB954),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1e3c32),
              Color(0xFF121212),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bluetoothStatus == PermissionStatus.denied)
              const PermissionDeniedBanner()
            else
              const SizedBox.shrink(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(context, ref, discoveryOn, queue),
                    const Text(
                      'Now Playing',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (nowPlaying != null)
                      _NowPlayingCard(track: nowPlaying)
                    else
                      _EmptyNowPlaying(),
                    const SizedBox(height: 24),
                    const Text(
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
                          ? _EmptyQueue()
                          : _QueueList(queue: queue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: discoveryOn
          ? FloatingActionButton.extended(
              onPressed: () => _simulateDiscovery(ref, queue),
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

  Widget _buildHero(
    BuildContext context,
    WidgetRef ref,
    bool discoveryOn,
    List<Track> queue,
  ) {
    return Container(
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
                  color: discoveryOn
                      ? const Color(0xFF1DB954)
                      : Colors.grey,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      discoveryOn ? 'Discovery Active' : 'Discovery Paused',
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
                    _simulateDiscovery(ref, queue);
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
    );
  }

  void _simulateDiscovery(WidgetRef ref, List<Track> queue) {
    const testTracks = [
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

    if (ref.read(nowPlayingProvider) == null) {
      final audioService = ref.read(audioServiceProvider);
      audioService.play(randomTrack);
    }
  }
}

class _NowPlayingCard extends ConsumerWidget {
  const _NowPlayingCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
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
                  track.from,
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
          IconButton(
            onPressed: () {
              ref.read(audioServiceProvider).skipNext();
            },
            icon: const Icon(
              Icons.skip_next_rounded,
              color: Color(0xFF1DB954),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNowPlaying extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      // Wrap in SingleChildScrollView so that the placeholder degrades
      // gracefully when the parent Expanded only allots a small height
      // (e.g. the 800x600 widget-test viewport). Avoids RenderFlex overflow
      // without changing copy, colors, or theme.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
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
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.queue});

  final List<Track> queue;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
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
                ? Border.all(
                    color: const Color(0xFF1DB954).withOpacity(0.3),
                  )
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFirst
                      ? [
                          const Color(0xFF1DB954),
                          const Color(0xFF1ed760),
                        ]
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
                ? const Icon(
                    Icons.equalizer,
                    color: Color(0xFF1DB954),
                    size: 20,
                  )
                : null,
          ),
        );
      },
    );
  }
}
