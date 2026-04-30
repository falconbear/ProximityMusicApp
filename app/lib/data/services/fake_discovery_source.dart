// Data service: FakeDiscoverySource.
//
// Test / dev implementation of DiscoverySource. Cycles through a
// caller-provided list of Peers on a Timer.periodic and exposes a
// setBluetoothState() test hook. Pure Dart — no flutter, no pigeon.

import 'dart:async';

import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/discovery_source.dart';

class FakeDiscoverySource implements DiscoverySource {
  FakeDiscoverySource({
    required BluetoothState initialBluetoothState,
    required this.peers,
    required this.interval,
  }) : _btState = initialBluetoothState;

  final List<Peer> peers;
  final Duration interval;

  BluetoothState _btState;
  int _cursor = 0;
  Timer? _timer;

  final StreamController<Peer> _peerCtl = StreamController<Peer>.broadcast();
  final StreamController<BluetoothState> _btCtl =
      StreamController<BluetoothState>.broadcast();

  @override
  Stream<Peer> get peerStream => _peerCtl.stream;

  @override
  Stream<BluetoothState> get bluetoothStateStream => _btCtl.stream;

  @override
  Future<BluetoothState> currentBluetoothState() async => _btState;

  @override
  Future<void> start() async {
    _timer?.cancel();
    if (peers.isEmpty) {
      // Nothing to emit — start() is still considered successful.
      return;
    }
    _cursor = 0;
    _timer = Timer.periodic(interval, (_) {
      if (_peerCtl.isClosed) return;
      final p = peers[_cursor % peers.length];
      _peerCtl.add(p);
      _cursor++;
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Test hook — pushes a new Bluetooth state into the stream and
  /// updates the value returned by currentBluetoothState().
  void setBluetoothState(BluetoothState state) {
    _btState = state;
    if (!_btCtl.isClosed) {
      _btCtl.add(state);
    }
  }

  /// Release stream resources. Tests that create many sources in a
  /// loop should call this to avoid leaks.
  Future<void> dispose() async {
    await stop();
    await _peerCtl.close();
    await _btCtl.close();
  }
}
