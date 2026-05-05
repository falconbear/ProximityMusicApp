// KeyExchange — abstract interface for ephemeral key generation + shared
// secret derivation.
//
// Pure Dart (no flutter / framework imports). The Sprint 04 implementation
// is StubKeyExchange (sha256-based MVP placeholder). Real ECDH (X25519) lands
// in Issue #5 + via flutter/services + native crypto.

import 'package:proximity_music_app/domain/entities/key_pair.dart';

abstract class KeyExchange {
  /// Generate a fresh ephemeral key pair (public + private, both 64 hex).
  EphemeralKeyPair generate();

  /// Derive a 64 hex (256-bit) shared secret from our key pair and the
  /// peer's handshake message. Must be deterministic for identical inputs.
  String deriveSharedSecret(EphemeralKeyPair my, HandshakeMessage theirs);
}
