import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureClipboardChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Enable background fetch for workmanager
    UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    // BGTaskScheduler requires every identifier to be registered before launch
    // finishes, and each must also appear in BGTaskSchedulerPermittedIdentifiers.
    // Whether either task is actually scheduled is decided in Dart, from the
    // notifications toggle and the wallets' connections.
    let bundleId = Bundle.main.bundleIdentifier ?? "org.magicgrants.spicewallet"

    // Short opportunistic wake-up (~30s). Only ever scheduled for light,
    // clearnet wallets — a Tor bootstrap or node scan can't finish in the window.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "\(bundleId).refresh",
      frequency: NSNumber(value: 15 * 60)
    )

    // Longer run, only while charging and idle — room for Tor to bootstrap first.
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "\(bundleId).processing")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureClipboard")
    if let messenger = registrar?.messenger() {
      let channel = FlutterMethodChannel(
        name: "org.magicgrants.spice/secure_clipboard",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, reply in
        guard call.method == "copySensitive" else {
          reply(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        let text = args?["text"] as? String ?? ""
        let seconds = (args?["clearAfterSeconds"] as? NSNumber)?.doubleValue ?? 60
        // localOnly keeps it off Universal Clipboard (Handoff); expirationDate
        // lets iOS clear it even if the app is no longer running.
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [
            .localOnly: true,
            .expirationDate: Date().addingTimeInterval(seconds),
          ]
        )
        reply(nil)
      }
      secureClipboardChannel = channel
    }
  }
}
