// Widget tests for the onboarding flow (Issue #2 RED phase).
//
// Targets future Presentation files:
//   package:proximity_music_app/presentation/state/onboarding_providers.dart
//   package:proximity_music_app/presentation/pages/onboarding/welcome_page.dart
//   package:proximity_music_app/presentation/pages/onboarding/consent_page.dart
//   plus the GoRouter redirect wiring in app.dart.
//
// Strategy: drive ProximityMusicApp through ProviderScope.overrides so that
// the provider default ('completed' for widget_test.dart compatibility) can
// be replaced with notStarted / a stale ConsentRecord and we can observe the
// resulting redirect behavior. Until GREEN ships these symbols every
// testWidgets case here will fail to compile or fail its assertions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/app.dart';
import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/services/onboarding_state.dart';
import 'package:proximity_music_app/presentation/state/onboarding_providers.dart';

OnboardingState _completedState({String acceptedVersion = 'v1'}) {
  return OnboardingState(
    status: OnboardingStatus.completed,
    consent: ConsentRecord(
      acceptedVersion: acceptedVersion,
      acceptedAt: DateTime.utc(2026, 1, 1),
    ),
    permissions: const {
      AppPermission.bluetooth: PermissionStatus.granted,
      AppPermission.notification: PermissionStatus.granted,
      AppPermission.backgroundPlayback: PermissionStatus.granted,
    },
    currentStep: OnboardingStep.welcome,
  );
}

const _notStartedState = OnboardingState(
  status: OnboardingStatus.notStarted,
  consent: null,
  permissions: <AppPermission, PermissionStatus>{},
  currentStep: OnboardingStep.welcome,
);

void main() {
  testWidgets(
    'ConsentPage normal mode: 同意して続行 button is disabled when checkbox '
    'is unchecked',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith((ref) => _notStartedState),
          ],
          child: const ProximityMusicApp(),
        ),
      );
      // Navigate directly to /onboarding/consent — initial route is welcome
      // when status==notStarted, so we drive there explicitly via the router.
      // The simplest approach in tests is to pump and then look up the
      // ConsentPage by navigating; but we can also seed the route via the
      // initial location. We rely on the (still-to-be-implemented) router to
      // expose '/onboarding/consent' as a reachable path.
      await tester.pumpAndSettle();

      // Walk through Welcome -> Privacy -> Permissions -> Consent by tapping
      // 'Next' three times. This validates the navigation chain in addition
      // to the disabled-button assertion.
      for (var i = 0; i < 3; i++) {
        final next = find.text('Next');
        expect(next, findsWidgets);
        await tester.tap(next.first);
        await tester.pumpAndSettle();
      }

      final continueButton = find.widgetWithText(
        ElevatedButton,
        '同意して続行',
      );
      expect(continueButton, findsOneWidget);
      final widget = tester.widget<ElevatedButton>(continueButton);
      expect(widget.onPressed, isNull,
          reason: 'Button must be disabled until the consent box is ticked');
    },
  );

  testWidgets(
    'ConsentPage normal mode: 同意して続行 button becomes enabled '
    'after the consent checkbox is ticked',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith((ref) => _notStartedState),
          ],
          child: const ProximityMusicApp(),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next').first);
        await tester.pumpAndSettle();
      }

      // Tick the checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final continueButton = find.widgetWithText(
        ElevatedButton,
        '同意して続行',
      );
      final widget = tester.widget<ElevatedButton>(continueButton);
      expect(widget.onPressed, isNotNull,
          reason: 'Button must be enabled once the consent box is ticked');
    },
  );

  testWidgets(
    'WelcomePage: notStarted override redirects to /onboarding/welcome '
    "and renders 'Next' button",
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith((ref) => _notStartedState),
          ],
          child: const ProximityMusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Welcome copy must be the first onboarding screen the user sees.
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    },
  );

  testWidgets(
    'Reconsent redirect: completed state with stale acceptedVersion (v0) '
    'lands the user directly on ConsentPage',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // status==completed but acceptedVersion mismatches
            // currentTermsVersion ('v1') => needsReconsent must trigger
            // redirect to /onboarding/consent.
            onboardingStateProvider.overrideWith(
              (ref) => _completedState(acceptedVersion: 'v0'),
            ),
          ],
          child: const ProximityMusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      // ConsentPage signals via the consent checkbox label '同意する'.
      expect(find.text('同意する'), findsWidgets);
    },
  );

  testWidgets(
    'Reconsent mode UI: shows 同意する + アプリを終了 buttons and hides '
    '戻る / スキップ',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider.overrideWith(
              (ref) => _completedState(acceptedVersion: 'v0'),
            ),
          ],
          child: const ProximityMusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Reconsent mode must expose the "Quit app" affordance.
      expect(find.text('アプリを終了'), findsOneWidget);
      // The consent label is present (checkbox + agree label both use it).
      expect(find.text('同意する'), findsWidgets);

      // 戻る / スキップ must be hidden in reconsent mode.
      expect(find.text('戻る'), findsNothing);
      expect(find.text('スキップ'), findsNothing);
    },
  );
}
