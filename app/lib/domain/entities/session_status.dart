// SessionStatus — finite-state lifecycle of a single peer session.
//
// Pure Dart enum (no flutter / framework imports). Used by the Session entity
// (domain/entities/session.dart) and rendered to the user by
// presentation/widgets/session_status_chip.dart.

enum SessionStatus {
  /// No handshake attempted yet.
  idle,

  /// Handshake / key exchange in progress.
  connecting,

  /// Handshake succeeded; shared secret available.
  connected,

  /// Handshake failed (permanently, until retried).
  failed,

  /// Previously connected, then dropped (by us, the peer, or rotation).
  disconnected,
}
