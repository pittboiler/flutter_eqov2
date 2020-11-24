import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

        GMSServices.provideAPIKey("AIzaSyAa1xw_s2MDuWDr3O3mKgKRiC3vzuU92Bc")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
