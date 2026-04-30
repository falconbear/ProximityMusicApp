package com.example.proximity_music_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // ---- Sprint 03 spike: proximity_music_app/discovery channels ----
    //
    // Real BLE / Nearby scanning lands in Issue #4. For now the method
    // channel returns stub responses and the event channels emit
    // nothing, exercising the wiring path end-to-end.

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

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
    }
}

private object EmptyStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Sprint 03 spike — emit nothing. Issue #4 wires the real
        // BLE / Nearby scanner here.
    }

    override fun onCancel(arguments: Any?) {
        // No-op.
    }
}
