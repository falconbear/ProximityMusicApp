// RED phase test for StubKeyExchange.
//
// Imports not-yet-existing service; will fail to compile until GREEN.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/stub_key_exchange.dart';
import 'package:proximity_music_app/domain/entities/key_pair.dart';

void main() {
  group('StubKeyExchange', () {
    final hex64 = RegExp(r'^[0-9a-f]{64}$');

    test('generate returns 64 hex public + 64 hex private', () {
      final kx = StubKeyExchange();
      final kp = kx.generate();

      expect(kp.publicKeyHex.length, 64);
      expect(kp.privateKeyHex.length, 64);
      expect(hex64.hasMatch(kp.publicKeyHex), isTrue);
      expect(hex64.hasMatch(kp.privateKeyHex), isTrue);
    });

    test('generate called 50 times yields distinct private keys', () {
      final kx = StubKeyExchange();
      final keys = <String>{};

      for (var i = 0; i < 50; i++) {
        keys.add(kx.generate().privateKeyHex);
      }

      expect(keys.length, 50);
    });

    test('deriveSharedSecret is deterministic 64 hex on identical input', () {
      final kx = StubKeyExchange();
      final my = EphemeralKeyPair(
        publicKeyHex: 'a' * 64,
        privateKeyHex: 'b' * 64,
      );
      final theirs = HandshakeMessage(
        fromIdValue: '0123456789abcdef0123456789abcdef',
        publicKeyHex: 'c' * 64,
        nonceHex: 'd' * 32,
      );

      final s1 = kx.deriveSharedSecret(my, theirs);
      final s2 = kx.deriveSharedSecret(my, theirs);

      expect(s1.length, 64);
      expect(hex64.hasMatch(s1), isTrue);
      expect(s1, s2);
    });
  });
}
