// Domain enum: BluetoothState.
//
// Pure Dart — represents the OS Bluetooth radio state as observed from
// the Discovery layer. Native sources (iOS / Android) translate
// platform-specific state codes into this enum before crossing the
// Platform Channel boundary.

enum BluetoothState { unknown, off, on, unauthorized }
