// IdRotationPolicy — keeps the current SessionId and decides when it should
// rotate.
//
// Pure Dart (no flutter / framework imports). Implements spec.md feature 4
// acceptance criterion: 「アプリ起動毎と 15 分間隔のいずれか早い方」.
// app-start rotation is satisfied by callers constructing a fresh policy at
// app boot; this class then enforces the 15-minute interval thereafter.

import 'dart:math';

import 'package:proximity_music_app/domain/entities/session_id.dart';

class IdRotationPolicy {
  SessionId _current;
  DateTime _lastRotatedAt;

  IdRotationPolicy({
    required SessionId initial,
    required DateTime initializedAt,
  })  : _current = initial,
        _lastRotatedAt = initializedAt;

  SessionId get current => _current;

  DateTime? get lastRotatedAt => _lastRotatedAt;

  /// Returns true once [now] is at least [interval] past the last rotation
  /// (or initialization). Default interval is 15 minutes per spec.
  bool isDueForRotation(
    DateTime now, {
    Duration interval = const Duration(minutes: 15),
  }) {
    final age = now.difference(_lastRotatedAt);
    return age > interval;
  }

  /// Force a rotation: replace [current] with a freshly generated SessionId
  /// using [rng] and stamp [now] as the new lastRotatedAt.
  void rotate(DateTime now, Random rng) {
    _current = SessionId.generate(rng, now);
    _lastRotatedAt = now;
  }
}
