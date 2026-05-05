// Presentation page: PrivacyBatteryPage (onboarding step 2 of 4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';
import 'package:proximity_music_app/presentation/widgets/onboarding_navigation.dart';

class PrivacyBatteryPage extends ConsumerWidget {
  const PrivacyBatteryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Battery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'プライバシーと電池影響',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '・近接検知のため Bluetooth を継続的に利用します。\n'
                '・電池消費に影響するため、必要なときだけ Discovery を'
                'オンにすることを推奨します。\n'
                '・共有する楽曲は権利クリアなものに限定してください。',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              OnboardingNavigation(
                onBack: () => context.go('/onboarding/welcome'),
                onNext: () async {
                  await ref
                      .read(onboardingServiceProvider)
                      .advanceTo(OnboardingStep.permissions);
                  if (context.mounted) {
                    context.go('/onboarding/permissions');
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
