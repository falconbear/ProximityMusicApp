// NativeSessionTransport — Sprint 04 spike of the SessionTransport interface
// over MethodChannel + EventChannel.
//
// The native side of this transport is intentionally a PoC stub for Sprint
// 04: sendHandshake always returns FlutterError(code: 'transport_unavailable')
// and the disconnects EventChannel emits no events. Real P2P (BLE / Nearby /
// MultipeerConnectivity) lands in Issue #5+.
//
// Imports flutter/services for MethodChannel / EventChannel only; does not
// import flutter/material, go_router, or pigeon (the wire-up is hand-rolled).

import 'package:flutter/services.dart';

import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/services/session_transport.dart';

class NativeSessionTransport implements SessionTransport {
  static const _channelName = 'proximity_music_app/session';
  static const _disconnectsChannelName =
      'proximity_music_app/session/disconnects';

  final MethodChannel _methods;
  final EventChannel _disconnects;

  NativeSessionTransport({
    MethodChannel? methodChannel,
    EventChannel? disconnectsEventChannel,
  })  : _methods = methodChannel ?? const MethodChannel(_channelName),
        _disconnects = disconnectsEventChannel ??
            const EventChannel(_disconnectsChannelName);

  @override
  Future<HandshakeMessage> sendHandshake(
    String peerId,
    HandshakeMessage outbound,
  ) async {
    try {
      final reply = await _methods.invokeMapMethod<String, dynamic>(
        'sendHandshake',
        <String, dynamic>{
          'peerId': peerId,
          'fromIdValue': outbound.fromIdValue,
          'publicKeyHex': outbound.publicKeyHex,
          'nonceHex': outbound.nonceHex,
        },
      );
      if (reply == null) {
        throw const SessionTransportException('null reply from native');
      }
      return HandshakeMessage(
        fromIdValue: reply['fromIdValue'] as String? ?? peerId,
        publicKeyHex: reply['publicKeyHex'] as String? ?? '',
        nonceHex: reply['nonceHex'] as String? ?? '',
      );
    } on PlatformException catch (e) {
      throw SessionTransportException(
        'native sendHandshake failed: ${e.code} ${e.message ?? ''}',
      );
    } on MissingPluginException catch (e) {
      throw SessionTransportException(
        'native sendHandshake unavailable: ${e.message ?? 'plugin missing'}',
      );
    }
  }

  @override
  Future<void> closeSession(String peerId) async {
    try {
      await _methods.invokeMethod<void>('closeSession', {'peerId': peerId});
    } on PlatformException catch (e) {
      throw SessionTransportException(
        'native closeSession failed: ${e.code} ${e.message ?? ''}',
      );
    } on MissingPluginException {
      // Treat as a no-op when the native side is not registered (e.g.,
      // Flutter web or test harness without channel handlers).
    }
  }

  @override
  Stream<String> get disconnectStream =>
      _disconnects.receiveBroadcastStream().map((event) => event.toString());
}
