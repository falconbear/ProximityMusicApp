// Presentation widget: PermissionDeniedBanner
//
// Inline banner shown above the Dashboard when the bluetooth permission is
// denied. Tapping the action navigates the user to the Settings page where
// they can re-request permission.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PermissionDeniedBanner extends StatelessWidget {
  const PermissionDeniedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3a1f1f),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '近接機能は無効です。設定から有効化できます',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/settings'),
              child: const Text('設定'),
            ),
          ],
        ),
      ),
    );
  }
}
