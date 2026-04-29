// Presentation state providers for onboarding / permissions / consent.
//
// Wires the Data layer's OnboardingService into Riverpod and exposes
// onboardingStateProvider, the StateNotifier-backed snapshot the rest of the
// presentation layer reads.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/data/services/onboarding_service.dart';
import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/services/onboarding_state.dart';

/// Default [OnboardingState] used when no override is supplied.
///
/// Defaults to **completed** so that existing widget_test.dart cases
/// (`pumpWidget(const ProviderScope(child: ProximityMusicApp()))` without
/// overrides) skip onboarding and land directly on the dashboard.
/// `main.dart` overrides this with a `notStarted` state on real device
/// launches so first-run users see the Welcome page.
OnboardingState _defaultOnboardingState() {
  return OnboardingState(
    status: OnboardingStatus.completed,
    consent: ConsentRecord(
      acceptedVersion: currentTermsVersion,
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

/// Provides the current [OnboardingState] snapshot.
///
/// This is a [StateProvider] so tests can do
/// `onboardingStateProvider.overrideWith((ref) => OnboardingState(...))`
/// to seed any initial state. The runtime app overrides this in `main.dart`
/// with a `notStarted` state so first-run users land on Welcome; the default
/// (no override) is `completed` so existing widget_test.dart cases skip
/// onboarding and load Dashboard directly.
final onboardingStateProvider = StateProvider<OnboardingState>(
  (ref) => _defaultOnboardingState(),
);

/// In-memory persistence stub for Sprint 02. A real backend (SharedPreferences,
/// Hive, ...) will arrive in a later Sprint. Tests + the runtime app share
/// this single in-memory cell within a ProviderScope.
class _InMemoryOnboardingPersistence {
  OnboardingState? _stored;

  OnboardingState load() => _stored ?? const OnboardingState();
  void save(OnboardingState state) => _stored = state;
}

final _onboardingPersistenceProvider =
    Provider<_InMemoryOnboardingPersistence>((ref) {
  return _InMemoryOnboardingPersistence();
});

/// Stub OS permission requester. Defaults to "always grant" — tests override
/// with a denied responder via `requestOsPermissionProvider.overrideWithValue`.
/// The real OS permission API integration arrives in Issue #3.
final requestOsPermissionProvider = Provider<RequestOsPermission>(
  (ref) => (permission) async => PermissionStatus.granted,
);

/// Application service for onboarding + permissions + consent.
///
/// `OnStateChanged` is wired so that any mutation inside the service is
/// reflected back into [onboardingStateProvider] (Sprint 01 callback-injection
/// regimen: Data layer stays free of Presentation imports).
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final persistence = ref.read(_onboardingPersistenceProvider);
  return OnboardingService(
    loadState: () {
      final stored = persistence.load();
      // Prefer the live state-provider value if it has been seeded by
      // Riverpod overrides (test mode); otherwise fall back to persistence.
      final live = ref.read(onboardingStateProvider);
      return _stateIsEmpty(stored) ? live : stored;
    },
    saveState: (state) {
      persistence.save(state);
    },
    requestOsPermission: ref.read(requestOsPermissionProvider),
    onStateChanged: (newState) {
      ref.read(onboardingStateProvider.notifier).state = newState;
    },
  );
});

bool _stateIsEmpty(OnboardingState s) {
  return s.status == OnboardingStatus.notStarted &&
      s.consent == null &&
      s.permissions.isEmpty &&
      s.currentStep == OnboardingStep.welcome;
}

/// Convenience: read the per-permission status map.
final permissionStatusesProvider =
    Provider<Map<AppPermission, PermissionStatus>>((ref) {
  return ref.watch(onboardingStateProvider).permissions;
});
