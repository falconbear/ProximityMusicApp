// Presentation unit tests for DiscoveryController (Issue #3 — RED phase).
//
// DiscoveryController is constructed with a DiscoverySource + four
// callbacks (peer-registry-update, bluetooth-state-update,
// discovery-status-update, now-time-getter). It should:
//   - drive DiscoveryStatus through starting → scanning on start()
//   - upsert peers received from the source into the registry
//   - flip DiscoveryStatus to error when BluetoothState != on

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/fake_discovery_source.dart';
import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/discovery_status.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/peer_registry.dart';
import 'package:proximity_music_app/presentation/state/discovery_controller.dart';

void main() {
  Peer makePeer(String id) =>
      Peer(id: id, lastSeenAt: DateTime.utc(2026, 5, 1), avatarSeed: 1);

  DiscoveryController buildController({
    required FakeDiscoverySource source,
    required PeerRegistry registry,
    required List<DiscoveryStatus> statusLog,
    required List<BluetoothState> btLog,
    DateTime Function()? now,
  }) {
    return DiscoveryController(
      source: source,
      onPeer: registry.upsert,
      onBluetoothState: btLog.add,
      onStatus: statusLog.add,
      now: now ?? () => DateTime.utc(2026, 5, 1, 12, 0, 0),
    );
  }

  group('DiscoveryController', () {
    test('start() transitions status from starting to scanning', () {
      fakeAsync((async) {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.on,
          peers: const [],
          interval: const Duration(seconds: 5),
        );
        final registry = PeerRegistry();
        final statusLog = <DiscoveryStatus>[];
        final btLog = <BluetoothState>[];

        final controller = buildController(
          source: source,
          registry: registry,
          statusLog: statusLog,
          btLog: btLog,
        );

        controller.start();
        async.elapse(const Duration(milliseconds: 100));

        expect(statusLog, contains(DiscoveryStatus.starting));
        expect(statusLog.last, DiscoveryStatus.scanning);

        controller.stop();
      });
    });

    test('peer emission upserts into the PeerRegistry', () {
      fakeAsync((async) {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.on,
          peers: [makePeer('p1'), makePeer('p2')],
          interval: const Duration(seconds: 1),
        );
        final registry = PeerRegistry();
        final statusLog = <DiscoveryStatus>[];
        final btLog = <BluetoothState>[];

        final controller = buildController(
          source: source,
          registry: registry,
          statusLog: statusLog,
          btLog: btLog,
        );

        controller.start();
        async.elapse(const Duration(seconds: 3));

        expect(registry.peers, isNotEmpty);

        controller.stop();
      });
    });

    test('BluetoothState.off transitions status to error', () {
      fakeAsync((async) {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.on,
          peers: const [],
          interval: const Duration(seconds: 5),
        );
        final registry = PeerRegistry();
        final statusLog = <DiscoveryStatus>[];
        final btLog = <BluetoothState>[];

        final controller = buildController(
          source: source,
          registry: registry,
          statusLog: statusLog,
          btLog: btLog,
        );

        controller.start();
        async.elapse(const Duration(milliseconds: 100));
        source.setBluetoothState(BluetoothState.off);
        async.elapse(const Duration(milliseconds: 100));

        expect(statusLog, contains(DiscoveryStatus.error));

        controller.stop();
      });
    });
  });
}
