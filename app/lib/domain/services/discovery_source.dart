// Domain interface: DiscoverySource.
//
// Pure Dart — abstracts whatever drives proximity peer detection
// (real BLE / Nearby in production, FakeDiscoverySource in tests
// and dev). Streams use only dart:async; no flutter import here.

import 'dart:async';

import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';

abstract class DiscoverySource {
  /// Begin emitting peers and bluetooth state events.
  Future<void> start();

  /// Stop emitting events. Idempotent — calling stop() on an already
  /// stopped source must not throw.
  Future<void> stop();

  /// Emits both new peers (first detection) and re-detections of
  /// already-known peers. Consumers (e.g. PeerRegistry) deduplicate.
  Stream<Peer> get peerStream;

  /// Emits whenever the OS Bluetooth radio state changes.
  Stream<BluetoothState> get bluetoothStateStream;

  /// One-shot read of the current Bluetooth state (used during
  /// initialization before the stream has emitted).
  Future<BluetoothState> currentBluetoothState();
}
