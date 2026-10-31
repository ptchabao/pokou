import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // flutter_contacts lit `delegate.window!!.rootViewController!` pendant son
    // enregistrement, et plante si elle est absente. Avec les scènes, les
    // greffons s'enregistrent pendant la création de la vue Flutter, avant
    // qu'aucune fenêtre n'existe. Une fenêtre provisoire le temps de
    // l'enregistrement, retirée aussitôt : les autres greffons, qui lisent
    // la fenêtre au moment de s'en servir, trouvent alors la vraie.
    let placeholder = window == nil
    if placeholder {
      let provisoire = UIWindow(frame: UIScreen.main.bounds)
      provisoire.rootViewController = UIViewController()
      window = provisoire
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if placeholder { window = nil }
  }
}
