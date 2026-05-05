// Domain unit tests for OnboardingState (Issue #2 RED phase).
//
// These tests target the future Domain types/files which do not exist yet:
//   - package:proximity_music_app/domain/entities/onboarding_status.dart
//   - package:proximity_music_app/domain/entities/consent_record.dart
//   - package:proximity_music_app/domain/entities/permission.dart
//   - package:proximity_music_app/domain/entities/onboarding_step.dart
//   - package:proximity_music_app/domain/services/onboarding_state.dart
//
// Until Phase 3.2 GREEN implements these types, every test in this file MUST
// fail (compile error counts as failure under flutter_test). This is the
// expected RED state.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/services/onboarding_state.dart';

void main() {
  group('OnboardingState entity', () {
    test('default constructor yields notStarted/null/empty/welcome', () {
      const state = OnboardingState();

      expect(state.status, OnboardingStatus.notStarted);
      expect(state.consent, isNull);
      expect(state.permissions, isEmpty);
      expect(state.currentStep, OnboardingStep.welcome);
    });

    test('copyWith preserves untouched fields and overrides the targeted one',
        () {
      const original = OnboardingState();

      final next = original.copyWith(status: OnboardingStatus.completed);

      expect(next.status, OnboardingStatus.completed);
      // Other fields must not change.
      expect(next.consent, original.consent);
      expect(next.permissions, original.permissions);
      expect(next.currentStep, original.currentStep);
    });

    test('equality is true for two instances with identical fields', () {
      final consent = ConsentRecord(
        acceptedVersion: 'v1',
        acceptedAt: DateTime.utc(2026, 1, 1),
      );
      final a = OnboardingState(
        status: OnboardingStatus.inProgress,
        consent: consent,
        permissions: const {
          AppPermission.bluetooth: PermissionStatus.granted,
        },
        currentStep: OnboardingStep.consent,
      );
      final b = OnboardingState(
        status: OnboardingStatus.inProgress,
        consent: ConsentRecord(
          acceptedVersion: 'v1',
          acceptedAt: DateTime.utc(2026, 1, 1),
        ),
        permissions: const {
          AppPermission.bluetooth: PermissionStatus.granted,
        },
        currentStep: OnboardingStep.consent,
      );

      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality is false when status differs', () {
      const a = OnboardingState();
      const b = OnboardingState(status: OnboardingStatus.completed);

      expect(a == b, isFalse);
    });

    test('toString contains both status and currentStep', () {
      const state = OnboardingState(
        status: OnboardingStatus.inProgress,
        currentStep: OnboardingStep.permissions,
      );

      final str = state.toString();
      expect(str, contains('OnboardingState'));
      expect(str, contains('inProgress'));
      expect(str, contains('permissions'));
    });

    test('copyWith({currentStep: ...}) advances step while keeping status', () {
      const original = OnboardingState(
        status: OnboardingStatus.inProgress,
        currentStep: OnboardingStep.welcome,
      );

      final next = original.copyWith(
        currentStep: OnboardingStep.privacyAndBattery,
      );

      expect(next.status, OnboardingStatus.inProgress);
      expect(next.currentStep, OnboardingStep.privacyAndBattery);
    });
  });
}
