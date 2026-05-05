// Presentation page: WelcomePage (onboarding step 1 of 4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';
import 'package:proximity_music_app/presentation/widgets/onboarding_navigation.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ProximityMusic は、近くにいる人と音楽を共有・再生する'
                'アプリです。',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              OnboardingNavigation(
                onNext: () async {
                  await ref
                      .read(onboardingServiceProvider)
                      .advanceTo(OnboardingStep.privacyAndBattery);
                  if (context.mounted) {
                    context.go('/onboarding/privacy-battery');
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
