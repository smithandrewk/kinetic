//
//  ContentView.swift
//  iphone_sensor_app_no_claude
//
//  Created by Andrew Smith on 11/12/25.
//

import SwiftUI
import CoreMotion

/// Holds file metadata for display and sorting
struct FileInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let creationDate: Date
    let modificationDate: Date

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
    let motionRecorder = MotionRecorder()
    @State var fileInfos: [FileInfo] = []
    @State var sortOption: FileSortOption = .newestFirst
    @State var showEducationAlert = false
    @State var showShareSheet = false
    @State var filesToShare: [URL] = []
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
        VStack(spacing: 20) {
            // Educational banner about background recording
            VStack(alignment: .leading, spacing: 8) {
                Text("📱 Background Recording Active")
                    .font(.headline)
                Text("Keep this app in the background (don't force-quit) for continuous data collection. The app will process data automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Learn More") {
                    showEducationAlert = true
                }
                .font(.caption)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)

            if motionRecorder.checkAvailability() {
                Text("✅ Accelerometer is available")
                    .foregroundColor(.green)
            } else {
                Text("❌ Accelerometer is NOT available")
                    .foregroundColor(.red)
            }

            Button("Refresh Files") {
                refreshFiles()
            }
            .buttonStyle(.bordered)

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
                              // Filename
                              Text(fileInfo.fileName)
                                  .font(.system(.caption, design: .monospaced))

                              // File size
                              Text("\(fileInfo.size) bytes")
                                  .font(.caption2)
                                  .foregroundColor(.secondary)

                              // Creation date
                              Text("Created: \(formatDate(fileInfo.creationDate))")
                                  .font(.caption2)
                                  .foregroundColor(.secondary)

                              // Modification date (if different from creation)
                              if abs(fileInfo.modificationDate.timeIntervalSince(fileInfo.creationDate)) > 1 {
                                  Text("Modified: \(formatDate(fileInfo.modificationDate))")
                                      .font(.caption2)
                                      .foregroundColor(.secondary)
                              }
                          }
                          Spacer()
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
                  .onDelete(perform: deleteFiles)
              }
        }
        .onAppear {
            refreshFiles()
            // Show education alert on first launch
            if !UserDefaults.standard.bool(forKey: "hasSeenEducation") {
                showEducationAlert = true
                UserDefaults.standard.set(true, forKey: "hasSeenEducation")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
            refreshFiles()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(fileURLs: filesToShare)
        }
        .alert("How Background Recording Works", isPresented: $showEducationAlert) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("""
            This app records sensor data continuously in the background using CMSensorRecorder.

            ⚠️ Important:
            • DON'T force-quit the app (swipe up in app switcher)
            • Just press the home button to background the app
            • The app will automatically process and save data every 30 seconds while open
            • Data is saved in 30-minute chunks as CSV files

            If you force-quit or the device restarts:
            • Data up to 12 hours old will be recovered when you reopen the app
            • After 12 hours, unprocessed data is lost

            For best results, open the app at least once every 12 hours.
            """)
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
        fileInfos = motionRecorder.getCSVFilesWithMetadata()
        print("Refreshed file list: \(fileInfos.count) files")
    }

    /// Format a date for display in the file list
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
