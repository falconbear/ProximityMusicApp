// Presentation page: SettingsPage (placeholder for Sprint 02).
//
// Sprint 02 only ships the bare minimum required by spec feature 2 acceptance
// criterion 6: a 「権限を再要求」 button on a Settings screen. The full
// settings UI (issue #10) lands later. The button taps OnboardingService.
// requestPermission(bluetooth), which goes through the injected
// RequestOsPermission stub.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '権限',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(onboardingServiceProvider)
                      .requestPermission(AppPermission.bluetooth);
                },
                child: const Text('権限を再要求'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
