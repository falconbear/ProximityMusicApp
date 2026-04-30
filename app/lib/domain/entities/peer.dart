// Domain entity: Peer.
//
// Pure Dart — no flutter / flutter_riverpod / pigeon dependencies.
// Represents an anonymous peer detected in proximity. `id` is an
// opaque session-local identifier, `avatarSeed` is a non-reversible
// hash material used by the Presentation layer to deterministically
// pick a colour + shape combination, and `lastSeenAt` is the most
// recent UTC detection timestamp.

class Peer {
  const Peer({
    required this.id,
    required this.lastSeenAt,
    required this.avatarSeed,
  });

  final String id;
  final DateTime lastSeenAt;
  final int avatarSeed;

  Peer copyWith({DateTime? lastSeenAt}) {
    return Peer(
      id: id,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      avatarSeed: avatarSeed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer &&
        other.id == id &&
        other.lastSeenAt == lastSeenAt &&
        other.avatarSeed == avatarSeed;
  }

  @override
  int get hashCode => Object.hash(id, lastSeenAt, avatarSeed);

  @override
  String toString() =>
      'Peer(id: $id, lastSeenAt: $lastSeenAt, avatarSeed: $avatarSeed)';
}
