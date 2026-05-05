// Presentation widget: MiniPlayer
//
// Bottom navigation bar showing the currently playing track with quick
// play/pause, favorite toggle (Issue #6), and skip controls. Tapping the
// body navigates to /player.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/presentation/state/providers.dart';

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

    // Watch the favorites store + tick so the icon rebuilds when add/remove
    // fires. The store is mutable so identity doesn't change; the tick gives
    // Riverpod something to compare against.
    final favorites = ref.watch(favoritesStoreProvider);
    ref.watch(favoritesTickProvider);
    final isFavorite = favorites.contains(nowPlaying);

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
            LinearProgressIndicator(
              value: duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
              minHeight: 2,
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
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
                    IconButton(
                      onPressed: () {
                        if (isFavorite) {
                          favorites.remove(nowPlaying);
                        } else {
                          favorites.add(nowPlaying);
                        }
                        // FavoritesStore is a plain Set; mutating it doesn't
                        // automatically invalidate the Provider, so nudge the
                        // tree to rebuild by bumping a sibling counter.
                        ref.read(favoritesTickProvider.notifier).state++;
                      },
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? const Color(0xFF1DB954)
                            : Colors.white.withOpacity(0.8),
                        size: 24,
                      ),
                    ),
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
                    IconButton(
                      onPressed: () {
                        // Route skip through the PlaybackController so queue
                        // / favorites / fallback all stay consistent.
                        ref.read(playbackControllerProvider).skip();
                      },
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
