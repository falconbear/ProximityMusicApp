import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // ---- Sprint 03 spike: proximity_music_app/discovery channels ----
    //
    // Real BLE / CoreBluetooth scanning lands in Issue #4. For now the
    // method channel returns stub responses and the event channels emit
    // nothing, exercising the wiring path end-to-end.
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let methodChannel = FlutterMethodChannel(
        name: "proximity_music_app/discovery",
        binaryMessenger: controller.binaryMessenger
      )
      methodChannel.setMethodCallHandler { (call, result) in
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
        binaryMessenger: controller.binaryMessenger
      )
      peerEvents.setStreamHandler(EmptyStreamHandler())

      let btEvents = FlutterEventChannel(
        name: "proximity_music_app/discovery/bt_state",
        binaryMessenger: controller.binaryMessenger
      )
      btEvents.setStreamHandler(EmptyStreamHandler())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class EmptyStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    // Sprint 03 spike: emit nothing. Issue #4 will replace this with
    // a CoreBluetooth-backed scanner.
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}
