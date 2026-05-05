// Domain enum: OnboardingStatus
//
// Pure Dart only. Must NOT import flutter, flutter_riverpod, just_audio, or
// go_router (Domain layer is the inner-most ring).

/// High-level onboarding progress for the current user.
///
/// - [notStarted]: first launch, no onboarding screens have been completed.
/// - [inProgress]: user is partway through the 4-step onboarding flow.
/// - [completed]: user has finished onboarding and is on the main app.
enum OnboardingStatus { notStarted, inProgress, completed }
