// FakeSessionTransport — in-memory test double for SessionTransport.
//
// Pure Dart (no flutter / pigeon imports). Used by widget tests and by the
// default sessionTransportProvider until NativeSessionTransport graduates
// from a stub to a real P2P transport (Issue #5+).

import 'dart:async';

import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/services/session_transport.dart';

/// Per-peer outcome configured for sendHandshake.
class FakeHandshakeOutcome {
  final HandshakeMessage? reply;
  final String? failure;
  final Duration delay;

  const FakeHandshakeOutcome._({
    this.reply,
    this.failure,
    this.delay = Duration.zero,
  });

  factory FakeHandshakeOutcome.success(
    HandshakeMessage reply, {
    Duration delay = Duration.zero,
  }) {
    return FakeHandshakeOutcome._(reply: reply, delay: delay);
  }

  factory FakeHandshakeOutcome.failure(
    String message, {
    Duration delay = Duration.zero,
  }) {
    return FakeHandshakeOutcome._(failure: message, delay: delay);
  }

  bool get isFailure => failure != null;
}

class FakeSessionTransport implements SessionTransport {
  final Map<String, FakeHandshakeOutcome> _outcomes;
  final Set<String> _closed = <String>{};
  final StreamController<String> _disconnects =
      StreamController<String>.broadcast();

  FakeSessionTransport({required Map<String, FakeHandshakeOutcome> outcomes})
      : _outcomes = Map<String, FakeHandshakeOutcome>.from(outcomes);

  /// Test API: replace / install an outcome for [peerId] at runtime, used
  /// by retry-style scenarios that want to flip failure -> success between
  /// calls.
  void setOutcome(String peerId, FakeHandshakeOutcome outcome) {
    _outcomes[peerId] = outcome;
  }

  /// Test API: emit a peer-initiated disconnect on [disconnectStream].
  void emitDisconnect(String peerId) {
    _disconnects.add(peerId);
  }

  /// Test API: read-only view of peerIds that have been closed.
  Set<String> exposeClosedPeerIds() => Set<String>.unmodifiable(_closed);

  @override
  Future<HandshakeMessage> sendHandshake(
    String peerId,
    HandshakeMessage outbound,
  ) async {
    final outcome = _outcomes[peerId];
    if (outcome == null) {
      throw SessionTransportException('no outcome configured for $peerId');
    }
    if (outcome.delay > Duration.zero) {
      await Future<void>.delayed(outcome.delay);
    }
    if (outcome.isFailure) {
      throw SessionTransportException(outcome.failure!);
    }
    return outcome.reply!;
  }

  @override
  Future<void> closeSession(String peerId) async {
    _closed.add(peerId);
  }

  @override
  Stream<String> get disconnectStream => _disconnects.stream;
}
