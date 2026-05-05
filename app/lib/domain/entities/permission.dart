// Domain enums: AppPermission and PermissionStatus
//
// Pure Dart only.

/// Application-level permission categories the onboarding flow asks about.
enum AppPermission { bluetooth, notification, backgroundPlayback }

/// Tri-state status for a single [AppPermission].
///
/// - [notRequested]: the user has not been prompted yet.
/// - [granted]: the OS dialog returned "allow".
/// - [denied]: the OS dialog returned "deny" (or the permission is revoked).
enum PermissionStatus { notRequested, granted, denied }
