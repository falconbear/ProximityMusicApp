package com.example.proximity_music_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Sprint 04 spike: register the proximity_music_app/session MethodChannel
    // and the matching disconnects EventChannel. The native side is an
    // intentional stub — sendHandshake always returns
    // result.error("transport_unavailable", ...) and the disconnect stream
    // emits no events. Real ECDH + P2P transport lands in Issue #5+.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "proximity_music_app/session"
        ).setMethodCallHandler { call, result ->
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

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "proximity_music_app/session/disconnects"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // Sprint 04: no events emitted.
            }

            override fun onCancel(arguments: Any?) {
                // No resources to release.
            }
        })
    }
}
