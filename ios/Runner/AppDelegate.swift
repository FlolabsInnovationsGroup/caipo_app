import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let bleHostOwner = BleHostOwner()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CaipoBle") else {
      return
    }
    bleHostOwner.attach(messenger: registrar.messenger())
  }
}

/// Keeps the Pigeon handlers alive for the engine lifetime.
final class BleHostOwner {
  private var bleHost: BleHostApiImpl?
  private var secureStore: SecureStoreHostApiImpl?

  func attach(messenger: FlutterBinaryMessenger) {
    let flutterApi = BleFlutterApi(binaryMessenger: messenger)
    let host = BleHostApiImpl(flutterApi: flutterApi)
    bleHost = host
    secureStore = SecureStoreHostApiImpl()
    BleHostApiSetup.setUp(binaryMessenger: messenger, api: host)
    SecureStoreHostApiSetup.setUp(binaryMessenger: messenger, api: secureStore)
  }
}
