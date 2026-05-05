// Presentation widget: PeerListTile.
//
// One row in the Discover page peer list: avatar + truncated id +
// relative-time label. Exports `formatRelative(DateTime, DateTime now)`
// as a pure helper for testing.

import 'package:flutter/material.dart';

import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/presentation/widgets/peer_avatar.dart';

/// Returns a Japanese-locale relative-time string for [past] given
/// the current moment [now]. The function is intentionally pure so
/// it can be unit-tested without a Widget tree.
///
/// Buckets:
///   - 0s         → 'たった今'
///   - 1..59s     → 'X 秒前'
///   - 60..3599s  → 'X 分前'
///   - 3600s+     → 'X 時間前'
String formatRelative(DateTime past, DateTime now) {
  final diff = now.difference(past);
  final secs = diff.inSeconds;
  if (secs <= 0) return 'たった今';
  if (secs < 60) return '$secs 秒前';
  final minutes = secs ~/ 60;
  if (minutes < 60) return '$minutes 分前';
  final hours = minutes ~/ 60;
  return '$hours 時間前';
}

class PeerListTile extends StatelessWidget {
  const PeerListTile({super.key, required this.peer, this.now});

  final Peer peer;

  /// Optional clock injection; defaults to DateTime.now().toUtc().
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final reference = now ?? DateTime.now().toUtc();
    final shortId = peer.id.length > 8 ? peer.id.substring(0, 8) : peer.id;
    return ListTile(
      leading: PeerAvatar(peer: peer, size: 40),
      title: Text(
        shortId,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        formatRelative(peer.lastSeenAt, reference),
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
    );
  }
}
