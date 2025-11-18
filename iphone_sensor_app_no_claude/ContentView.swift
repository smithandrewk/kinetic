//
//  ContentView.swift
//  iphone_sensor_app_no_claude
//
//  Created by Andrew Smith on 11/12/25.
//

import SwiftUI

/// File synchronization state
enum SyncState: String, Codable, Hashable {
    case pending      // Metadata known, file not yet transferred from watch
    case transferring // Transfer in progress
    case synced       // Successfully transferred and saved to iPhone
}

/// Source device for the file
enum DeviceType: String, Codable, Hashable {
    case watch
    case phone // Reserved for future use if phone recording is re-enabled
}

/// Holds file metadata for display and sorting
struct FileInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let creationDate: Date
    let modificationDate: Date
    var syncState: SyncState = .synced
    var transferProgress: Double = 0.0
    var sourceDevice: DeviceType = .watch

    var fileName: String {
        url.lastPathComponent
    }

    /// The actual data collection date parsed from the filename
    /// Format: sensor_data_2025-11-17_14-30-00.csv
    /// Falls back to file creation date if parsing fails
    var dataDate: Date {
        let filename = url.lastPathComponent

        // Extract the date portion: "sensor_data_YYYY-MM-DD_HH-mm-ss.csv"
        // Pattern: sensor_data_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})
        let components = filename.components(separatedBy: "_")

        // Need at least: ["sensor", "data", "YYYY-MM-DD", "HH-mm-ss.csv"]
        guard components.count >= 4,
              components[0] == "sensor",
              components[1] == "data" else {
            // Fallback to creation date if filename doesn't match expected format
            return creationDate
        }

        let datePart = components[2] // "YYYY-MM-DD"
        let timePart = components[3].replacingOccurrences(of: ".csv", with: "") // "HH-mm-ss"

        // Combine into ISO 8601 format: "YYYY-MM-DD HH:mm:ss"
        let dateTimeString = "\(datePart) \(timePart.replacingOccurrences(of: "-", with: ":"))"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current

        if let parsedDate = dateFormatter.date(from: dateTimeString) {
            return parsedDate
        } else {
            // Fallback to creation date if parsing fails
            return creationDate
        }
    }
}

/// Sorting options for the file list
enum FileSortOption: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case largestFirst = "Largest First"
    case smallestFirst = "Smallest First"
}

struct ContentView: View {
    let csvFileManager = CSVFileManager()
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State var fileInfos: [FileInfo] = []
    @State var sortOption: FileSortOption = .newestFirst
    @State var showShareSheet = false
    @State var filesToShare: [URL] = []
    @State var showDeleteAllConfirmation = false
    @State var filesCurrentlyTransferring: Set<String> = [] // Track files being downloaded

