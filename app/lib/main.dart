// Application entry point.
//
// Re-exports `app.dart` so that existing imports of
// `package:proximity_music_app/main.dart` (e.g. widget_test.dart) still
// resolve `ProximityMusicApp`.
//
// On real-device launches we override `onboardingStateProvider` with a
// `notStarted` snapshot so the GoRouter redirect lands first-run users on
// the Welcome page (spec feature 2 acceptance criterion 1). The provider's
// default value is `completed` purely to keep widget_test.dart cases — which
// pumpWidget without overrides — landing on Dashboard. This split is
// documented in the contract for Issue #2.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/app.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/services/onboarding_state.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';

export 'package:proximity_music_app/app.dart' show ProximityMusicApp;

void main() {
  runApp(
    ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith(
          (ref) => const OnboardingState(
            status: OnboardingStatus.notStarted,
            consent: null,
            permissions: <AppPermission, PermissionStatus>{},
            currentStep: OnboardingStep.welcome,
          ),
        ),
      ],
      child: const ProximityMusicApp(),
    ),
  );
}
