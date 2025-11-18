//
//  WatchConnectivityManager.swift
//  iphone_sensor_app_no_claude
//
//  Manages file synchronization from Apple Watch to iPhone
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false
    @Published var receivedFiles: [FileInfo] = []
    @Published var pendingFiles: [FileInfo] = []  // Files known but not yet transferred
    @Published var syncInProgress: Bool = false
    @Published var activeTransfers: [String: Double] = [:]  // fileName: progress

    // MARK: - Initialization

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("📱 WatchConnectivity session activating...")
        } else {
            print("⚠️  WatchConnectivity not supported on this device")
        }
    }

    // MARK: - Manual Sync Triggers

    /// Request files to be synced from watch (when watch is reachable)
    func requestSyncFromWatch() {
        print("📱 Requesting sync from watch...")
        print("📱 Session state: activated=\(WCSession.default.activationState == .activated), reachable=\(WCSession.default.isReachable)")

        guard WCSession.default.isReachable else {
            print("📱 Watch not reachable for sync request")
            return
        }

        print("📱 Sending syncFiles message to watch...")
        WCSession.default.sendMessage(["action": "syncFiles"], replyHandler: { reply in
            print("📱 Received reply from watch: \(reply)")
            if let fileCount = reply["fileCount"] as? Int {
                print("📱 Watch will sync \(fileCount) files")
                DispatchQueue.main.async {
                    self.syncInProgress = true
                }
            }
        }, errorHandler: { error in
            print("❌ Sync request failed: \(error.localizedDescription)")
        })
    }

    /// Request a specific file download from watch (FORCE IMMEDIATE TRANSFER)
    func requestFile(_ fileName: String) {
        print("📱 Requesting IMMEDIATE high-priority transfer of: \(fileName)")

        guard WCSession.default.isReachable else {
            print("❌ Watch not reachable for immediate transfer")
            return
        }

        WCSession.default.sendMessage(
            ["action": "transferFile", "fileName": fileName],
            replyHandler: { reply in
                if let status = reply["status"] as? String {
                    print("📱 Watch response: \(status)")
                    if status == "transferring" {
                        print("📱 ✅ File \(fileName) is now transferring with HIGH PRIORITY")
                    }
                }
            },
            errorHandler: { error in
                print("❌ File request failed: \(error.localizedDescription)")
            }
        )
    }

    /// Request watch to delete all synced files
    func requestDeleteSyncedFilesOnWatch() {
        print("📱 Requesting watch to delete synced files...")
        print("📱 Session state: activated=\(WCSession.default.activationState == .activated), reachable=\(WCSession.default.isReachable)")

        guard WCSession.default.isReachable else {
            print("📱 Watch not reachable for delete request")
            return
        }

        // Get list of files we have on iPhone to send to watch
        let filesOnIPhone = receivedFiles.map { $0.fileName }
        print("📱 Sending list of \(filesOnIPhone.count) files on iPhone to watch...")

        print("📱 Sending deleteSyncedFiles message to watch...")
        WCSession.default.sendMessage([
            "action": "deleteSyncedFiles",
            "filesOnIPhone": filesOnIPhone
        ], replyHandler: { reply in
            print("📱 Received reply from watch: \(reply)")
            if let deletedCount = reply["deletedCount"] as? Int {
                print("📱 Watch deleted \(deletedCount) files")
            }
        }, errorHandler: { error in
            print("❌ Delete request failed: \(error.localizedDescription)")
        })
    }

    // MARK: - Helper Methods

    private func saveReceivedFile(_ file: WCSessionFile) {
        let fileName = file.metadata?["fileName"] as? String ?? "unknown_\(UUID().uuidString).csv"

        // Create watch_data subdirectory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let watchDataDir = documentsURL.appendingPathComponent("watch_data")
        let destination = watchDataDir.appendingPathComponent(fileName)

        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: watchDataDir, withIntermediateDirectories: true)

            // Remove existing file if present
            try? FileManager.default.removeItem(at: destination)

            // Move received file (MUST be done before method returns!)
            try FileManager.default.moveItem(at: file.fileURL, to: destination)

            print("📱 Saved file: \(fileName)")

            // Update UI on main thread
            DispatchQueue.main.async {
                print("📱 Loading received files after save...")
                self.loadReceivedFiles()
                self.syncInProgress = false

                // Remove from pending files since it's now received
                self.pendingFiles.removeAll { $0.fileName == fileName }
                print("📱 Removed \(fileName) from pending files. Pending count: \(self.pendingFiles.count)")

                // Send confirmation to watch
                self.sendTransferConfirmation(fileName: fileName)

                // Post notification to refresh UI
                print("📱 Posting RefreshFileList notification")
                NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
            }
        } catch {
            print("❌ Failed to save file \(fileName): \(error)")
        }
    }

    private func loadReceivedFiles() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let watchDataDir = documentsURL.appendingPathComponent("watch_data")

        guard FileManager.default.fileExists(atPath: watchDataDir.path) else {
            receivedFiles = []
            return
        }

        do {
            let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .creationDateKey, .fileSizeKey]
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: watchDataDir,
                includingPropertiesForKeys: resourceKeys
            )

            let csvFiles = fileURLs.filter { $0.pathExtension == "csv" }

            receivedFiles = csvFiles.compactMap { url in
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

                    let size = attributes[.size] as? Int64 ?? 0
                    let creationDate = resourceValues.creationDate ?? Date.distantPast
                    let modificationDate = resourceValues.contentModificationDate ?? Date.distantPast

                    return FileInfo(
                        url: url,
                        size: size,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        syncState: .synced,
                        sourceDevice: .watch
                    )
                } catch {
                    return nil
                }
            }
        } catch {
            print("❌ Error loading received files: \(error)")
            receivedFiles = []
        }
    }

    private func sendTransferConfirmation(fileName: String) {
        // Send confirmation that file was received (for watch auto-delete)
        guard WCSession.default.activationState == .activated else { return }

        let message = ["action": "fileReceived", "fileName": fileName]

        if WCSession.default.isReachable {
            // Send immediately if reachable
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("❌ Failed to send confirmation: \(error.localizedDescription)")
            })
        } else {
            // Queue for later delivery
            WCSession.default.transferUserInfo(message)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable

            print("📱 WatchConnectivity activated: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled)")
        }

        if let error = error {
            print("❌ WCSession activation failed: \(error)")
        }

        // Load any previously received files
        DispatchQueue.main.async {
            self.loadReceivedFiles()

            // Load current application context from watch (if available)
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                print("📱 Loading existing application context from watch")
                if let availableFilesData = context["availableFiles"] as? [[String: Any]] {
                    self.updatePendingFiles(from: availableFilesData)
                }
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 Watch reachability changed: \(session.isReachable)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 Session deactivated - re-activating for watch switching")
        session.activate()
    }

    // MARK: - Receive Messages

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 Received message: \(message)")

        if let action = message["action"] as? String {
            switch action {
            case "filesIncoming":
                // Watch notifying of incoming files
                let count = message["count"] as? Int ?? 0
                DispatchQueue.main.async {
                    self.syncInProgress = true
                }
                replyHandler(["status": "ready"])
                print("📱 Watch sending \(count) files")

            default:
                replyHandler(["error": "unknown action"])
            }
        } else {
            replyHandler(["status": "received"])
        }
    }

    // MARK: - Receive Files

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("📱 Received file transfer")
        saveReceivedFile(file)
    }

    // MARK: - Receive Application Context

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context: \(applicationContext)")

        // Handle file metadata from watch
        if let availableFilesData = applicationContext["availableFiles"] as? [[String: Any]] {
            DispatchQueue.main.async {
                self.updatePendingFiles(from: availableFilesData)
            }
        }
    }

    private func updatePendingFiles(from metadata: [[String: Any]]) {
        // Parse metadata into pending FileInfo objects
        let pending = metadata.compactMap { fileData -> FileInfo? in
            guard let fileName = fileData["fileName"] as? String,
                  let size = fileData["size"] as? Int64,
                  let creationTimestamp = fileData["creationDate"] as? TimeInterval,
                  let dataTimestamp = fileData["dataDate"] as? TimeInterval else {
                return nil
            }

            // Check if we already have this file
            let alreadyReceived = receivedFiles.contains { $0.fileName == fileName }
            if alreadyReceived {
                return nil  // Don't show as pending if we have it
            }

            // Create placeholder URL (file doesn't exist locally yet)
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let placeholderURL = documentsURL.appendingPathComponent("watch_data").appendingPathComponent(fileName)

            return FileInfo(
                url: placeholderURL,
                size: size,
                creationDate: Date(timeIntervalSince1970: creationTimestamp),
                modificationDate: Date(timeIntervalSince1970: creationTimestamp),
                syncState: .pending,
                sourceDevice: .watch
            )
        }

        pendingFiles = pending
        print("📱 Updated pending files: \(pending.count) files available on watch")

        // Notify UI to refresh
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
    }
}
