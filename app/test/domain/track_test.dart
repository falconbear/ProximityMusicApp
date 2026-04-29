// Domain unit tests for Track entity.
//
// TDD RED phase for Issue #1 (sprint-01: bootstrap-and-layered-refactor).
// These tests target the future Domain layer file
// `package:proximity_music_app/domain/entities/track.dart` which does not
// exist yet. Until the GREEN phase moves Track into that file with
// equality/hashCode/toString overrides, every test in this file MUST fail
// (compile error counts as failure under flutter_test).

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track.dart';

void main() {
  group('Track entity', () {
    test('constructor preserves field values', () {
      const track = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );

      expect(track.title, 'Song A');
      expect(track.from, 'Alice');
      expect(track.filePath, 'assets/audio/song_a.mp3');
      expect(track.duration, const Duration(minutes: 3, seconds: 14));
    });

    test('two Tracks with identical fields are equal (== returns true)', () {
      const a = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );
      const b = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );

      // Field-based equality must hold for identical content.
      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two Tracks with different fields are not equal (== returns false)',
        () {
      const a = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );
      const differentTitle = Track(
        title: 'Song B',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );
      const differentFrom = Track(
        title: 'Song A',
        from: 'Bob',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );
      const differentFilePath = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/other.mp3',
        duration: Duration(minutes: 3, seconds: 14),
      );
      const differentDuration = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
        duration: Duration(minutes: 4),
      );

      expect(a == differentTitle, isFalse);
      expect(a == differentFrom, isFalse);
      expect(a == differentFilePath, isFalse);
      expect(a == differentDuration, isFalse);
    });

    test('toString contains class name and identifying fields', () {
      const track = Track(
        title: 'Song A',
        from: 'Alice',
        filePath: 'assets/audio/song_a.mp3',
      );

      final str = track.toString();
      expect(str, contains('Track'));
      expect(str, contains('Song A'));
      expect(str, contains('Alice'));
    });
  });
}
