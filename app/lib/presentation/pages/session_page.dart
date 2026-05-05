// SessionPage — anonymous session dashboard.
//
// Displays the current local SessionId fingerprint, an immediate ID-rotate
// button (今すぐ更新), the list of active per-peer sessions, and an empty
// state for when no sessions exist.
//
// Layout uses SingleChildScrollView + a shrinkWrap ListView so the page
// renders cleanly inside the 800x600 widget-test viewport without RenderFlex
// overflow (Sprint 01 instinct feedback_flutter_test_viewport_overflow).
//
// AI-Slop anti-directive: no asset/network image widgets.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';
import 'package:proximity_music_app/presentation/state/session_providers.dart';
import 'package:proximity_music_app/presentation/widgets/session_status_chip.dart';

class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(currentSessionIdProvider);
    final allSessions = ref.watch(sessionsProvider);
    final activeSessions = allSessions
        .where((s) => s.status != SessionStatus.disconnected)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FingerprintCard(
                fingerprint: currentId.fingerprint,
                issuedAt: currentId.issuedAt,
                onRotate: () => _rotate(context, ref),
              ),
              const SizedBox(height: 16),
              const Text(
                'Active sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (activeSessions.isEmpty)
                const _EmptySessions()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeSessions.length,
                  itemBuilder: (context, index) {
                    return _SessionTile(session: activeSessions[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _rotate(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sessionControllerProvider);
    controller.rotateNow(DateTime.now().toUtc(), Random.secure());
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(content: Text('匿名 ID をローテートしました')),
    );
  }
}

class _FingerprintCard extends StatelessWidget {
  const _FingerprintCard({
    required this.fingerprint,
    required this.issuedAt,
    required this.onRotate,
  });

  final String fingerprint;
  final DateTime issuedAt;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: $fingerprint',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '最終更新: ${issuedAt.toIso8601String()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onRotate,
                child: const Text('今すぐ更新'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '近くのピアと未接続です。Discover 画面からピアを選んで接続してください',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortPeer(session.peerId),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                SessionStatusChip(session.status),
              ],
            ),
          ),
          if (session.status == SessionStatus.failed)
            TextButton(
              onPressed: () {
                ref
                    .read(sessionControllerProvider)
                    .retrySession(session.peerId);
              },
              child: const Text('再試行'),
            ),
        ],
      ),
    );
  }

  String _shortPeer(String peerId) {
    if (peerId.length <= 16) return peerId;
    return '${peerId.substring(0, 8)}…${peerId.substring(peerId.length - 4)}';
  }
}
