// Domain unit tests for PlaybackQueue.
//
// TDD RED phase for Issue #6 (sprint-06: receive-instant-play + auto queue).
// Targets the future Domain layer file
// `package:proximity_music_app/domain/playback/playback_queue.dart` which does
// not exist yet. Until the GREEN phase introduces it, every test here MUST
// fail (compile error counts as failure under flutter_test).
//
// Pure Dart only — no Flutter / Riverpod / just_audio imports.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/playback_queue.dart';

void main() {
  const t1 = Track(
    title: 'Track One',
    from: 'Alice',
    filePath: 'assets/audio/t1.mp3',
  );
  const t2 = Track(
    title: 'Track Two',
    from: 'Bob',
    filePath: 'assets/audio/t2.mp3',
  );

  group('PlaybackQueue', () {
    test('empty queue: isEmpty true, currentTrack null, upcoming empty', () {
      final q = PlaybackQueue();

      expect(q.isEmpty, isTrue);
      expect(q.currentTrack, isNull);
      expect(q.upcoming, isEmpty);
    });

    test('after enqueue(t1): currentTrack==t1, upcoming empty, isEmpty false',
        () {
      final q = PlaybackQueue();

      q.enqueue(t1);

      expect(q.currentTrack, equals(t1));
      expect(q.upcoming, isEmpty);
      expect(q.isEmpty, isFalse);
    });

    test('after enqueue(t1) + enqueue(t2): currentTrack==t1, upcoming==[t2]',
        () {
      final q = PlaybackQueue();

      q.enqueue(t1);
      q.enqueue(t2);

      expect(q.currentTrack, equals(t1));
      expect(q.upcoming, equals(<Track>[t2]));
      expect(q.isEmpty, isFalse);
    });

    test('skip() advances currentTrack to next; final skip yields empty', () {
      final q = PlaybackQueue();
      q.enqueue(t1);
      q.enqueue(t2);

      // First skip: t1 leaves, t2 becomes current.
      q.skip();
      expect(q.currentTrack, equals(t2));
      expect(q.upcoming, isEmpty);
      expect(q.isEmpty, isFalse);

      // Second skip: queue becomes empty.
      q.skip();
      expect(q.currentTrack, isNull);
      expect(q.upcoming, isEmpty);
      expect(q.isEmpty, isTrue);
    });

    test('skip() on empty queue is a no-op (no exception)', () {
      final q = PlaybackQueue();

      // Must not throw.
      q.skip();
      expect(q.currentTrack, isNull);
      expect(q.isEmpty, isTrue);
    });

    test('clear() empties the queue', () {
      final q = PlaybackQueue();
      q.enqueue(t1);
      q.enqueue(t2);

      q.clear();

      expect(q.isEmpty, isTrue);
      expect(q.currentTrack, isNull);
      expect(q.upcoming, isEmpty);
    });
  });
}
