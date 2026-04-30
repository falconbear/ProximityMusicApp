// Data service: NativeDiscoverySource.
//
// Bridges to platform-native BLE / Nearby scanners via Platform
// Channels. This Sprint (Issue #3) lands the wiring only — the
// native side returns empty peer streams + BluetoothState.on stub
// values. Real BLE scanning ships in Issue #4.
//
// Channels (kept in sync with Runner/AppDelegate.swift and
// MainActivity.kt):
//   method:  proximity_music_app/discovery
//   event:   proximity_music_app/discovery/peers
//   event:   proximity_music_app/discovery/bt_state

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/discovery_source.dart';

class NativeDiscoverySource implements DiscoverySource {
  NativeDiscoverySource({
    MethodChannel? method,
    EventChannel? peerEvents,
    EventChannel? btEvents,
  })  : _method =
            method ?? const MethodChannel('proximity_music_app/discovery'),
        _peerEvents = peerEvents ??
            const EventChannel('proximity_music_app/discovery/peers'),
        _btEvents = btEvents ??
            const EventChannel('proximity_music_app/discovery/bt_state');

  final MethodChannel _method;
  final EventChannel _peerEvents;
  final EventChannel _btEvents;

  Stream<Peer>? _peerStream;
  Stream<BluetoothState>? _btStream;

  @override
  Stream<Peer> get peerStream {
    return _peerStream ??=
        _peerEvents.receiveBroadcastStream().map(_decodePeer).handleError((_) {
      // Native PoC stub may not emit anything; surface no peers
      // rather than crashing.
    });
  }

  @override
  Stream<BluetoothState> get bluetoothStateStream {
    return _btStream ??= _btEvents
        .receiveBroadcastStream()
        .map(_decodeBluetoothState)
        .handleError((_) {});
  }

  @override
  Future<void> start() async {
    await _method.invokeMethod<void>('start');
  }

  @override
  Future<void> stop() async {
    await _method.invokeMethod<void>('stop');
  }

  @override
  Future<BluetoothState> currentBluetoothState() async {
    final raw = await _method.invokeMethod<String>('currentBluetoothState');
    return _decodeBluetoothState(raw);
  }

  Peer _decodePeer(dynamic event) {
    final map = (event as Map).cast<String, dynamic>();
    final id = map['id'] as String? ?? '';
    final lastSeen = map['lastSeenAtMs'] as int? ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
    final seed = map['avatarSeed'] as int? ?? 0;
    return Peer(
      id: id,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(lastSeen, isUtc: true),
      avatarSeed: seed,
    );
  }

  BluetoothState _decodeBluetoothState(dynamic raw) {
    switch (raw) {
      case 'on':
        return BluetoothState.on;
      case 'off':
        return BluetoothState.off;
      case 'unauthorized':
        return BluetoothState.unauthorized;
      case 'unknown':
      default:
        return BluetoothState.unknown;
    }
  }
}
