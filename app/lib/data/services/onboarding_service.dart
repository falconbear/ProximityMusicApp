// Data layer: OnboardingService
//
// Mirrors Sprint 01's AudioService pattern: only Domain types + injected
// callbacks. The Data layer must NOT import flutter / flutter_riverpod /
// flutter/material / go_router / shared_preferences. Persistence and OS
// permission access are abstracted through the four typedef callbacks below
// so Presentation can wire them to Riverpod and tests can fake them.

import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';
import 'package:proximity_music_app/domain/services/onboarding_state.dart';

/// Loads the persisted [OnboardingState], or returns a fresh `notStarted`
/// snapshot if nothing is persisted yet.
typedef LoadOnboardingState = OnboardingState Function();

/// Persists the given [OnboardingState] (synchronously from the caller's
/// perspective; backing store may be async internally).
typedef SaveOnboardingState = void Function(OnboardingState state);

/// Asks the OS for the given [AppPermission]. Stub implementations may simply
/// return [PermissionStatus.granted].
typedef RequestOsPermission = Future<PermissionStatus> Function(
  AppPermission permission,
);

/// Notification fired immediately after a mutating method has saved a new
/// [OnboardingState]. Pure-read methods (`load`, `needsReconsent`) do NOT
/// call this. Presentation hooks this callback up to update its Riverpod
/// state-provider so the UI re-renders.
typedef OnStateChanged = void Function(OnboardingState newState);

/// Application service orchestrating the onboarding + consent + permissions
/// flow. Stateless on its own; the source-of-truth state lives behind the
/// [loadState] / [saveState] callbacks (in-memory or persistent store).
class OnboardingService {
  OnboardingService({
    required this.loadState,
    required this.saveState,
    required this.requestOsPermission,
    required this.onStateChanged,
  });

  final LoadOnboardingState loadState;
  final SaveOnboardingState saveState;
  final RequestOsPermission requestOsPermission;
  final OnStateChanged onStateChanged;

  /// Returns the persisted state, or a fresh `notStarted` snapshot if none.
  ///
  /// Pure read; does not mutate or fire [onStateChanged].
  OnboardingState load() => loadState();

  /// Advances `currentStep` to [step] and saves.
  ///
  /// Status moves from `notStarted` to `inProgress` the first time the user
  /// leaves the Welcome screen.
  Future<void> advanceTo(OnboardingStep step) async {
    final current = loadState();
    final nextStatus = current.status == OnboardingStatus.completed
        ? current.status
        : OnboardingStatus.inProgress;
    final next = current.copyWith(
      currentStep: step,
      status: nextStatus,
    );
    saveState(next);
    onStateChanged(next);
  }

  /// Records the user's consent for the given terms [version] (typically
  /// [currentTermsVersion]) at `DateTime.now().toUtc()` and saves.
  Future<void> recordConsent(String version) async {
    final current = loadState();
    final next = current.copyWith(
      consent: ConsentRecord(
        acceptedVersion: version,
        acceptedAt: DateTime.now().toUtc(),
      ),
    );
    saveState(next);
    onStateChanged(next);
  }

  /// Calls the injected [requestOsPermission] for [permission] and stores the
  /// resulting [PermissionStatus] under that key in the state's `permissions`
  /// map. Returns the newly recorded status.
  Future<PermissionStatus> requestPermission(AppPermission permission) async {
    final result = await requestOsPermission(permission);
    final current = loadState();
    final updated = Map<AppPermission, PermissionStatus>.from(
      current.permissions,
    )..[permission] = result;
    final next = current.copyWith(permissions: updated);
    saveState(next);
    onStateChanged(next);
    return result;
  }

  /// Marks onboarding as completed and saves.
  Future<void> complete() async {
    final current = loadState();
    final next = current.copyWith(status: OnboardingStatus.completed);
    saveState(next);
    onStateChanged(next);
  }

  /// Returns `true` iff the persisted [ConsentRecord] is missing or its
  /// `acceptedVersion` differs from the supplied [currentAppVersion]
  /// (typically [currentTermsVersion]).
  ///
  /// Pure read; does not mutate or fire [onStateChanged].
  bool needsReconsent(String currentAppVersion) {
    final state = loadState();
    final consent = state.consent;
    if (consent == null) return true;
    return consent.acceptedVersion != currentAppVersion;
  }
}
