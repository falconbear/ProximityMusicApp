// Data unit tests for OnboardingService (Issue #2 RED phase).
//
// Targets future Data file:
//   package:proximity_music_app/data/services/onboarding_service.dart
//
// OnboardingService is constructed with four typedef callbacks injected from
// Presentation (LoadOnboardingState / SaveOnboardingState / RequestOsPermission
// / OnStateChanged). The Data layer itself stays free of Riverpod / Flutter /
// go_router imports (Sprint 01 callback-injection regimen).
//
// Every test here must fail until GREEN implements OnboardingService.

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/onboarding_service.dart';
import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/services/onboarding_state.dart';

/// Tiny in-memory persistence harness used to drive OnboardingService
/// in tests. It captures the state it was last asked to save so each test
/// can assert on it directly.
class _Persistence {
  OnboardingState? stored;
  int saveCalls = 0;

  OnboardingState load() => stored ?? const OnboardingState();

  void save(OnboardingState state) {
    stored = state;
    saveCalls++;
  }
}

OnboardingService _buildService({
  _Persistence? persistence,
  Future<PermissionStatus> Function(AppPermission)? requestOsPermission,
  void Function(OnboardingState)? onStateChanged,
}) {
  final p = persistence ?? _Persistence();
  return OnboardingService(
    loadState: p.load,
    saveState: p.save,
    requestOsPermission:
        requestOsPermission ?? ((perm) async => PermissionStatus.granted),
    onStateChanged: onStateChanged ?? ((_) {}),
  );
}

void main() {
  group('OnboardingService', () {
    test('load() returns notStarted when nothing was persisted', () {
      final service = _buildService();

      final state = service.load();

      expect(state.status, OnboardingStatus.notStarted);
      expect(state.consent, isNull);
      expect(state.permissions, isEmpty);
      expect(state.currentStep, OnboardingStep.welcome);
    });

    test(
      'advanceTo(privacyAndBattery) updates currentStep and saves',
      () async {
        final p = _Persistence();
        final service = _buildService(persistence: p);

        await service.advanceTo(OnboardingStep.privacyAndBattery);

        expect(p.stored, isNotNull);
        expect(p.stored!.currentStep, OnboardingStep.privacyAndBattery);
        expect(p.saveCalls, 1);
      },
    );

    test(
      "recordConsent('v1') stores ConsentRecord with acceptedVersion='v1'",
      () async {
        final p = _Persistence();
        final service = _buildService(persistence: p);

        await service.recordConsent('v1');

        expect(p.stored, isNotNull);
        expect(p.stored!.consent, isNotNull);
        expect(p.stored!.consent!.acceptedVersion, 'v1');
        // Saved exactly once for this single mutation.
        expect(p.saveCalls, 1);
      },
    );

    test(
      'requestPermission(bluetooth) calls injected RequestOsPermission and '
      'stores the result in permissions',
      () async {
        final p = _Persistence();
        var calls = 0;
        AppPermission? captured;
        final service = _buildService(
          persistence: p,
          requestOsPermission: (perm) async {
            calls++;
            captured = perm;
            return PermissionStatus.denied;
          },
        );

        final result =
            await service.requestPermission(AppPermission.bluetooth);

        expect(calls, 1);
        expect(captured, AppPermission.bluetooth);
        expect(result, PermissionStatus.denied);
        expect(
          p.stored!.permissions[AppPermission.bluetooth],
          PermissionStatus.denied,
        );
      },
    );

    test('complete() flips status to completed and saves', () async {
      final p = _Persistence();
      final service = _buildService(persistence: p);

      await service.complete();

      expect(p.stored, isNotNull);
      expect(p.stored!.status, OnboardingStatus.completed);
    });

    test(
      "needsReconsent('v2') is true when stored consent is on 'v1'",
      () async {
        final p = _Persistence();
        // Seed persisted state with consent on v1.
        p.stored = OnboardingState(
          status: OnboardingStatus.completed,
          consent: ConsentRecord(
            acceptedVersion: 'v1',
            acceptedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        final service = _buildService(persistence: p);

        expect(service.needsReconsent('v2'), isTrue);
        expect(service.needsReconsent('v1'), isFalse);
      },
    );

    test(
      'OnStateChanged is invoked exactly once per mutating method '
      'with the new full OnboardingState as its argument',
      () async {
        final p = _Persistence();
        var callCount = 0;
        OnboardingState? captured;
        final service = _buildService(
          persistence: p,
          onStateChanged: (s) {
            callCount++;
            captured = s;
          },
        );

        await service.advanceTo(OnboardingStep.privacyAndBattery);

        expect(callCount, 1);
        expect(captured, isNotNull);
        expect(captured!.currentStep, OnboardingStep.privacyAndBattery);

        await service.recordConsent('v1');

        expect(callCount, 2);
        expect(captured!.consent, isNotNull);
        expect(captured!.consent!.acceptedVersion, 'v1');
      },
    );

    test(
      'OnStateChanged is NOT invoked by load() or needsReconsent() '
      '(non-mutating methods)',
      () {
        final p = _Persistence();
        p.stored = OnboardingState(
          status: OnboardingStatus.completed,
          consent: ConsentRecord(
            acceptedVersion: 'v1',
            acceptedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        var callCount = 0;
        final service = _buildService(
          persistence: p,
          onStateChanged: (_) => callCount++,
        );

        // Pure reads: must not notify.
        service.load();
        service.needsReconsent('v2');
        service.needsReconsent('v1');

        expect(callCount, 0);
      },
    );
  });
}
