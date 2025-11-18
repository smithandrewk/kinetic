//
//  MotionRecorder.swift
//  iphone_sensor_app_no_claude
//
//  File manager utility for Watch-synced sensor data
//  Note: iPhone no longer records sensor data - all recording happens on Apple Watch
//

import Foundation

/// File manager utility class for handling CSV files synced from Apple Watch
class CSVFileManager {

    /// Get all CSV files with metadata from iPhone's local storage
    /// These are files that have been synced from the Apple Watch
    /// Returns array of FileInfo objects that can be sorted by various criteria
    func getCSVFilesWithMetadata() -> [FileInfo] {
        let documentsURL = Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let watchDataDir = documentsURL.appendingPathComponent("watch_data")

        // Check if watch_data directory exists
        guard Foundation.FileManager.default.fileExists(atPath: watchDataDir.path) else {
            print("📱 watch_data directory doesn't exist yet")
            return []
        }

        do {
            // Request specific file attributes for better performance
            let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .creationDateKey, .fileSizeKey]
            let fileURLs = try Foundation.FileManager.default.contentsOfDirectory(
                at: watchDataDir,
                includingPropertiesForKeys: resourceKeys
            )

            let csvFiles = fileURLs.filter { $0.pathExtension == "csv" }

            // Map URLs to FileInfo objects with metadata
            return csvFiles.compactMap { url in
                do {
                    let attributes = try Foundation.FileManager.default.attributesOfItem(atPath: url.path)
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

                    let size = attributes[.size] as? Int64 ?? 0
                    let creationDate = resourceValues.creationDate ?? Date.distantPast
                    let modificationDate = resourceValues.contentModificationDate ?? Date.distantPast

                    return FileInfo(
                        url: url,
                        size: size,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        syncState: .synced, // Files in iPhone storage are already synced
                        sourceDevice: .watch
                    )
                } catch {
                    print("❌ Error reading attributes for \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
        } catch {
            print("❌ Error reading directory: \(error)")
            return []
        }
    }

    /// Legacy method that returns just URLs (kept for backward compatibility)
    func getCSVFiles() -> [URL] {
        return getCSVFilesWithMetadata().map { $0.url }
    }
}
