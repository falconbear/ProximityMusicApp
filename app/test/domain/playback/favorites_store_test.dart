// Domain unit tests for FavoritesStore.
//
// TDD RED phase for Issue #6 (sprint-06: receive-instant-play + auto queue).
// Targets `package:proximity_music_app/domain/playback/favorites_store.dart`,
// which does not exist yet. Pure Dart only — no Flutter / Riverpod imports.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/favorites_store.dart';

void main() {
  const t1 = Track(
    title: 'Fav One',
    from: 'Alice',
    filePath: 'assets/audio/fav1.mp3',
  );
  const t2 = Track(
    title: 'Fav Two',
    from: 'Bob',
    filePath: 'assets/audio/fav2.mp3',
  );

  group('FavoritesStore', () {
    test('newly constructed store is empty', () {
      final store = FavoritesStore();

      expect(store.isEmpty, isTrue);
      expect(store.contains(t1), isFalse);
    });

    test('add(t) is idempotent: adding the same Track twice keeps size 1', () {
      final store = FavoritesStore();

      store.add(t1);
      store.add(t1);

      expect(store.contains(t1), isTrue);
      expect(store.isEmpty, isFalse);
      // pickShuffled with a single element returns that element.
      final picked = store.pickShuffled(Random(42));
      expect(picked, equals(t1));
    });

    test('remove(notExisting) is a no-op (no exception)', () {
      final store = FavoritesStore();

      // No throw expected even though t1 is not present.
      store.remove(t1);
      expect(store.isEmpty, isTrue);

      store.add(t1);
      store.remove(t2); // t2 was never added — no-op.
      expect(store.contains(t1), isTrue);
    });

    test('pickShuffled(Random(42)) returns non-null when non-empty', () {
      final store = FavoritesStore();
      store.add(t1);
      store.add(t2);

      final picked = store.pickShuffled(Random(42));

      expect(picked, isNotNull);
      // The picked element must be one of the favorites.
      expect(<Track>[t1, t2].contains(picked), isTrue);
    });

    test('pickShuffled returns null on empty store', () {
      final store = FavoritesStore();

      final picked = store.pickShuffled(Random(42));

      expect(picked, isNull);
    });

    test('pickShuffled is deterministic given the same seed', () {
      final storeA = FavoritesStore()
        ..add(t1)
        ..add(t2);
      final storeB = FavoritesStore()
        ..add(t1)
        ..add(t2);

      final pickedA = storeA.pickShuffled(Random(42));
      final pickedB = storeB.pickShuffled(Random(42));

      expect(pickedA, equals(pickedB));
    });
  });
}
