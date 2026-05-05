// SessionStatusChip — small color-coded chip rendering a SessionStatus.
//
// AI-Slop anti-directive (spec.md): no asset / network image usage; the
// chip is composed of pure widgets only.

import 'package:flutter/material.dart';

import 'package:proximity_music_app/domain/entities/session_status.dart';

class SessionStatusChip extends StatelessWidget {
  const SessionStatusChip(this.status, {super.key});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == SessionStatus.connecting) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            spec.label,
            style: TextStyle(
              color: spec.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _ChipSpec _specFor(SessionStatus status) {
    switch (status) {
      case SessionStatus.idle:
        return const _ChipSpec(
          label: 'アイドル',
          background: Color(0xFF3A3A3A),
          foreground: Colors.white,
        );
      case SessionStatus.connecting:
        return const _ChipSpec(
          label: '接続中',
          background: Color(0xFF1DB954),
          foreground: Colors.white,
        );
      case SessionStatus.connected:
        return const _ChipSpec(
          label: '接続済み',
          background: Color(0xFF1DB954),
          foreground: Colors.white,
        );
      case SessionStatus.failed:
        return const _ChipSpec(
          label: '失敗',
          background: Color(0xFFFF6B6B),
          foreground: Colors.white,
        );
      case SessionStatus.disconnected:
        return const _ChipSpec(
          label: '切断',
          background: Color(0xFF3A3A3A),
          foreground: Colors.white70,
        );
    }
  }
}

class _ChipSpec {
  final String label;
  final Color background;
  final Color foreground;

  const _ChipSpec({
    required this.label,
    required this.background,
    required this.foreground,
  });
}
