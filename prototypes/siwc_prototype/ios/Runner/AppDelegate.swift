import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var signInTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Keeps the app running briefly while the user is in Safari, so the loopback
    // listener can answer the sign-in callback. iOS grants roughly 30 seconds.
    let channel = FlutterMethodChannel(
      name: "siwc/background",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "begin":
        self.endSignInTask()
        self.signInTask = UIApplication.shared.beginBackgroundTask(withName: "siwc-sign-in") {
          self.endSignInTask()
        }
        result(nil)
      case "end":
        self.endSignInTask()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func endSignInTask() {
    guard signInTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(signInTask)
    signInTask = .invalid
  }
}
