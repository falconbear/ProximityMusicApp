// StubKeyExchange — MVP placeholder implementation of KeyExchange.
//
// This is a placeholder for spec feature 4 (匿名セッション + ID ローテーション)
// that uses sha256 over (private || peer-public || peer-nonce) to fabricate
// a deterministic 64-hex shared secret. It is NOT real ECDH and does NOT
// provide forward secrecy. Real ECDH (X25519) is planned for Issue #5+ via
// flutter/services + native crypto.
//
// Pure Dart + dart:math + crypto package only. No flutter / pigeon imports.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/services/key_exchange.dart';

class StubKeyExchange implements KeyExchange {
  final Random _rng;

  StubKeyExchange({Random? rng}) : _rng = rng ?? Random.secure();

  @override
  EphemeralKeyPair generate() {
    final priv = _hex32(_rng);
    // Public is sha256(private) so two distinct privs always yield distinct
    // pubs; this satisfies the contract that publicKeyHex is 64 hex.
    final pub = _sha256Hex(priv);
    return EphemeralKeyPair(publicKeyHex: pub, privateKeyHex: priv);
  }

  @override
  String deriveSharedSecret(EphemeralKeyPair my, HandshakeMessage theirs) {
    // Order the inputs so identical (my, theirs) always produce the same
    // 64-hex output (deterministic per the test contract).
    final material = '${my.privateKeyHex}|${theirs.publicKeyHex}|${theirs.nonceHex}';
    return _sha256Hex(material);
  }

  String _hex32(Random rng) {
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      final b = rng.nextInt(256);
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
