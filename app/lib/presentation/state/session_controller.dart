// SessionController — orchestrates session lifecycle and ID rotation.
//
// Pure Dart + dart:async only. Does NOT import flutter / flutter_riverpod
// (Sprint 01 callback_injection_remedy continued: testability without a
// ProviderContainer). All side-effects flow through injected callbacks so
// session_controller_test.dart can drive it from plain Dart unit tests.
//
// State transitions implemented per .ai/work/4/contract.json scope[10]:
//   openSession(peerId)    : connecting -> (connected | failed)
//   retrySession(peerId)   : same as openSession
//   rotateNow(now, rng)    : rotates IdRotationPolicy, then emits a
//                            disconnected upsert for every session opened
//                            under the previous SessionId
//   checkRotation(now, rng): rotates only if IdRotationPolicy says it's due
//
// To honour disconnectAllExcept semantics without coupling to a concrete
// SessionRegistry, the controller maintains a small in-memory shadow of
// sessions it has emitted (keyed by peerId). On rotation it walks that
// shadow and re-emits any session whose myIdAtOpen.value differs from the
// new id as disconnected. The host's upsertSession callback then applies
// the change to whatever registry it owns.
//
// SessionTransport.disconnectStream is subscribed to in the constructor and
// peer-initiated disconnects are reflected through upsertSession.

import 'dart:async';
import 'dart:math';

import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';
import 'package:proximity_music_app/domain/services/id_rotation_policy.dart';
import 'package:proximity_music_app/domain/services/key_exchange.dart';
import 'package:proximity_music_app/domain/services/session_transport.dart';

typedef UpsertSession = void Function(Session session);
typedef OnIdRotated = void Function(SessionId newId);
typedef Clock = DateTime Function();
typedef RngFn = Random Function();

class SessionController {
  final SessionTransport transport;
  final KeyExchange keyExchange;
  final IdRotationPolicy idRotationPolicy;
  final UpsertSession upsertSession;
  final OnIdRotated onIdRotated;
  final Clock clock;
  final RngFn rng;

  /// Shadow of sessions this controller has emitted, keyed by peerId. Used
  /// only by rotateNow to identify sessions tied to a stale SessionId.
  final Map<String, Session> _shadow = {};

  StreamSubscription<String>? _disconnectSub;

  SessionController({
    required this.transport,
    required this.keyExchange,
    required this.idRotationPolicy,
    required this.upsertSession,
    required this.onIdRotated,
    required this.clock,
    required this.rng,
  }) {
    _disconnectSub = transport.disconnectStream.listen(_handleDisconnect);
  }

  Future<void> openSession(String peerId) async {
    final myId = idRotationPolicy.current;
    final now = clock();

    _emit(
      Session(
        peerId: peerId,
        myIdAtOpen: myId,
        status: SessionStatus.connecting,
        updatedAt: now,
      ),
    );

    try {
      final myKp = keyExchange.generate();
      final outbound = HandshakeMessage(
        fromIdValue: myId.value,
        publicKeyHex: myKp.publicKeyHex,
        nonceHex: _shortNonceHex(rng()),
      );
      final reply = await transport.sendHandshake(peerId, outbound);
      final shared = keyExchange.deriveSharedSecret(myKp, reply);

      _emit(
        Session(
          peerId: peerId,
          myIdAtOpen: myId,
          status: SessionStatus.connected,
          updatedAt: clock(),
          sharedSecretHex: shared,
        ),
      );
    } catch (e) {
      _emit(
        Session(
          peerId: peerId,
          myIdAtOpen: myId,
          status: SessionStatus.failed,
          updatedAt: clock(),
          failureReason: e.toString(),
        ),
      );
    }
  }

  Future<void> retrySession(String peerId) => openSession(peerId);

  void rotateNow(DateTime now, Random rngArg) {
    idRotationPolicy.rotate(now, rngArg);
    final newId = idRotationPolicy.current;
    onIdRotated(newId);

    // Emit a disconnected upsert for every session opened under the
    // previous SessionId. Iterate over a snapshot so we can mutate _shadow
    // safely inside _emit.
    final stale = _shadow.values
        .where((s) =>
            s.myIdAtOpen.value != newId.value &&
            s.status != SessionStatus.disconnected)
        .toList();
    for (final s in stale) {
      _emit(
        s.copyWith(
          status: SessionStatus.disconnected,
          updatedAt: now,
        ),
      );
    }
  }

  void checkRotation(DateTime now, Random rngArg) {
    if (idRotationPolicy.isDueForRotation(now)) {
      rotateNow(now, rngArg);
    }
  }

  Future<void> dispose() async {
    await _disconnectSub?.cancel();
    _disconnectSub = null;
  }

  void _emit(Session s) {
    _shadow[s.peerId] = s;
    upsertSession(s);
  }

  void _handleDisconnect(String peerId) {
    final prior = _shadow[peerId];
    final myId = prior?.myIdAtOpen ?? idRotationPolicy.current;
    _emit(
      Session(
        peerId: peerId,
        myIdAtOpen: myId,
        status: SessionStatus.disconnected,
        updatedAt: clock(),
      ),
    );
  }

  String _shortNonceHex(Random r) {
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buf.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }
}
