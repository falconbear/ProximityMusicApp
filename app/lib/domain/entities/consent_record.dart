// Domain entity: ConsentRecord
//
// Pure Dart only. Must NOT import flutter, flutter_riverpod, just_audio, or
// go_router.

/// The currently shipped Terms of Service / Privacy Policy version.
///
/// Bumping this constant in a future Sprint triggers the "needs reconsent"
/// flow described in spec feature 13. Sprint 02 pins this to `'v1'`.
const String currentTermsVersion = 'v1';

/// User-side record of a single consent acceptance.
///
/// Two records are equal iff their [acceptedVersion] and [acceptedAt] are
/// equal. The class is intentionally immutable; callers create a new instance
/// when re-accepting.
class ConsentRecord {
  ConsentRecord({
    required this.acceptedVersion,
    required this.acceptedAt,
  });

  /// Terms version the user agreed to (e.g. `'v1'`).
  final String acceptedVersion;

  /// Timestamp at which the user tapped the agree button.
  final DateTime acceptedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsentRecord &&
        other.acceptedVersion == acceptedVersion &&
        other.acceptedAt == acceptedAt;
  }

  @override
  int get hashCode => Object.hash(acceptedVersion, acceptedAt);

  @override
  String toString() {
    return 'ConsentRecord(acceptedVersion: $acceptedVersion, '
        'acceptedAt: $acceptedAt)';
  }
}
