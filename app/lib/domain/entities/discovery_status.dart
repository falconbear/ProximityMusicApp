// Domain enum: DiscoveryStatus.
//
// Pure Dart — the Presentation-facing lifecycle of a discovery
// session. The DiscoveryController in the Presentation layer drives
// this state in response to events from a DiscoverySource.

enum DiscoveryStatus {
  idle,
  starting,
  scanning,
  stopped,
  error,
}
