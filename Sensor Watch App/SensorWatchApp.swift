//
//  SensorWatchApp.swift
//  SensorWatch Watch App
//
//  Main app entry point for Apple Watch sensor recording
//

import SwiftUI

@main
struct SensorWatchApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("⌚ App became active")
                appState.handleAppBecameActive()
            case .inactive:
                print("⌚ App became inactive")
            case .background:
                print("⌚ App entered background")
                appState.handleAppEnteredBackground()
            @unknown default:
                break
            }
        }
    }
}

/// Manages app-wide state and background processing
class AppState: ObservableObject {
    let motionRecorder = MotionRecorder()
    private var backgroundTaskTimer: Timer?
    private var hasLaunched = false
    private var previousFileCount = 0

    init() {
        // Initialize WatchConnectivity
        _ = WatchConnectivityManager.shared

        // Start continuous recording and process data on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if !self.hasLaunched {
                self.hasLaunched = true
                print("⌚ SensorWatch app initialized")
                self.motionRecorder.startContinuousRecording()
                self.motionRecorder.processAndSaveUnprocessedData()
                self.scheduleBackgroundProcessing()

                // Initial metadata sync
                WatchConnectivityManager.shared.syncFileMetadata()

                // Track initial file count
                self.previousFileCount = self.motionRecorder.getCSVFiles().count
            }
        }
    }

    func handleAppBecameActive() {
        // Process and save data when app comes to foreground
        motionRecorder.processAndSaveUnprocessedData()

        // Notify UI to refresh file list
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)

        // Sync metadata
        WatchConnectivityManager.shared.syncFileMetadata()

        // Restart timer if needed
        if backgroundTaskTimer == nil {
            scheduleBackgroundProcessing()
        }
    }

    func handleAppEnteredBackground() {
        // Timer will continue running in background on watchOS
        print("⌚ Timer will continue processing in background")

        // Sync metadata before backgrounding
        WatchConnectivityManager.shared.syncFileMetadata()
    }

    // MARK: - Background Processing

    /// Schedule a timer to periodically process sensor data
    /// On watchOS, this runs every 30 seconds while app is active or in background
    private func scheduleBackgroundProcessing() {
        // Cancel any existing timer
        backgroundTaskTimer?.invalidate()

        // Create a new timer that fires every 30 seconds
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            print("⏰ Background timer fired - processing data")

            self.motionRecorder.processAndSaveUnprocessedData()

            // Check if new files were created
            let currentFileCount = self.motionRecorder.getCSVFiles().count
            if currentFileCount > self.previousFileCount {
                print("⌚ New files detected: \(currentFileCount - self.previousFileCount) files")

                // Get new files
                let allFiles = self.motionRecorder.getCSVFiles()
                let newFiles = Array(allFiles.suffix(currentFileCount - self.previousFileCount))

                // Queue new files for transfer
                for fileURL in newFiles {
                    WatchConnectivityManager.shared.queueFileForTransfer(fileURL)
                }

                self.previousFileCount = currentFileCount

                // Update metadata
                WatchConnectivityManager.shared.syncFileMetadata()
            }

            // Notify UI to refresh file list
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
        }

        // Ensure timer runs even when UI is scrolling
        if let timer = backgroundTaskTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("⏰ Scheduled background processing timer (30s interval)")
    }

    deinit {
        backgroundTaskTimer?.invalidate()
    }
}
