// Presentation page: PermissionsPage (onboarding step 3 of 4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';
import 'package:proximity_music_app/presentation/widgets/onboarding_navigation.dart';

class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(onboardingServiceProvider);
    final statuses = ref.watch(permissionStatusesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '必要な権限',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _PermissionRow(
                label: 'Bluetooth',
                description: '近接ユーザー検出に必須',
                status: statuses[AppPermission.bluetooth],
                onRequest: () =>
                    service.requestPermission(AppPermission.bluetooth),
              ),
              _PermissionRow(
                label: '通知',
                description: '受信通知のため',
                status: statuses[AppPermission.notification],
                onRequest: () =>
                    service.requestPermission(AppPermission.notification),
              ),
              _PermissionRow(
                label: 'バックグラウンド再生',
                description: '画面ロック中も再生を継続',
                status: statuses[AppPermission.backgroundPlayback],
                onRequest: () => service
                    .requestPermission(AppPermission.backgroundPlayback),
              ),
              const SizedBox(height: 32),
              OnboardingNavigation(
                onBack: () => context.go('/onboarding/privacy-battery'),
                onSkip: () async {
                  await service.advanceTo(OnboardingStep.consent);
                  if (context.mounted) {
                    context.go('/onboarding/consent');
                  }
                },
                onNext: () async {
                  await service.advanceTo(OnboardingStep.consent);
                  if (context.mounted) {
                    context.go('/onboarding/consent');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.description,
    required this.status,
    required this.onRequest,
  });

  final String label;
  final String description;
  final PermissionStatus? status;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Status: ${status ?? PermissionStatus.notRequested}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onRequest,
            child: const Text('要求'),
          ),
        ],
      ),
    );
  }
}
