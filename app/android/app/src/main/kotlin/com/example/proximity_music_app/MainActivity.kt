package com.example.proximity_music_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ---- Sprint 03 spike: proximity_music_app/discovery channels ----
        //
        // Real BLE / Nearby scanning lands in a later sprint. For now the
        // method channel returns stub responses and the event channels emit
        // nothing, exercising the wiring path end-to-end.
        MethodChannel(messenger, "proximity_music_app/discovery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(null)
                    "stop" -> result.success(null)
                    "currentBluetoothState" -> result.success("on")
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, "proximity_music_app/discovery/peers")
            .setStreamHandler(EmptyStreamHandler)

        EventChannel(messenger, "proximity_music_app/discovery/bt_state")
            .setStreamHandler(EmptyStreamHandler)

        // ---- Sprint 04 spike: proximity_music_app/session channels ----
        //
        // Native side is an intentional stub — sendHandshake always returns
        // result.error("transport_unavailable", ...) and the disconnect stream
        // emits no events. Real ECDH + P2P transport lands in Issue #5+.
        MethodChannel(messenger, "proximity_music_app/session")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendHandshake" -> result.error(
                        "transport_unavailable",
                        "Sprint 04 stub: native session transport not implemented",
                        null
                    )
                    "closeSession" -> result.success(null)
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, "proximity_music_app/session/disconnects")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // Sprint 04: no events emitted.
                }

                override fun onCancel(arguments: Any?) {
                    // No resources to release.
                }
            })
    }
}

private object EmptyStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Sprint 03 spike — emit nothing. A later sprint wires the real
        // BLE / Nearby scanner here.
    }

    override fun onCancel(arguments: Any?) {
        // No-op.
    }
}
