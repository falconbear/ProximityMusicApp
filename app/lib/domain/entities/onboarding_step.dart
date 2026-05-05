// Domain enum: OnboardingStep
//
// Pure Dart only.

/// Steps of the 4-screen onboarding flow.
///
/// Order: welcome -> privacyAndBattery -> permissions -> consent -> (main app).
enum OnboardingStep { welcome, privacyAndBattery, permissions, consent }
