//
//  ContentView.swift
//  SensorWatch Watch App
//
//  Apple Watch UI for continuous sensor data recording
//

import SwiftUI
import CoreMotion

/// Sorting options for the file list
enum FileSortOption: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case nameAscending = "Name A-Z"
    case nameDescending = "Name Z-A"
    case largestFirst = "Largest"
    case smallestFirst = "Smallest"
}

struct ContentView: View {
    let motionRecorder = MotionRecorder()
    @ObservedObject var watchConnectivity = WatchConnectivityManager.shared
    @State var fileInfos: [FileInfo] = []
    @State var sortOption: FileSortOption = .newestFirst

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status Section
                    VStack(spacing: 8) {
                        if motionRecorder.checkAvailability() {
                            Label("Sensor Ready", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("Sensor Unavailable", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Text("Recording in Background")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Sync status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(watchConnectivity.isPaired ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text(watchConnectivity.isPaired ? "📱 Paired" : "Not Paired")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            if watchConnectivity.filesTransferring > 0 {
                                Text("• \(watchConnectivity.filesTransferring) syncing")
                                    .font(.system(size: 9))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                    // Files Section Header
                    HStack {
                        Text("Files: \(fileInfos.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    // File List
                    if fileInfos.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No Files Yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(sortedFiles) { fileInfo in
                                FileRowView(fileInfo: fileInfo)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Sensor Watch")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            refreshFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
            refreshFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationWillEnterForegroundNotification)) { _ in
            refreshFiles()
        }
    }

    // MARK: - Helper Functions

    func refreshFiles() {
        fileInfos = motionRecorder.getCSVFilesWithMetadata()
        print("⌚ Refreshed file list: \(fileInfos.count) files")
    }
}

// MARK: - File Row View

/// Compact file row for watch display
struct FileRowView: View {
    let fileInfo: FileInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fileInfo.fileName)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)

            HStack {
                Text(formatSize(fileInfo.size))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Text(formatDate(fileInfo.creationDate))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024) KB"
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

