//
//  MotionRecorder.swift
//  iphone_sensor_app_no_claude
//
//  Created by Andrew Smith on 11/12/25.
//

import Foundation
import CoreMotion

// Extension to make CMSensorDataList iterable in Swift
extension CMSensorDataList: Sequence {
    public typealias Iterator = NSFastEnumerationIterator
    public func makeIterator() -> NSFastEnumerationIterator {
        return NSFastEnumerationIterator(self)
    }
}

class MotionRecorder {
    private let motion = CMMotionManager()
    private let sensorRecorder = CMSensorRecorder()

    private var timer: Timer?

    // Constants for background recording configuration
    private let recordingDuration: TimeInterval = 12 * 60 * 60 // 12 hours (max allowed)
    private let chunkDuration: TimeInterval = 2 * 60 // 2 minutes per CSV file (for testing)

    // UserDefaults keys for tracking state
    private let lastProcessedDateKey = "lastProcessedDate"
    private let recordingStartDateKey = "recordingStartDate"

    // MARK: - Continuous Background Recording

    /// Start continuous background recording with CMSensorRecorder
    func startContinuousRecording() {
        DispatchQueue.global(qos: .background).async {
            let now = Date()
            print("Starting continuous CMSensorRecorder recording for 12 hours...")
            self.sensorRecorder.recordAccelerometer(forDuration: self.recordingDuration)
            UserDefaults.standard.set(now, forKey: self.recordingStartDateKey)
            print("Recording started at \(now)")
        }
    }

    /// Check if we need to restart recording (if >11 hours have passed)
    private func shouldRestartRecording() -> Bool {
        if let recordingStartDate = UserDefaults.standard.object(forKey: recordingStartDateKey) as? Date {
            let elapsed = Date().timeIntervalSince(recordingStartDate)
            let elevenHours: TimeInterval = 11 * 60 * 60

            if elapsed > elevenHours {
                print("Recording has been running for \(elapsed/3600) hours, needs restart")
                return true
            }
            print("Recording has been running for \(elapsed/3600) hours, still valid")
            return false
        }

        // No recording start date found, need to start
        print("No recording start date found, needs to start")
        return true
    }

    /// Process and save any unprocessed sensor data
    /// This should be called on app launch, app resume, and by BGProcessingTask
    func processAndSaveUnprocessedData() {
        DispatchQueue.global(qos: .background).async {
            print("Processing unprocessed sensor data...")

            let now = Date()
            let lastProcessedDate = UserDefaults.standard.object(forKey: self.lastProcessedDateKey) as? Date ?? now.addingTimeInterval(-12 * 60 * 60)

            print("Last processed: \(lastProcessedDate)")
            print("Current time: \(now)")

            // Retrieve all data since last processed time
            if let data = self.sensorRecorder.accelerometerData(from: lastProcessedDate, to: now) {
                print("Found unprocessed data from \(lastProcessedDate) to \(now)")

                // Break data into chunks by time period
                // This will update lastProcessedDate internally based on what was written
                self.saveDataInChunks(data: data, from: lastProcessedDate, to: now)
            } else {
                print("No unprocessed data found")
            }

            // Check if we need to restart recording (after ~11 hours)
            if self.shouldRestartRecording() {
                print("Restarting recording session...")
                self.startContinuousRecording()
            }
        }
    }

    /// Save sensor data in time-based chunks (e.g., 30-minute chunks)
    /// Only writes COMPLETE chunks - partial data is left for next processing cycle
    private func saveDataInChunks(data: CMSensorDataList, from startDate: Date, to endDate: Date) {
        var currentChunkStart = startDate
        var currentChunkData: [(date: Date, x: Double, y: Double, z: Double)] = []
        var lastProcessedTimestamp = startDate

        var totalCount = 0
        var chunksWritten = 0

        for datum in data {
            if let accelData = datum as? CMRecordedAccelerometerData {
                totalCount += 1

                let timestamp = accelData.startDate
                lastProcessedTimestamp = timestamp

                // If this sample is beyond current chunk duration, save chunk and start new one
                if timestamp.timeIntervalSince(currentChunkStart) > self.chunkDuration {
                    if !currentChunkData.isEmpty {
                        self.writeChunkToCSV(data: currentChunkData, startDate: currentChunkStart)
                        chunksWritten += 1
                        currentChunkData.removeAll()
                    }
                    currentChunkStart = timestamp
                }

                currentChunkData.append((
                    date: timestamp,
                    x: accelData.acceleration.x,
                    y: accelData.acceleration.y,
                    z: accelData.acceleration.z
                ))
            }
        }

        // DON'T write remaining partial data - wait for it to become a complete 30-minute chunk
        // Update lastProcessedDate to the start of the incomplete chunk so we can retrieve it again next time
        if !currentChunkData.isEmpty {
            print("Incomplete chunk with \(currentChunkData.count) samples starting at \(currentChunkStart) - will process next time")
            // Update lastProcessedDate to just before this incomplete chunk
            UserDefaults.standard.set(currentChunkStart.addingTimeInterval(-1), forKey: self.lastProcessedDateKey)
        }

        print("Processed total of \(totalCount) samples, wrote \(chunksWritten) complete chunks")
    }

    /// Write a chunk of data to a CSV file
    private func writeChunkToCSV(data: [(date: Date, x: Double, y: Double, z: Double)], startDate: Date) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: startDate)
        let filename = "sensor_data_\(dateString).csv"
        let fileURL = documentsURL.appendingPathComponent(filename)

        do {
            // Create file with headers
            var csvContent = "timestamp,x,y,z\n"

            // Add all data rows
            for sample in data {
                let timestamp = sample.date.timeIntervalSince1970
                csvContent += "\(timestamp),\(sample.x),\(sample.y),\(sample.z)\n"
            }

            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Wrote \(data.count) samples to \(filename)")
        } catch {
            print("Error writing chunk to CSV: \(error)")
        }
    }

    func checkAvailability () -> Bool {
        if motion.isAccelerometerAvailable {
            print("Available!")
            return true
        } else {
            return false
        }
    }
    
    // Old CMMotionManager start/stop methods removed - we only use CMSensorRecorder now for automatic background recording
    
    /// Get all CSV files with metadata (size, creation date, modification date)
    /// Returns array of FileInfo objects that can be sorted by various criteria
    func getCSVFilesWithMetadata() -> [FileInfo] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            // Request specific file attributes for better performance
            let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .creationDateKey, .fileSizeKey]
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: resourceKeys
            )

            let csvFiles = fileURLs.filter { $0.pathExtension == "csv" }

            // Map URLs to FileInfo objects with metadata
            return csvFiles.compactMap { url in
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
                        modificationDate: modificationDate
                    )
                } catch {
                    print("Error reading attributes for \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
        } catch {
            print("Error reading directory: \(error)")
            return []
        }
    }

    /// Legacy method that returns just URLs (kept for backward compatibility)
    func getCSVFiles() -> [URL] {
        return getCSVFilesWithMetadata().map { $0.url }
    }
}
