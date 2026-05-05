// Domain service: OnboardingState
//
// Pure Dart only. Must NOT import flutter, flutter_riverpod, just_audio,
// go_router, or shared_preferences. This is the immutable snapshot type used
// throughout the onboarding/consent flow.

import 'package:proximity_music_app/domain/entities/consent_record.dart';
import 'package:proximity_music_app/domain/entities/onboarding_status.dart';
import 'package:proximity_music_app/domain/entities/onboarding_step.dart';
import 'package:proximity_music_app/domain/entities/permission.dart';

/// Snapshot of the user's onboarding progress, consent record, and the
/// per-permission status known so far.
///
/// Treat as immutable: use [copyWith] to derive a new state.
class OnboardingState {
  const OnboardingState({
    this.status = OnboardingStatus.notStarted,
    this.consent,
    this.permissions = const <AppPermission, PermissionStatus>{},
    this.currentStep = OnboardingStep.welcome,
  });

  final OnboardingStatus status;
  final ConsentRecord? consent;
  final Map<AppPermission, PermissionStatus> permissions;
  final OnboardingStep currentStep;

  /// Returns a new [OnboardingState] with the supplied overrides applied.
  ///
  /// Fields not passed explicitly are preserved from the current instance.
  OnboardingState copyWith({
    OnboardingStatus? status,
    ConsentRecord? consent,
    Map<AppPermission, PermissionStatus>? permissions,
    OnboardingStep? currentStep,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      consent: consent ?? this.consent,
      permissions: permissions ?? this.permissions,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingState &&
        other.status == status &&
        other.consent == consent &&
        _mapsEqual(other.permissions, permissions) &&
        other.currentStep == currentStep;
  }

  @override
  int get hashCode => Object.hash(
        status,
        consent,
        _mapHash(permissions),
        currentStep,
      );

  @override
  String toString() {
    return 'OnboardingState(status: $status, consent: $consent, '
        'permissions: $permissions, currentStep: $currentStep)';
  }

  static bool _mapsEqual(
    Map<AppPermission, PermissionStatus> a,
    Map<AppPermission, PermissionStatus> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<AppPermission, PermissionStatus> m) {
    var h = 0;
    for (final entry in m.entries) {
      h = h ^ Object.hash(entry.key, entry.value);
    }
    return h;
  }
}
