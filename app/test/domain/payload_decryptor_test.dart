// Domain unit tests for AesGcmPayloadDecryptor.
//
// TDD RED phase for Issue #5 (sprint-05: P2P track transfer).
// Targets the future Domain layer file
// `package:proximity_music_app/domain/services/payload_decryptor.dart`.
//
// Test plan reference (contract.json TP-22): round-trip with fixed
// 32-byte key (0x00..0x1f), 12-byte nonce (0x00..0x0b), and the UTF-8
// plaintext 'hello world'.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track_transfer.dart'
    show DecryptionFailure;
import 'package:proximity_music_app/domain/services/payload_decryptor.dart';

void main() {
  // Fixed test vectors per TP-22.
  final key = List<int>.generate(32, (i) => i); // 0x00..0x1f
  final nonce = List<int>.generate(12, (i) => i); // 0x00..0x0b
  final plaintext = utf8.encode('hello world');

  group('AesGcmPayloadDecryptor', () {
    test(
      'decrypts a valid ciphertext back to the original plaintext',
      () async {
        final decryptor = AesGcmPayloadDecryptor();

        // Encrypt first to obtain a valid ciphertext under the same algorithm.
        final ciphertext = await decryptor.encryptForTest(
          plaintext: plaintext,
          key: key,
          nonce: nonce,
        );

        final recovered = await decryptor.decrypt(
          ciphertext: ciphertext,
          key: key,
          nonce: nonce,
        );

        expect(utf8.decode(recovered), 'hello world');
      },
    );

    test('throws when ciphertext is tampered (1 bit flip)', () async {
      final decryptor = AesGcmPayloadDecryptor();
      final ciphertext = await decryptor.encryptForTest(
        plaintext: plaintext,
        key: key,
        nonce: nonce,
      );

      // Flip a single bit in the ciphertext body (not the auth tag tail).
      final tampered = List<int>.from(ciphertext);
      tampered[0] = tampered[0] ^ 0x01;

      expect(
        () => decryptor.decrypt(ciphertext: tampered, key: key, nonce: nonce),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('throws when the wrong key is used', () async {
      final decryptor = AesGcmPayloadDecryptor();
      final ciphertext = await decryptor.encryptForTest(
        plaintext: plaintext,
        key: key,
        nonce: nonce,
      );

      // Use a different key.
      final wrongKey = List<int>.generate(32, (i) => 0xFF - i);

      expect(
        () => decryptor.decrypt(
          ciphertext: ciphertext,
          key: wrongKey,
          nonce: nonce,
        ),
        throwsA(isA<DecryptionFailure>()),
      );
    });
  });
}
