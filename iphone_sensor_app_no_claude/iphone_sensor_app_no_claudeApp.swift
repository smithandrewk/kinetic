//
//  iphone_sensor_app_no_claudeApp.swift
//  iphone_sensor_app_no_claude
//
//  Created by Andrew Smith on 11/12/25.
//

import SwiftUI
import BackgroundTasks

@main
struct iphone_sensor_app_no_claudeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// AppDelegate to handle background tasks and lifecycle events
class AppDelegate: NSObject, UIApplicationDelegate {
    let motionRecorder = MotionRecorder()
    var processingTimer: Timer?

    // Background task identifier - must match Info.plist entry
    let backgroundTaskIdentifier = "com.andrew.iphone-sensor-app-no-claude.processensordata"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("App launched")

        // Register background task
        registerBackgroundTasks()

        // Process any unprocessed data and start recording
        motionRecorder.processAndSaveUnprocessedData()
        motionRecorder.startContinuousRecording()

        // Schedule the first background task
        scheduleBackgroundTask()

        // Start periodic processing timer (every 1 minute while app is open)
        startPeriodicProcessing()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App entered background")
        // Stop the timer when going to background
        stopPeriodicProcessing()
        // Process data before backgrounding
        motionRecorder.processAndSaveUnprocessedData()
        // Schedule background task when app goes to background
        scheduleBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App will enter foreground")
        // Process any data that accumulated while app was in background
        motionRecorder.processAndSaveUnprocessedData()
        // Restart the timer
        startPeriodicProcessing()
    }

    // MARK: - Periodic Processing

    private func startPeriodicProcessing() {
        stopPeriodicProcessing() // Stop any existing timer

        // Process data every 30 seconds while app is in foreground
        processingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            print("Periodic processing triggered (foreground)")
            self?.motionRecorder.processAndSaveUnprocessedData()

            // Post notification to refresh UI
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
        }

        print("Started periodic processing timer (every 30 seconds)")
    }

    private func stopPeriodicProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
        print("Stopped periodic processing timer")
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            print("Background task started: \(self.backgroundTaskIdentifier)")
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }

    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)

        // Require external power and network if needed (optional)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        // Schedule to run in 1 minute (for testing - normally would be 2 hours)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled for \(request.earliestBeginDate!)")
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }

    private func handleBackgroundTask(task: BGProcessingTask) {
        // Schedule the next background task
        scheduleBackgroundTask()

        // Set expiration handler
        task.expirationHandler = {
            print("Background task expired")
            task.setTaskCompleted(success: false)
        }

        // Process sensor data in background
        DispatchQueue.global(qos: .background).async {
            print("Processing data in background task...")
            self.motionRecorder.processAndSaveUnprocessedData()

            // Mark task as completed
            task.setTaskCompleted(success: true)
            print("Background task completed successfully")
        }
    }
}