    /// Returns sorted files based on current sort option
    var sortedFiles: [FileInfo] {
        switch sortOption {
        case .nameAscending:
            return fileInfos.sorted { $0.fileName < $1.fileName }
        case .nameDescending:
            return fileInfos.sorted { $0.fileName > $1.fileName }
        case .newestFirst:
            return fileInfos.sorted { $0.dataDate > $1.dataDate }
        case .oldestFirst:
            return fileInfos.sorted { $0.dataDate < $1.dataDate }
        case .largestFirst:
            return fileInfos.sorted { $0.size > $1.size }
        case .smallestFirst:
            return fileInfos.sorted { $0.size < $1.size }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header for Watch File Manager
            VStack(alignment: .leading, spacing: 8) {
                Text("⌚ Apple Watch Sensor Data")
                    .font(.headline)
                Text("Files are automatically synced from your Apple Watch")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Watch connectivity status
                HStack(spacing: 8) {
                    Circle()
                        .fill(watchConnectivity.isReachable ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(watchConnectivity.isReachable ? "Watch Connected" : "Watch Not Reachable")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if watchConnectivity.syncInProgress {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Syncing...")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)

            HStack(spacing: 10) {
                Button(action: {
                    watchConnectivity.requestSyncFromWatch()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Sync from Watch")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!watchConnectivity.isReachable || watchConnectivity.syncInProgress)

                Button(action: {
                    watchConnectivity.requestDeleteSyncedFilesOnWatch()
                }) {
                    HStack {
                        Image(systemName: "trash.circle")
                        Text("Delete Synced")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!watchConnectivity.isReachable)
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Files: \(fileInfos.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Sort picker
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(FileSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }

                HStack(spacing: 10) {
                    Spacer()

                    Button("Share All") {
                        if !fileInfos.isEmpty {
                            filesToShare = fileInfos.map { $0.url }
                            showShareSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(fileInfos.isEmpty)

                    Button("Delete All") {
                        showDeleteAllConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(fileInfos.isEmpty)
                }
            }
            .padding(.horizontal)

            List {
                  ForEach(sortedFiles) { fileInfo in
                      HStack {
                          VStack(alignment: .leading, spacing: 4) {
                              // Date and time (parsed from filename) with sync state badge
                              HStack(spacing: 6) {
                                  Text(formatDataDate(fileInfo.dataDate))
                                      .font(.system(.body, design: .default))
                                      .fontWeight(.medium)
                                      .opacity(fileInfo.syncState == .pending ? 0.5 : 1.0)

                                  // Sync state badge
                                  if fileInfo.syncState == .pending {
                                      Text("⌚ On Watch")
                                          .font(.caption2)
                                          .padding(.horizontal, 6)
                                          .padding(.vertical, 2)
                                          .background(Color.orange.opacity(0.2))
                                          .cornerRadius(4)
                                  } else if fileInfo.syncState == .transferring {
                                      ProgressView()
                                          .scaleEffect(0.6)
                                  }
                              }

                              // File size
                              Text(formatFileSize(fileInfo.size))
                                  .font(.caption2)
                                  .foregroundColor(.secondary)
                                  .opacity(fileInfo.syncState == .pending ? 0.5 : 1.0)
                          }
                          Spacer()

                          if fileInfo.syncState == .pending {
                              // Download button for pending files
                              Button(action: {
                                  print("📱 Requesting download of: \(fileInfo.fileName)")
                                  // Add to transferring set
                                  filesCurrentlyTransferring.insert(fileInfo.fileName)
                                  // Refresh to update UI
                                  refreshFiles()
                                  // Request file from watch
                                  watchConnectivity.requestFile(fileInfo.fileName)
                              }) {
                                  Image(systemName: "arrow.down.circle")
                              }
                              .buttonStyle(.bordered)
                              .disabled(!watchConnectivity.isReachable)
                          } else if fileInfo.syncState == .transferring {
                              // Show progress indicator
                              ProgressView()
                                  .scaleEffect(0.8)
                          } else {
                              // Share button for synced files
                              Button("Share") {
                                  // Check if file exists before sharing
                                  if FileManager.default.fileExists(atPath: fileInfo.url.path) {
                                      filesToShare = [fileInfo.url]
                                      showShareSheet = true
                                  } else {
                                      print("File doesn't exist: \(fileInfo.url.path)")
                                  }
                              }
                              .buttonStyle(.bordered)
                          }
                      }
                  }
                  .onDelete(perform: deleteFiles)
              }
        }
        .onAppear {
            print("📱 ContentView appeared - loading files")
            refreshFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
            print("📱 Received RefreshFileList notification")
            refreshFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("📱 App entering foreground - refreshing files")
            refreshFiles()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(fileURLs: filesToShare)
        }
        .alert("Delete All Files?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllFiles()
            }
        } message: {
            Text("Are you sure you want to delete all \(fileInfos.count) files? This cannot be undone.")
        }
    }

    func refreshFiles() {
        // Combine locally synced files with pending files from watch
        let syncedFiles = csvFileManager.getCSVFilesWithMetadata()
        var allFiles = syncedFiles + watchConnectivity.pendingFiles

        // Get set of synced file names for quick lookup
        let syncedFileNames = Set(syncedFiles.map { $0.fileName })

        // Remove files from transferring set if they're now synced
        let completedTransfers = filesCurrentlyTransferring.intersection(syncedFileNames)
        if !completedTransfers.isEmpty {
            print("📱 Completed transfers: \(completedTransfers)")
            filesCurrentlyTransferring.subtract(completedTransfers)
        }

        // Mark files that are currently transferring
        for i in 0..<allFiles.count {
            if filesCurrentlyTransferring.contains(allFiles[i].fileName) {
                allFiles[i].syncState = .transferring
            }
        }

        fileInfos = allFiles
        print("📱 Refreshed file list: \(syncedFiles.count) synced, \(watchConnectivity.pendingFiles.count) pending, \(filesCurrentlyTransferring.count) transferring")
    }

    /// Format the data collection date for display (primary display)
    func formatDataDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a"
        return formatter.string(from: date)
    }

    /// Format file size in human-readable format
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Format a date for display (legacy, kept for compatibility)
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func deleteFiles(at offsets: IndexSet) {
        // Get the sorted files (since that's what's displayed)
        let sorted = sortedFiles

        // First delete from filesystem
        for index in offsets {
            let fileInfo = sorted[index]
            do {
                try FileManager.default.removeItem(at: fileInfo.url)
                print("Deleted file: \(fileInfo.fileName)")
            } catch {
                print("Error deleting file: \(error)")
            }
        }

        // Remove from fileInfos array by matching URLs
        let urlsToRemove = offsets.map { sorted[$0].url }
        fileInfos.removeAll { fileInfo in
            urlsToRemove.contains(fileInfo.url)
        }
    }

    func deleteAllFiles() {
        // Delete all files from filesystem
        for fileInfo in fileInfos {
            do {
                try FileManager.default.removeItem(at: fileInfo.url)
                print("Deleted file: \(fileInfo.fileName)")
            } catch {
                print("Error deleting file: \(error)")
            }
        }

        // Clear the fileInfos array
        fileInfos.removeAll()
        print("Deleted all files")
    }
}


struct ShareSheet: UIViewControllerRepresentable {
      let fileURLs: [URL]

      func makeUIViewController(context: Context) -> UIActivityViewController {
          UIActivityViewController(activityItems: fileURLs, applicationActivities: nil)
      }

      func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
  }
