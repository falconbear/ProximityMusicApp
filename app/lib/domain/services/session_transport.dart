// SessionTransport — abstract interface for sending handshake messages and
// being notified of disconnects.
//
// Pure Dart (no flutter / framework imports). FakeSessionTransport (Data
// layer) implements this for tests; NativeSessionTransport implements it
// over MethodChannel + EventChannel.

import 'package:proximity_music_app/domain/entities/key_pair.dart';

abstract class SessionTransport {
  /// Send our handshake to [peerId] and return the peer's reply. Throws
  /// [SessionTransportException] if the transport fails or the peer rejects.
  Future<HandshakeMessage> sendHandshake(
    String peerId,
    HandshakeMessage outbound,
  );

  /// Close any active session with [peerId]. Idempotent.
  Future<void> closeSession(String peerId);

  /// Stream of peerIds that the transport has just dropped (peer-initiated
  /// disconnect, link loss, app rotation, etc.).
  Stream<String> get disconnectStream;
}

class SessionTransportException implements Exception {
  final String message;

  const SessionTransportException(this.message);

  @override
  String toString() => 'SessionTransportException($message)';
}
