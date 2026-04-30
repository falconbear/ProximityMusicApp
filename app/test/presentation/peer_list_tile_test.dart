// Presentation unit tests for the relative-time formatter exported from
// `peer_list_tile.dart` (Issue #3 — RED phase).

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/presentation/widgets/peer_list_tile.dart';

void main() {
  group('formatRelative', () {
    final now = DateTime.utc(2026, 5, 1, 12, 0, 0);

    test('5 seconds ago → "5 秒前"', () {
      final past = now.subtract(const Duration(seconds: 5));
      expect(formatRelative(past, now), '5 秒前');
    });

    test('90 seconds ago → "1 分前"', () {
      final past = now.subtract(const Duration(seconds: 90));
      expect(formatRelative(past, now), '1 分前');
    });

    test('3700 seconds ago → "1 時間前"', () {
      final past = now.subtract(const Duration(seconds: 3700));
      expect(formatRelative(past, now), '1 時間前');
    });

    test('0 seconds ago → "たった今"', () {
      expect(formatRelative(now, now), 'たった今');
    });
  });
}
