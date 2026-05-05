// Domain service: IntegrityVerifier (abstract) + Sha256IntegrityVerifier.
//
// Pure Dart only. The abstract API is List<int> in / String hex out so the
// Domain layer does not expose any crypto package types. The concrete
// implementation uses package:crypto's sha256 to compute the digest.

import 'package:crypto/crypto.dart' show sha256;

abstract class IntegrityVerifier {
  /// Returns true iff sha256(bytes) (lower-case hex) equals expectedHex.
  bool verify(List<int> bytes, String expectedHex);
}

class Sha256IntegrityVerifier implements IntegrityVerifier {
  const Sha256IntegrityVerifier();

  @override
  bool verify(List<int> bytes, String expectedHex) {
    final digest = sha256.convert(bytes);
    final actualHex = digest.toString(); // lowercase hex by default
    return actualHex == expectedHex.toLowerCase();
  }
}
