// RED phase test for FakeSessionTransport.
//
// Imports not-yet-existing service; will fail to compile until GREEN.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/fake_session_transport.dart';
import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/services/session_transport.dart';

void main() {
  HandshakeMessage outbound() => HandshakeMessage(
        fromIdValue: '0123456789abcdef0123456789abcdef',
        publicKeyHex: 'a' * 64,
        nonceHex: 'b' * 32,
      );

  HandshakeMessage incomingFor(String peerId) => HandshakeMessage(
        fromIdValue: peerId,
        publicKeyHex: 'c' * 64,
        nonceHex: 'd' * 32,
      );

  group('FakeSessionTransport', () {
    test('success outcome returns the configured HandshakeMessage', () async {
      final reply = incomingFor('peer-A');
      final transport = FakeSessionTransport(
        outcomes: {'peer-A': FakeHandshakeOutcome.success(reply)},
      );

      final result = await transport.sendHandshake('peer-A', outbound());

      expect(result.fromIdValue, 'peer-A');
      expect(result.publicKeyHex, reply.publicKeyHex);
    });

    test('failure outcome throws SessionTransportException', () async {
      final transport = FakeSessionTransport(
        outcomes: {
          'peer-B': FakeHandshakeOutcome.failure('boom'),
        },
      );

      expect(
        () => transport.sendHandshake('peer-B', outbound()),
        throwsA(isA<SessionTransportException>()),
      );
    });

    test('closeSession records peerId in closed set', () async {
      final transport = FakeSessionTransport(outcomes: const {});

      await transport.closeSession('peer-C');

      expect(transport.exposeClosedPeerIds().contains('peer-C'), isTrue);
    });

    test('emitDisconnect emits peerId on disconnectStream', () async {
      final transport = FakeSessionTransport(outcomes: const {});
      final received = <String>[];
      final sub = transport.disconnectStream.listen(received.add);

      transport.emitDisconnect('peer-D');
      // Allow the event loop to deliver the event.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, contains('peer-D'));
    });
  });
}
