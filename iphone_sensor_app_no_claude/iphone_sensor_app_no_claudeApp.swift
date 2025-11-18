//
//  iphone_sensor_app_no_claudeApp.swift
//  iphone_sensor_app_no_claude
//
//  iPhone file manager app for Apple Watch sensor data
//  Note: All sensor recording now happens on Apple Watch
//

import SwiftUI

@main
struct iphone_sensor_app_no_claudeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WatchConnectivityManager.shared)
        }
    }
}

// AppDelegate to initialize WatchConnectivity
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("📱 iPhone app launched - Watch file manager mode")

        // Initialize WatchConnectivity session
        _ = WatchConnectivityManager.shared

        return true
    }
}
