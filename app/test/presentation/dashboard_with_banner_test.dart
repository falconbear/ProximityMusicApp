// Widget test for DashboardPage with PermissionDeniedBanner present
// (Issue #2 RED phase, spec feature 2 acceptance criterion 5).
//
// Targets future Presentation files:
//   package:proximity_music_app/presentation/widgets/permission_denied_banner.dart
//   plus the DashboardPage modifications to render the banner when
//   bluetooth permission status is denied.
//
// Strategy: override onboardingStateProvider with a 'completed but bluetooth
// denied' state, pump ProximityMusicApp, then verify the banner is visible
// AND that Discovery toggle + Player navigation continue to work normally.
// Until GREEN this whole file fails to compile (missing symbols).

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
import 'package:proximity_music_app/presentation/widgets/permission_denied_banner.dart';

void main() {
  testWidgets(
    'Banner visible (bluetooth denied) does not block Discovery toggle '
    'or Player navigation',
    (tester) async {
      final completedButBluetoothDenied = OnboardingState(
        status: OnboardingStatus.completed,
        consent: ConsentRecord(
          acceptedVersion: 'v1',
          acceptedAt: DateTime.utc(2026, 1, 1),
        ),
        permissions: const {
          AppPermission.bluetooth: PermissionStatus.denied,
          AppPermission.notification: PermissionStatus.granted,
          AppPermission.backgroundPlayback: PermissionStatus.granted,
        },
        currentStep: OnboardingStep.welcome,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingStateProvider
                .overrideWith((ref) => completedButBluetoothDenied),
          ],
          child: const ProximityMusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Banner is rendered while permission is denied.
      expect(find.byType(PermissionDeniedBanner), findsOneWidget);
      expect(
        find.text('近接機能は無効です。設定から有効化できます'),
        findsOneWidget,
      );

      // Discovery toggle must still flip from Paused -> Active.
      expect(find.text('Discovery Paused'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Discovery Active'), findsOneWidget);

      // Player navigation must still work via the queue_music icon.
      await tester.tap(find.byIcon(Icons.queue_music));
      await tester.pumpAndSettle();
      expect(find.text('Player'), findsOneWidget);
    },
  );
}
