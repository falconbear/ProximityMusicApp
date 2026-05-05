// Domain unit tests for Sha256IntegrityVerifier.
//
// TDD RED phase for Issue #5 (sprint-05: P2P track transfer).
// Targets the future Domain layer file
// `package:proximity_music_app/domain/services/integrity_verifier.dart`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/services/integrity_verifier.dart';

void main() {
  group('Sha256IntegrityVerifier', () {
    test('returns true for matching sha256 hex of known input', () {
      final verifier = const Sha256IntegrityVerifier();
      // Known SHA-256("abc") =
      // ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
      final input = utf8.encode('abc');
      const expectedHex =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

      expect(verifier.verify(input, expectedHex), isTrue);
    });

    test('returns false when payload is tampered (1 byte flipped)', () {
      final verifier = const Sha256IntegrityVerifier();
      final input = utf8.encode('abc');
      const expectedHex =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

      // Flip one byte to simulate tampering.
      final tampered = List<int>.from(input);
      tampered[0] = tampered[0] ^ 0x01;

      expect(verifier.verify(tampered, expectedHex), isFalse);
    });

    test(
      'empty bytes produce sha256 of empty '
      '(e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855)',
      () {
        final verifier = const Sha256IntegrityVerifier();
        const emptyHex =
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

        expect(verifier.verify(<int>[], emptyHex), isTrue);
      },
    );
  });
}
