// EphemeralKeyPair + HandshakeMessage — value objects for KeyExchange.
//
// Pure Dart (no flutter / framework imports). All fields are hex strings to
// keep the contract trivially serializable across MethodChannel boundaries
// in a future Native session transport implementation (Issue #5+).

class EphemeralKeyPair {
  /// 64 hex chars (256-bit) public key.
  final String publicKeyHex;

  /// 64 hex chars (256-bit) private key.
  final String privateKeyHex;

  const EphemeralKeyPair({
    required this.publicKeyHex,
    required this.privateKeyHex,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EphemeralKeyPair &&
        other.publicKeyHex == publicKeyHex &&
        other.privateKeyHex == privateKeyHex;
  }

  @override
  int get hashCode => Object.hash(publicKeyHex, privateKeyHex);
}

class HandshakeMessage {
  /// The peer's local SessionId.value (32 hex) at handshake time.
  final String fromIdValue;

  /// 64 hex chars (256-bit) public key.
  final String publicKeyHex;

  /// 32 hex chars (128-bit) one-shot nonce.
  final String nonceHex;

  const HandshakeMessage({
    required this.fromIdValue,
    required this.publicKeyHex,
    required this.nonceHex,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HandshakeMessage &&
        other.fromIdValue == fromIdValue &&
        other.publicKeyHex == publicKeyHex &&
        other.nonceHex == nonceHex;
  }

  @override
  int get hashCode => Object.hash(fromIdValue, publicKeyHex, nonceHex);
}
