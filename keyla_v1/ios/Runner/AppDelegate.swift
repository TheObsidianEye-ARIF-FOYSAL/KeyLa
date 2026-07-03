import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyEnabled = false
  private var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self, selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "keyla/screen_privacy",
      binaryMessenger: engineBridge.pluginRegistry as! FlutterBinaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.privacyEnabled = true
        result(nil)
      case "disable":
        self?.privacyEnabled = false
        self?.removeOverlay()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Blurs the app preview in the switcher / on resign-active, per spec §5
  // ("Blur/obscure the app preview in the OS app switcher").
  @objc private func willResignActive() {
    guard privacyEnabled, let window = self.window else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    blur.frame = window.bounds
    blur.tag = 0xDEAD_BEEF
    window.addSubview(blur)
    privacyOverlay = blur
  }

  @objc private func didBecomeActive() {
    removeOverlay()
  }

  private func removeOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
