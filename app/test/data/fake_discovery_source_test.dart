// Data unit tests for FakeDiscoverySource (Issue #3 — RED phase).
//
// Validates that the fake correctly simulates a periodic peer stream
// and a controllable BluetoothState stream so that Presentation tests
// can drive deterministic Discovery flows without real BLE.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/fake_discovery_source.dart';
import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';

void main() {
  Peer makePeer(String id) =>
      Peer(id: id, lastSeenAt: DateTime.utc(2026, 5, 1), avatarSeed: 1);

  group('FakeDiscoverySource', () {
    test('start() emits peers from the seeded list at the given interval', () {
      fakeAsync((async) {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.on,
          peers: [makePeer('p1'), makePeer('p2')],
          interval: const Duration(seconds: 5),
        );

        final received = <Peer>[];
        final sub = source.peerStream.listen(received.add);

        source.start();
        async.elapse(const Duration(seconds: 5));
        expect(received.length, greaterThanOrEqualTo(1));
        expect(received.first.id, 'p1');

        sub.cancel();
        source.stop();
      });
    });

    test('stop() halts new peer emissions', () {
      fakeAsync((async) {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.on,
          peers: [makePeer('p1'), makePeer('p2'), makePeer('p3')],
          interval: const Duration(seconds: 1),
        );

        final received = <Peer>[];
        final sub = source.peerStream.listen(received.add);

        source.start();
        async.elapse(const Duration(seconds: 2));
        final countAfterTwoSeconds = received.length;
        expect(countAfterTwoSeconds, greaterThanOrEqualTo(1));

        source.stop();
        async.elapse(const Duration(seconds: 5));
        // No new peers after stop.
        expect(received.length, countAfterTwoSeconds);

        sub.cancel();
      });
    });

    test('setBluetoothState emits the new value on bluetoothStateStream', () {
      fakeAsync((async) {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.on,
          peers: const [],
          interval: const Duration(seconds: 5),
        );

        final received = <BluetoothState>[];
        final sub = source.bluetoothStateStream.listen(received.add);

        source.setBluetoothState(BluetoothState.off);
        async.flushMicrotasks();

        expect(received, contains(BluetoothState.off));
        sub.cancel();
      });
    });

    test(
      'currentBluetoothState returns the constructor-provided value',
      () async {
        final source = FakeDiscoverySource(
          initialBluetoothState: BluetoothState.unauthorized,
          peers: const [],
          interval: const Duration(seconds: 5),
        );

        expect(
          await source.currentBluetoothState(),
          BluetoothState.unauthorized,
        );
      },
    );
  });
}
