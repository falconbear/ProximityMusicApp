// Presentation controller: DiscoveryController.
//
// Pure Dart + dart:async. The Riverpod-aware factory in
// discovery_providers.dart wires a controller to the various
// providers via callback injection (Sprint 01 instinct
// callback_injection_remedy).

import 'dart:async';

import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/discovery_status.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/discovery_source.dart';

/// Drives a DiscoverySource and translates its events into
/// Presentation-layer state mutations through the supplied
/// callbacks. Owns no Riverpod or flutter imports.
class DiscoveryController {
  DiscoveryController({
    required DiscoverySource source,
    required void Function(Peer) onPeer,
    required void Function(BluetoothState) onBluetoothState,
    required void Function(DiscoveryStatus) onStatus,
    required DateTime Function() now,
    void Function(DateTime now, Duration ttl)? onPrune,
    Duration pruneInterval = const Duration(seconds: 10),
    Duration peerTtl = const Duration(seconds: 60),
  }) : _source = source,
       _onPeer = onPeer,
       _onBluetoothState = onBluetoothState,
       _onStatus = onStatus,
       _now = now,
       _onPrune = onPrune,
       _pruneInterval = pruneInterval,
       _peerTtl = peerTtl;

  final DiscoverySource _source;
  final void Function(Peer) _onPeer;
  final void Function(BluetoothState) _onBluetoothState;
  final void Function(DiscoveryStatus) _onStatus;
  final DateTime Function() _now;
  final void Function(DateTime now, Duration ttl)? _onPrune;
  final Duration _pruneInterval;
  final Duration _peerTtl;

  StreamSubscription<Peer>? _peerSub;
  StreamSubscription<BluetoothState>? _btSub;
  Timer? _pruneTimer;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _onStatus(DiscoveryStatus.starting);

    _peerSub = _source.peerStream.listen(_onPeer);
    _btSub = _source.bluetoothStateStream.listen((bt) {
      _onBluetoothState(bt);
      if (bt != BluetoothState.on) {
        _onStatus(DiscoveryStatus.error);
      }
    });

    await _source.start();

    _pruneTimer = Timer.periodic(_pruneInterval, (_) {
      _onPrune?.call(_now(), _peerTtl);
    });

    _onStatus(DiscoveryStatus.scanning);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    await _peerSub?.cancel();
    _peerSub = null;
    await _btSub?.cancel();
    _btSub = null;
    await _source.stop();
    _onStatus(DiscoveryStatus.stopped);
  }
}
