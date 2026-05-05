// Domain service: PayloadDecryptor (abstract) + AesGcmPayloadDecryptor.
//
// Pure Dart only. The abstract API uses List<int> for plaintext / ciphertext /
// key / nonce so the Domain layer does not expose any crypto package types in
// its surface. The concrete implementation uses package:cryptography's AesGcm
// with a 256-bit key and a 12-byte nonce.
//
// Wire format for ciphertext: cipherBody (N bytes) followed by mac (16 bytes).
// AES-GCM authenticates the body with the mac; tampering of either causes
// decrypt to throw DecryptionFailure (which wraps SecretBoxAuthenticationError
// from package:cryptography).

import 'package:cryptography/cryptography.dart'
    show AesGcm, Mac, SecretBox, SecretBoxAuthenticationError, SecretKey;

import 'package:proximity_music_app/domain/entities/track_transfer.dart'
    show DecryptionFailure;

abstract class PayloadDecryptor {
  /// Decrypts [ciphertext] (cipherBody || mac, last 16 bytes are the mac)
  /// using [key] (32 bytes) and [nonce] (12 bytes). Throws
  /// [DecryptionFailure] on cipher / key / mac mismatch.
  Future<List<int>> decrypt({
    required List<int> ciphertext,
    required List<int> key,
    required List<int> nonce,
  });

  /// Encrypts [plaintext] for round-trip testing. Returns cipherBody || mac
  /// (mac length = 16 bytes, AES-GCM default).
  Future<List<int>> encryptForTest({
    required List<int> plaintext,
    required List<int> key,
    required List<int> nonce,
  });
}

class AesGcmPayloadDecryptor implements PayloadDecryptor {
  AesGcmPayloadDecryptor();

  static const int _macLength = 16; // AES-GCM default mac size in bytes.

  final AesGcm _algo = AesGcm.with256bits();

  @override
  Future<List<int>> decrypt({
    required List<int> ciphertext,
    required List<int> key,
    required List<int> nonce,
  }) async {
    if (ciphertext.length < _macLength) {
      throw const DecryptionFailure('ciphertext shorter than mac length');
    }
    final cipherBody = ciphertext.sublist(0, ciphertext.length - _macLength);
    final macBytes = ciphertext.sublist(ciphertext.length - _macLength);

    final secretKey = SecretKey(key);
    final box = SecretBox(cipherBody, nonce: nonce, mac: Mac(macBytes));

    try {
      return await _algo.decrypt(box, secretKey: secretKey);
    } on SecretBoxAuthenticationError catch (e) {
      throw DecryptionFailure('authentication failed: $e');
    } catch (e) {
      throw DecryptionFailure('decrypt failed: $e');
    }
  }

  @override
  Future<List<int>> encryptForTest({
    required List<int> plaintext,
    required List<int> key,
    required List<int> nonce,
  }) async {
    final secretKey = SecretKey(key);
    final box = await _algo.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return <int>[...box.cipherText, ...box.mac.bytes];
  }
}
