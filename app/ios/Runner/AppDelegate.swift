import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger

      // ---- Sprint 03 spike: proximity_music_app/discovery channels ----
      //
      // Real BLE / CoreBluetooth scanning lands in a later sprint. For now
      // the method channel returns stub responses and the event channels
      // emit nothing, exercising the wiring path end-to-end.
      let discoveryChannel = FlutterMethodChannel(
        name: "proximity_music_app/discovery",
        binaryMessenger: messenger
      )
      discoveryChannel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "start":
          result(nil)
        case "stop":
          result(nil)
        case "currentBluetoothState":
          result("on")
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let peerEvents = FlutterEventChannel(
        name: "proximity_music_app/discovery/peers",
        binaryMessenger: messenger
      )
      peerEvents.setStreamHandler(EmptyStreamHandler())

      let btEvents = FlutterEventChannel(
        name: "proximity_music_app/discovery/bt_state",
        binaryMessenger: messenger
      )
      btEvents.setStreamHandler(EmptyStreamHandler())

      // ---- Sprint 04 spike: proximity_music_app/session channels ----
      //
      // Native side is an intentional stub for Sprint 04 — sendHandshake
      // always returns FlutterError(code: "transport_unavailable") and the
      // disconnect stream emits no events. Real ECDH + P2P transport lands
      // in Issue #5+.
      let sessionChannel = FlutterMethodChannel(
        name: "proximity_music_app/session",
        binaryMessenger: messenger
      )
      sessionChannel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "sendHandshake":
          result(FlutterError(
            code: "transport_unavailable",
            message: "Sprint 04 stub: native session transport not implemented",
            details: nil
          ))
        case "closeSession":
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let disconnectsChannel = FlutterEventChannel(
        name: "proximity_music_app/session/disconnects",
        binaryMessenger: messenger
      )
      disconnectsChannel.setStreamHandler(SessionDisconnectsStreamHandler())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class EmptyStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    // Sprint 03 spike: emit nothing. A later sprint will replace this with
    // a CoreBluetooth-backed scanner.
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}

/// Sprint 04 stub stream handler for proximity_music_app/session/disconnects.
/// Holds the event sink but never emits events. Real disconnect notifications
/// land in Issue #5+ when a real P2P transport is wired.
class SessionDisconnectsStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}
