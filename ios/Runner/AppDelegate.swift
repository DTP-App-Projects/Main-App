import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The live driver map on the shipment tracking screen; the SDK aborts the
    // app if a map is built before a key is provided.
    GMSServices.provideAPIKey("AIzaSyD8aeToq5NGuglB-C18FhGWhVKMcrFw5ZE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
