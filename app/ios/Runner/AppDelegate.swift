import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Sprint 04 spike: register the proximity_music_app/session MethodChannel
    // and the matching disconnects EventChannel. The native side is an
    // intentional stub for Sprint 04 — sendHandshake always returns
    // FlutterError(code: "transport_unavailable") and the disconnect stream
    // emits no events. Real ECDH + P2P transport lands in Issue #5+.
    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger

      let methodChannel = FlutterMethodChannel(
        name: "proximity_music_app/session",
        binaryMessenger: messenger
      )
      methodChannel.setMethodCallHandler { (call, result) in
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
