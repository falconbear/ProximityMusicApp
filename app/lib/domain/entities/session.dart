// Session — single peer's session record.
//
// Pure Dart (no flutter / framework imports). Equality is intentionally based
// on `(peerId, myIdAtOpen.value, status)` so the SessionRegistry can de-dupe
// on those three fields while still updating `updatedAt` / `failureReason`
// on every upsert.

import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';

class Session {
  /// Stable identifier of the peer (string, transport-supplied; not a
  /// SessionId — peers do not share their internal id).
  final String peerId;

  /// The local SessionId in effect when this session was first opened. If
  /// the local id rotates, sessions opened under the previous id are
  /// disconnected by `SessionRegistry.disconnectAllExcept`.
  final SessionId myIdAtOpen;

  final SessionStatus status;
  final DateTime updatedAt;

  /// 64 hex chars (256-bit) shared secret derived by KeyExchange. Null until
  /// handshake completes successfully.
  final String? sharedSecretHex;

  /// Free-form error reason recorded when [status] == failed.
  final String? failureReason;

  const Session({
    required this.peerId,
    required this.myIdAtOpen,
    required this.status,
    required this.updatedAt,
    this.sharedSecretHex,
    this.failureReason,
  });

  Session copyWith({
    SessionStatus? status,
    DateTime? updatedAt,
    String? sharedSecretHex,
    String? failureReason,
  }) {
    return Session(
      peerId: peerId,
      myIdAtOpen: myIdAtOpen,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      sharedSecretHex: sharedSecretHex ?? this.sharedSecretHex,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session &&
        other.peerId == peerId &&
        other.myIdAtOpen.value == myIdAtOpen.value &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(peerId, myIdAtOpen.value, status);

  @override
  String toString() =>
      'Session(peer=$peerId, myId=${myIdAtOpen.fingerprint}, status=$status)';
}
