// Presentation Riverpod providers for proximity discovery (Issue #3).
//
// Callers may override `discoverySourceProvider` (e.g. in tests or
// for production native wiring) without touching this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/data/services/fake_discovery_source.dart';
import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/discovery_status.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/discovery_source.dart';
import 'package:proximity_music_app/domain/services/peer_registry.dart';
import 'package:proximity_music_app/presentation/state/discovery_controller.dart';

/// Default demo peers used by the in-app FakeDiscoverySource so a
/// freshly-launched app has visible activity on the Discover screen.
List<Peer> _demoPeers() {
  final now = DateTime.now().toUtc();
  return [
    Peer(id: 'demo-aaa00001', lastSeenAt: now, avatarSeed: 7),
    Peer(id: 'demo-bbb00002', lastSeenAt: now, avatarSeed: 13),
    Peer(id: 'demo-ccc00003', lastSeenAt: now, avatarSeed: 21),
  ];
}

/// The active DiscoverySource. Override with NativeDiscoverySource()
/// in production via ProviderScope.overrides.
final discoverySourceProvider = Provider<DiscoverySource>((ref) {
  final source = FakeDiscoverySource(
    initialBluetoothState: BluetoothState.on,
    peers: _demoPeers(),
    interval: const Duration(seconds: 5),
  );
  return source;
});

/// Mutable PeerRegistry. Reading `.peers` returns the current
/// snapshot; consumers should rebuild when the registry mutates by
/// also watching peersProvider.
final peerRegistryProvider = Provider<PeerRegistry>((ref) {
  return PeerRegistry();
});

final discoveryStatusProvider = StateProvider<DiscoveryStatus>(
  (ref) => DiscoveryStatus.idle,
);

final bluetoothStateProvider = StateProvider<BluetoothState>(
  (ref) => BluetoothState.unknown,
);

/// Controller wired to the providers via callback injection.
final discoveryControllerProvider = Provider<DiscoveryController>((ref) {
  final source = ref.watch(discoverySourceProvider);
  final registry = ref.watch(peerRegistryProvider);

  final controller = DiscoveryController(
    source: source,
    onPeer: (peer) {
      registry.upsert(peer);
      // Bump peersProvider listeners by re-emitting the same registry
      // reference through a counter. We use a separate tick provider
      // so consumers of peersProvider rebuild.
      ref.read(_peerTickProvider.notifier).state++;
    },
    onBluetoothState: (bt) {
      ref.read(bluetoothStateProvider.notifier).state = bt;
    },
    onStatus: (status) {
      ref.read(discoveryStatusProvider.notifier).state = status;
    },
    onPrune: (now, ttl) {
      registry.prune(now, ttl);
      ref.read(_peerTickProvider.notifier).state++;
    },
    now: () => DateTime.now().toUtc(),
  );
  return controller;
});

/// Internal tick used to invalidate peersProvider when the registry
/// mutates (PeerRegistry is a mutable container, so we cannot rely on
/// reference identity).
final _peerTickProvider = StateProvider<int>((ref) => 0);

/// Snapshot of all currently-known peers. Rebuilds whenever the
/// registry is mutated.
final peersProvider = Provider<List<Peer>>((ref) {
  // ignore: unused_local_variable
  final tick = ref.watch(_peerTickProvider);
  return ref.watch(peerRegistryProvider).peers;
});
