// Data service: DuplicateTrackDetector (abstract) + InMemoryDuplicateTrackDetector.
//
// Pure Dart only. The current Issue scope uses transit-cipher SHA-256 for the
// duplicate check (see contract.scope[5] / out_of_scope[12]); a future Issue
// may swap in a plain-content hash without changing this interface.

abstract class DuplicateTrackDetector {
  bool isDuplicate(String sha256Hex);
  void record(String sha256Hex);
}

class InMemoryDuplicateTrackDetector implements DuplicateTrackDetector {
  InMemoryDuplicateTrackDetector();

  final Set<String> _seen = <String>{};

  @override
  bool isDuplicate(String sha256Hex) => _seen.contains(sha256Hex);

  @override
  void record(String sha256Hex) {
    _seen.add(sha256Hex);
  }
}
