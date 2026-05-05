// Domain unit test for the DiscoverySource abstract interface
// (Issue #3 — RED phase).
//
// Verifies that the abstract type is implementable in pure Dart and
// exposes the contractual streams. Compile error here means the domain
// type is missing.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/discovery_source.dart';

class _MockDiscoverySource implements DiscoverySource {
  final _peers = StreamController<Peer>.broadcast();
  final _bt = StreamController<BluetoothState>.broadcast();

  @override
  Stream<Peer> get peerStream => _peers.stream;

  @override
  Stream<BluetoothState> get bluetoothStateStream => _bt.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<BluetoothState> currentBluetoothState() async => BluetoothState.on;
}

void main() {
  group('DiscoverySource', () {
    test('a pure-Dart class can implement DiscoverySource', () {
      final mock = _MockDiscoverySource();
      // Type-level conformance — the class is recognised as a
      // DiscoverySource at runtime.
      expect(mock, isA<DiscoverySource>());

      // Streams must be StreamController-backed (not null).
      expect(mock.peerStream, isA<Stream<Peer>>());
      expect(mock.bluetoothStateStream, isA<Stream<BluetoothState>>());
    });
  });
}
