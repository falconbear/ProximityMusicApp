// Widget tests for the MiniPlayer favorite-toggle behaviour added in Issue #6.
//
// TDD RED phase — relies on the future favorites toggle inside MiniPlayer
// and the new FavoritesStore wired through favoritesStoreProvider. Until
// GREEN, the tests must fail.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/favorites_store.dart';
import 'package:proximity_music_app/presentation/state/providers.dart';
import 'package:proximity_music_app/presentation/widgets/mini_player.dart';

void main() {
  const playing = Track(
    title: 'Now Playing',
    from: 'Peer',
    filePath: 'assets/audio/now.mp3',
  );

  Future<void> pumpMiniPlayer(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          nowPlayingProvider.overrideWith((ref) => playing),
        ],
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MiniPlayer(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'RED-6: favorite icon defaults to favorite_border for the current track',
      (WidgetTester tester) async {
    await pumpMiniPlayer(tester);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets(
      'RED-6: tapping favorite toggles the icon and updates FavoritesStore',
      (WidgetTester tester) async {
    await pumpMiniPlayer(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MiniPlayer)),
    );
    final FavoritesStore favorites = container.read(favoritesStoreProvider);

    // Initial: not favorited.
    expect(favorites.contains(playing), isFalse);

    // Tap the border icon → adds favorite, icon switches to filled.
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(favorites.contains(playing), isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);

    // Tap again → removes favorite, icon switches back.
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pump();

    expect(favorites.contains(playing), isFalse);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });
}
