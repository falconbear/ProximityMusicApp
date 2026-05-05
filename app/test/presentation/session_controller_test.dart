// RED phase test for SessionController (pure-Dart, callback-injected).
//
// Imports not-yet-existing service; will fail to compile until GREEN.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/fake_session_transport.dart';
import 'package:proximity_music_app/data/services/stub_key_exchange.dart';
import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';
import 'package:proximity_music_app/domain/services/id_rotation_policy.dart';
import 'package:proximity_music_app/domain/services/session_registry.dart';
import 'package:proximity_music_app/presentation/state/session_controller.dart';

class _Harness {
  _Harness({
    required this.transport,
    required this.policy,
    required this.now,
    Random? rng,
  })  : registry = SessionRegistry(),
        rng = rng ?? Random(42),
        upserts = [] {
    controller = SessionController(
      transport: transport,
      keyExchange: StubKeyExchange(),
      idRotationPolicy: policy,
      upsertSession: (s) {
        upserts.add(s);
        registry.upsert(s);
      },
      onIdRotated: (_) {},
      clock: () => now,
      rng: () => this.rng,
    );
  }

  final FakeSessionTransport transport;
  final IdRotationPolicy policy;
  DateTime now;
  Random rng;
  final SessionRegistry registry;
  final List<Session> upserts;
  late final SessionController controller;
}

HandshakeMessage replyFor(String peerId) => HandshakeMessage(
      fromIdValue: peerId,
      publicKeyHex: 'c' * 64,
      nonceHex: 'd' * 32,
    );

void main() {
  final t0 = DateTime.utc(2026, 5, 5, 12);

  IdRotationPolicy newPolicy() {
    final id = SessionId.generate(Random(7), t0);
    return IdRotationPolicy(initial: id, initializedAt: t0);
  }

  group('SessionController', () {
    test('openSession success path: connecting -> connected upserts', () async {
      final h = _Harness(
        transport: FakeSessionTransport(
          outcomes: {'peer-A': FakeHandshakeOutcome.success(replyFor('peer-A'))},
        ),
        policy: newPolicy(),
        now: t0,
      );

      await h.controller.openSession('peer-A');

      expect(h.upserts.length, greaterThanOrEqualTo(2));
      expect(h.upserts.first.status, SessionStatus.connecting);
      expect(h.upserts.last.status, SessionStatus.connected);
      expect(h.upserts.last.sharedSecretHex, isNotNull);
    });

    test('openSession failure path: final upsert is failed + reason', () async {
      final h = _Harness(
        transport: FakeSessionTransport(
          outcomes: {'peer-A': FakeHandshakeOutcome.failure('handshake denied')},
        ),
        policy: newPolicy(),
        now: t0,
      );

      await h.controller.openSession('peer-A');

      expect(h.upserts.last.status, SessionStatus.failed);
      expect(h.upserts.last.failureReason, isNotNull);
      expect(h.upserts.last.failureReason!.isNotEmpty, isTrue);
    });

    test('retrySession transitions failed -> connecting -> connected', () async {
      final transport = FakeSessionTransport(
        outcomes: {'peer-A': FakeHandshakeOutcome.failure('temporary')},
      );
      final h = _Harness(
        transport: transport,
        policy: newPolicy(),
        now: t0,
      );

      await h.controller.openSession('peer-A');
      expect(h.upserts.last.status, SessionStatus.failed);

      // Switch outcome to success and retry.
      transport.setOutcome(
        'peer-A',
        FakeHandshakeOutcome.success(replyFor('peer-A')),
      );
      await h.controller.retrySession('peer-A');

      final statuses = h.upserts.map((s) => s.status).toList();
      expect(statuses.contains(SessionStatus.connecting), isTrue);
      expect(statuses.last, SessionStatus.connected);
    });

    test('rotateNow rotates current id and disconnects old-id sessions',
        () async {
      final h = _Harness(
        transport: FakeSessionTransport(
          outcomes: {'peer-A': FakeHandshakeOutcome.success(replyFor('peer-A'))},
        ),
        policy: newPolicy(),
        now: t0,
      );
      await h.controller.openSession('peer-A');
      final beforeId = h.policy.current.value;

      h.now = t0.add(const Duration(minutes: 16));
      h.controller.rotateNow(h.now, h.rng);

      expect(h.policy.current.value, isNot(beforeId));
      // The peer-A session was opened with the old id, so it must now be
      // marked disconnected via disconnectAllExcept.
      expect(h.registry.sessionFor('peer-A')?.status, SessionStatus.disconnected);
    });

    test('checkRotation triggers rotation when 16 min have passed', () {
      final h = _Harness(
        transport: FakeSessionTransport(outcomes: const {}),
        policy: newPolicy(),
        now: t0,
      );
      final before = h.policy.current.value;

      h.now = t0.add(const Duration(minutes: 16));
      h.controller.checkRotation(h.now, h.rng);

      expect(h.policy.current.value, isNot(before));
    });

    test('disconnectStream emit upserts session as disconnected', () async {
      final transport = FakeSessionTransport(
        outcomes: {'peer-A': FakeHandshakeOutcome.success(replyFor('peer-A'))},
      );
      final h = _Harness(
        transport: transport,
        policy: newPolicy(),
        now: t0,
      );
      await h.controller.openSession('peer-A');

      transport.emitDisconnect('peer-A');
      // Let the stream subscription dispatch.
      await Future<void>.delayed(Duration.zero);

      expect(
        h.registry.sessionFor('peer-A')?.status,
        SessionStatus.disconnected,
      );
    });
  });
}
