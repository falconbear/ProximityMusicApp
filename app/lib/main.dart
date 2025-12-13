import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: router,
    );
  }
}

// Mock providers for discovery status and now playing.
final discoveryProvider = StateProvider<bool>((ref) => false);
final nowPlayingProvider = StateProvider<Track?>((ref) => null);
final queueProvider = StateProvider<List<Track>>((ref) => const []);

class Track {
  const Track({required this.title, required this.from});
  final String title;
  final String from;
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
        title: const Text('Proximity Music'),
        actions: [
          IconButton(
            tooltip: 'Player',
            onPressed: () => context.go('/player'),
            icon: const Icon(Icons.queue_music),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(
                  discoveryOn ? 'Discovery Active' : 'Discovery Paused',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text('すれ違いで曲を受信して自動再生します'),
                trailing: Switch(
                  value: discoveryOn,
                  onChanged: (value) {
                    ref.read(discoveryProvider.notifier).state = value;
                    if (value) {
                      // Simulate receiving a new track and start playback.
                      final mock = Track(
                        title: 'Random Track #${queue.length + 1}',
                        from: 'Nearby User',
                      );
                      ref.read(nowPlayingProvider.notifier).state = mock;
                      ref
                          .read(queueProvider.notifier)
                          .state = [mock, ...queue];
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Now Playing', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (nowPlaying != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(nowPlaying.title),
                  subtitle: Text('from ${nowPlaying.from}'),
                  trailing: IconButton(
                    tooltip: 'Skip',
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      if (queue.isNotEmpty) {
                        final updated = [...queue]..removeAt(0);
                        final next = updated.isNotEmpty ? updated.first : null;
                        ref.read(queueProvider.notifier).state = updated;
                        ref.read(nowPlayingProvider.notifier).state = next;
                      }
                    },
                  ),
                ),
              )
            else
              const Text('再生中の曲はありません'),
            const SizedBox(height: 16),
            Text('Queue', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: queue.isEmpty
                  ? const Center(child: Text('まだキューは空です'))
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        return ListTile(
                          leading: const Icon(Icons.audiotrack),
                          title: Text(track.title),
                          subtitle: Text('from ${track.from}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Mock receive another track while discovery is on.
          if (!discoveryOn) return;
          final mock = Track(
            title: 'Random Track #${queue.length + 1}',
            from: 'Nearby User',
          );
          ref.read(queueProvider.notifier).state = [mock, ...queue];
          if (ref.read(nowPlayingProvider) == null) {
            ref.read(nowPlayingProvider.notifier).state = mock;
          }
        },
        icon: const Icon(Icons.shuffle),
        label: const Text('受信をシミュレート'),
      ),
    );
  }
}

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlaying = ref.watch(nowPlayingProvider);
    final queue = ref.watch(queueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player'),
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.dashboard),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('再生コントロール', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.music_video),
                title: Text(nowPlaying?.title ?? '未再生'),
                subtitle: Text(nowPlaying != null
                    ? 'from ${nowPlaying.from}'
                    : '曲が届くとここに表示されます'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Skip',
                      icon: const Icon(Icons.skip_next),
                      onPressed: queue.isNotEmpty
                          ? () {
                              final updated = [...queue]..removeAt(0);
                              final next =
                                  updated.isNotEmpty ? updated.first : null;
                              ref.read(queueProvider.notifier).state = updated;
                              ref.read(nowPlayingProvider.notifier).state = next;
                            }
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Block sender',
                      icon: const Icon(Icons.block),
                      onPressed: nowPlaying == null
                          ? null
                          : () {
                              // Placeholder: block logic will be implemented with backend/secure storage.
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('${nowPlaying.from} をブロックしました'),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('キュー', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: queue.isEmpty
                  ? const Center(child: Text('キューは空です'))
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        return ListTile(
                          leading: const Icon(Icons.audiotrack),
                          title: Text(track.title),
                          subtitle: Text('from ${track.from}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
