// SessionId — anonymous 32-hex (16 byte) identifier with rotation timestamp.
//
// Pure Dart only. Must not import flutter / flutter_riverpod / just_audio /
// go_router / pigeon / flutter/services. Keeps the Domain layer free of
// platform / framework dependencies (single-direction layering rule).
//
// The first 8 hex of `value` form a user-facing fingerprint of the form
// `XXXX-XXXX`, used to display the current anonymous identity to the user
// per spec.md feature 4 (匿名セッション + ID ローテーション).

import 'dart:math';

class SessionId {
  /// 32 lowercase hex chars (16 bytes / 128 bits) anonymous id payload.
  final String value;

  /// When this id was issued (used by IdRotationPolicy to compute age).
  final DateTime issuedAt;

  const SessionId({
    required this.value,
    required this.issuedAt,
  });

  /// Generate a fresh SessionId from the supplied [rng] (use Random.secure()
  /// in production; tests inject a seeded Random for determinism).
  factory SessionId.generate(Random rng, DateTime now) {
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      // Each byte -> 2 hex chars, padded.
      final b = rng.nextInt(256);
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return SessionId(value: buf.toString(), issuedAt: now);
  }

  /// User-facing fingerprint derived from the first 8 hex chars of [value],
  /// rendered as `XXXX-XXXX`. Stable for a given [value].
  String get fingerprint {
    final head = value.substring(0, 8);
    return '${head.substring(0, 4)}-${head.substring(4, 8)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionId &&
        other.value == value &&
        other.issuedAt == issuedAt;
  }

  @override
  int get hashCode => Object.hash(value, issuedAt);

  @override
  String toString() => 'SessionId($fingerprint @ $issuedAt)';
}
