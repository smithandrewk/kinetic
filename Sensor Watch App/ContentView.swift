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
    @State var fileInfos: [FileInfo] = []
    @State var sortOption: FileSortOption = .newestFirst
    @State var showDeleteAllConfirmation = false

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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                    // Debug Test Button
                    Button {
                        motionRecorder.testDataRetrieval()
                    } label: {
                        Label("Test Data Fetch", systemImage: "ant.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    // Files Section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Files: \(fileInfos.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Refresh button
                            Button {
                                refreshFiles()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        // Sort picker - compact for watch
                        Picker("Sort", selection: $sortOption) {
                            ForEach(FileSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .font(.caption2)
                    }

                    // Action Buttons
                    HStack(spacing: 8) {
                        // Share All button
                        NavigationLink {
                            ShareAllView(fileURLs: fileInfos.map { $0.url })
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .disabled(fileInfos.isEmpty)

                        // Delete All button
                        Button {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("Delete All", systemImage: "trash")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(fileInfos.isEmpty)
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
                                NavigationLink {
                                    FileDetailView(fileInfo: fileInfo, onDelete: {
                                        deleteFile(fileInfo)
                                    })
                                } label: {
                                    FileRowView(fileInfo: fileInfo)
                                }
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
        .confirmationDialog("Delete All Files?", isPresented: $showDeleteAllConfirmation, titleVisibility: .visible) {
            Button("Delete All (\(fileInfos.count))", role: .destructive) {
                deleteAllFiles()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Helper Functions

    func refreshFiles() {
        fileInfos = motionRecorder.getCSVFilesWithMetadata()
        print("⌚ Refreshed file list: \(fileInfos.count) files")
    }

    func deleteFile(_ fileInfo: FileInfo) {
        do {
            try FileManager.default.removeItem(at: fileInfo.url)
            print("⌚ Deleted file: \(fileInfo.fileName)")
            fileInfos.removeAll { $0.id == fileInfo.id }
        } catch {
            print("❌ Error deleting file: \(error)")
        }
    }

    func deleteAllFiles() {
        for fileInfo in fileInfos {
            do {
                try FileManager.default.removeItem(at: fileInfo.url)
                print("⌚ Deleted file: \(fileInfo.fileName)")
            } catch {
                print("❌ Error deleting file: \(error)")
            }
        }
        fileInfos.removeAll()
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

// MARK: - File Detail View

/// Detailed view for a single file with share/delete options
struct FileDetailView: View {
    let fileInfo: FileInfo
    let onDelete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Filename
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filename")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(fileInfo.fileName)
                        .font(.system(.caption2, design: .monospaced))
                }

                Divider()

                // File Size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(fileInfo.size) bytes")
                        .font(.caption2)
                }

                Divider()

                // Creation Date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatFullDate(fileInfo.creationDate))
                        .font(.caption2)
                }

                Divider()

                // Modification Date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Modified")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatFullDate(fileInfo.modificationDate))
                        .font(.caption2)
                }

                // Action Buttons
                VStack(spacing: 8) {
                    Button {
                        shareFile()
                    } label: {
                        Label("Share File", systemImage: "square.and.arrow.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete File", systemImage: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("File Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete File?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func shareFile() {
        // Placeholder - will implement WatchConnectivity transfer to iPhone
        print("⌚ Share file: \(fileInfo.fileName)")
    }
}

// MARK: - Share All View

/// View for sharing all files
struct ShareAllView: View {
    let fileURLs: [URL]

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.largeTitle)
                .foregroundColor(.blue)

            Text("Share \(fileURLs.count) Files")
                .font(.caption)

            Text("Transfer to iPhone coming soon")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Share via iPhone") {
                // Placeholder for WatchConnectivity transfer
                print("⌚ Share \(fileURLs.count) files to iPhone")
            }
            .buttonStyle(.borderedProminent)

            Text("Note: File sharing will be implemented using WatchConnectivity to automatically transfer files to the paired iPhone.")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Share Files")
        .navigationBarTitleDisplayMode(.inline)
    }
}
