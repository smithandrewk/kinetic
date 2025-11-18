//
//  WatchConnectivityManager.swift
//  Sensor Watch App
//
//  Manages smart file transfer from Watch to iPhone with auto-delete
//

import Foundation
import WatchConnectivity
import Combine
import WatchKit

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    @Published var isPaired: Bool = false
    @Published var isReachable: Bool = false
    @Published var syncStatus: String = "Idle"
    @Published var filesTransferring: Int = 0
    @Published var transferProgress: [URL: Double] = [:]

    // MARK: - Private Properties

    private var transferQueue: [URL] = []
    private var activeTransfers: Set<URL> = []
    private let maxConcurrentTransfers = 3
    private var confirmedTransfers: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: "confirmedTransfers"),
               let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return set
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "confirmedTransfers")
            }
        }
    }
    private var pendingDeletions: [String: Date] {
        get {
            if let data = UserDefaults.standard.data(forKey: "pendingDeletions"),
               let dict = try? JSONDecoder().decode([String: Date].self, from: data) {
                return dict
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "pendingDeletions")
            }
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("⌚ WatchConnectivity session activating...")
        }

        // Start deletion cleanup timer
        startDeletionCleanupTimer()
    }

    // MARK: - File Transfer Management

    /// Queue a file for transfer (called when new file is created)
    /// Transfers start immediately - iOS handles opportunistic delivery in background
    func queueFileForTransfer(_ url: URL) {
        guard !transferQueue.contains(url), !activeTransfers.contains(url) else {
            return
        }

        transferQueue.append(url)
        print("⌚ Queued file for transfer: \(url.lastPathComponent)")

        // Start transfer immediately
        // WCSession.transferFile() handles all the heavy lifting:
        // - Queues transfer persistently (survives app termination)
        // - Delivers opportunistically based on battery, connectivity, proximity
        // - Retries automatically until delivered
        // - Works completely in background
        processTransferQueue()

        // Update metadata immediately so iPhone knows file exists
        syncFileMetadata()
    }

    /// Manual trigger to transfer all files
    func transferAllPendingFiles() {
        print("⌚ transferAllPendingFiles() called")
        DispatchQueue.main.async {
            self.syncStatus = "Syncing..."
        }

        let motionRecorder = MotionRecorder()
        let files = motionRecorder.getCSVFiles()

        print("⌚ Total files found: \(files.count)")
        print("⌚ Already confirmed: \(confirmedTransfers.count)")

        // Filter out files that are already confirmed
        let filesToTransfer = files.filter { url in
            !confirmedTransfers.contains(url.lastPathComponent)
        }

        print("⌚ Transferring all files: \(filesToTransfer.count) files")

        for file in filesToTransfer {
            if !transferQueue.contains(file) && !activeTransfers.contains(file) {
                transferQueue.append(file)
            }
        }

        processTransferQueue()
    }

    private func processTransferQueue() {
        // Limit concurrent transfers
        while activeTransfers.count < maxConcurrentTransfers && !transferQueue.isEmpty {
            let fileURL = transferQueue.removeFirst()
            transferFile(fileURL)
        }
    }

    private func transferFile(_ fileURL: URL, highPriority: Bool = false) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ File doesn't exist: \(fileURL.lastPathComponent)")
            return
        }

        activeTransfers.insert(fileURL)

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = attributes[.size] as? Int64 ?? 0

            let metadata: [String: Any] = [
                "fileName": fileURL.lastPathComponent,
                "fileSize": size,
                "timestamp": Date().timeIntervalSince1970,
                "priority": highPriority ? "high" : "normal"
            ]

            let transfer = WCSession.default.transferFile(fileURL, metadata: metadata)

            if highPriority {
                print("⌚ Started HIGH PRIORITY transfer: \(fileURL.lastPathComponent) (\(size) bytes)")
            } else {
                print("⌚ Started transfer: \(fileURL.lastPathComponent) (\(size) bytes)")
            }

            // Monitor progress
            transfer.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
                DispatchQueue.main.async {
                    self?.transferProgress[fileURL] = progress.fractionCompleted
                    self?.filesTransferring = self?.activeTransfers.count ?? 0
                }
            }

            // Monitor completion
            transfer.progress.observe(\.isFinished, options: [.new]) { [weak self] progress, _ in
                if progress.isFinished {
                    self?.handleTransferCompletion(fileURL: fileURL)
                }
            }

        } catch {
            print("❌ Error transferring file: \(error)")
            activeTransfers.remove(fileURL)
        }
    }

    private func handleTransferCompletion(fileURL: URL) {
        print("⌚ Transfer completed: \(fileURL.lastPathComponent)")

        DispatchQueue.main.async {
            self.activeTransfers.remove(fileURL)
            self.transferProgress.removeValue(forKey: fileURL)
            self.filesTransferring = self.activeTransfers.count

            if self.activeTransfers.isEmpty && self.transferQueue.isEmpty {
                self.syncStatus = "Synced"
            }

            // Process next file in queue
            self.processTransferQueue()
        }
    }

    // MARK: - Metadata Synchronization

    func syncFileMetadata() {
        let motionRecorder = MotionRecorder()
        let fileInfos = motionRecorder.getCSVFilesWithMetadata()

        let metadata = fileInfos.map { fileInfo in
            [
                "fileName": fileInfo.fileName,
                "size": fileInfo.size,
                "creationDate": fileInfo.creationDate.timeIntervalSince1970,
                "dataDate": fileInfo.dataDate.timeIntervalSince1970
            ] as [String : Any]
        }

        let context: [String: Any] = [
            "availableFiles": metadata,
            "lastUpdated": Date().timeIntervalSince1970
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            print("⌚ Synced metadata for \(fileInfos.count) files")
        } catch {
            print("❌ Failed to sync metadata: \(error)")
        }
    }

    // MARK: - Auto-Delete with Confirmation

    private func startDeletionCleanupTimer() {
        // Check every 5 minutes for files ready to delete
        Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.cleanupConfirmedFiles()
        }
    }

    private func handleFileConfirmation(fileName: String) {
        var confirmed = confirmedTransfers
        confirmed.insert(fileName)
        confirmedTransfers = confirmed

        var pending = pendingDeletions
        pending[fileName] = Date()
        pendingDeletions = pending

        print("⌚ File confirmed by iPhone: \(fileName) - will delete in 5 minutes")
        print("⌚ Total confirmed transfers: \(confirmedTransfers.count)")
    }

    private func cleanupConfirmedFiles() {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        let motionRecorder = MotionRecorder()
        var pending = pendingDeletions
        var needsMetadataSync = false

        for (fileName, confirmationTime) in pending {
            if confirmationTime < fiveMinutesAgo {
                // Safe to delete - 5 minute grace period passed
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsURL.appendingPathComponent(fileName)

                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("⌚ Auto-deleted confirmed file: \(fileName)")
                    pending.removeValue(forKey: fileName)
                    needsMetadataSync = true
                } catch {
                    print("❌ Failed to auto-delete \(fileName): \(error)")
                }
            }
        }

        // Save updated pending deletions
        pendingDeletions = pending

        // Update metadata after deletions
        if needsMetadataSync {
            syncFileMetadata()
        }
    }

    // MARK: - Manual Sync Request Handler

    private func handleSyncRequest(replyHandler: @escaping ([String : Any]) -> Void) {
        let motionRecorder = MotionRecorder()
        let files = motionRecorder.getCSVFiles()

        // Filter out confirmed files
        let filesToTransfer = files.filter { !confirmedTransfers.contains($0.lastPathComponent) }

        print("⌚ Manual sync requested: \(filesToTransfer.count) files to transfer")

        replyHandler(["fileCount": filesToTransfer.count])

        // Queue all files
        for file in filesToTransfer {
            if !transferQueue.contains(file) && !activeTransfers.contains(file) {
                transferQueue.append(file)
            }
        }

        // Start immediate transfer
        processTransferQueue()
    }

    // MARK: - Delete Synced Files Handler

    private func handleDeleteSyncedFiles(filesOnIPhone: [String], replyHandler: @escaping ([String : Any]) -> Void) {
        let motionRecorder = MotionRecorder()
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let allWatchFiles = motionRecorder.getCSVFiles()

        var deletedCount = 0

        print("⌚ Deleting synced files from watch...")
        print("⌚ Files on iPhone: \(filesOnIPhone.count)")
        print("⌚ Total files on watch: \(allWatchFiles.count)")

        // Strategy: Delete files that exist on iPhone
        // This works for both tracked confirmations AND legacy files
        let filesToDelete = Set(filesOnIPhone)

        for watchFile in allWatchFiles {
            let fileName = watchFile.lastPathComponent

            // If iPhone has this file, delete it from watch
            if filesToDelete.contains(fileName) {
                do {
                    try FileManager.default.removeItem(at: watchFile)
                    print("⌚ Deleted synced file: \(fileName)")
                    deletedCount += 1
                } catch {
                    print("❌ Failed to delete \(fileName): \(error)")
                }
            }
        }

        // Clear the confirmed transfers and pending deletions for deleted files
        var confirmed = confirmedTransfers
        var pending = pendingDeletions

        for fileName in filesToDelete {
            confirmed.remove(fileName)
            pending.removeValue(forKey: fileName)
        }

        confirmedTransfers = confirmed
        pendingDeletions = pending

        print("⌚ Deleted \(deletedCount) synced files from watch")

        // Update metadata after deletion
        syncFileMetadata()

        // Notify UI to refresh
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
        }

        replyHandler(["deletedCount": deletedCount, "status": "success"])
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = (activationState == .activated)
            self.isReachable = session.isReachable
            print("⌚ WatchConnectivity activated: state=\(activationState.rawValue)")
        }

        if let error = error {
            print("❌ WCSession activation failed: \(error)")
        } else {
            // Sync metadata on activation
            syncFileMetadata()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚ iPhone reachability changed: \(session.isReachable)")
        }
    }

    // MARK: - Receive Messages

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("⌚ ========== RECEIVED MESSAGE ==========")
        print("⌚ Message: \(message)")

        guard let action = message["action"] as? String else {
            print("⌚ ERROR: No action in message")
            replyHandler(["error": "no action"])
            return
        }

        print("⌚ Action: \(action)")

        switch action {
        case "syncFiles":
            // iPhone requesting sync
            print("⌚ Handling syncFiles request")
            handleSyncRequest(replyHandler: replyHandler)

        case "transferFile":
            // iPhone requesting specific file - FORCE IMMEDIATE HIGH PRIORITY TRANSFER
            print("⌚ Handling transferFile request (HIGH PRIORITY)")
            if let fileName = message["fileName"] as? String {
                print("⌚ Requested file: \(fileName)")
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsURL.appendingPathComponent(fileName)

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    print("⌚ File exists, starting IMMEDIATE high priority transfer")

                    // Remove from queue if already queued (to avoid duplicate)
                    transferQueue.removeAll { $0 == fileURL }

                    // Transfer immediately with high priority flag
                    transferFile(fileURL, highPriority: true)

                    replyHandler(["status": "transferring"])
                } else {
                    print("⌚ ERROR: File not found at \(fileURL.path)")
                    replyHandler(["error": "file not found"])
                }
            } else {
                print("⌚ ERROR: No fileName in message")
                replyHandler(["error": "no fileName"])
            }

        case "deleteSyncedFiles":
            // iPhone requesting to delete all synced files from watch
            print("⌚ Handling deleteSyncedFiles request")
            let filesOnIPhone = message["filesOnIPhone"] as? [String] ?? []
            handleDeleteSyncedFiles(filesOnIPhone: filesOnIPhone, replyHandler: replyHandler)

        default:
            replyHandler(["error": "unknown action"])
        }
    }

    // MARK: - Receive User Info (for confirmations)

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("⌚ Received user info: \(userInfo)")

        if let action = userInfo["action"] as? String, action == "fileReceived",
           let fileName = userInfo["fileName"] as? String {
            handleFileConfirmation(fileName: fileName)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚ Received message (no reply): \(message)")

        if let action = message["action"] as? String, action == "fileReceived",
           let fileName = message["fileName"] as? String {
            handleFileConfirmation(fileName: fileName)
        }
    }
}
