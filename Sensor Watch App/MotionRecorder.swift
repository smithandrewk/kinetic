//
//  MotionRecorder.swift
//  SensorWatch Watch App
//
//  Watch-optimized version for continuous sensor recording
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

class MotionRecorder {
    private let motion = CMMotionManager()
    private let sensorRecorder = CMSensorRecorder()

    // Constants for background recording configuration
    private let recordingDuration: TimeInterval = 12 * 60 * 60 // 12 hours (max allowed)
    private let chunkDuration: TimeInterval = 10 * 60 // 2 minutes per CSV file (for testing)

    // UserDefaults keys for tracking state
    private let lastProcessedDateKey = "lastProcessedDate"
    private let recordingStartDateKey = "recordingStartDate"

    // MARK: - Sensor Availability

    /// Check if accelerometer is available on this device
    func checkAvailability() -> Bool {
        if motion.isAccelerometerAvailable {
            print("✅ Accelerometer available on Apple Watch")
            return true
        } else {
            print("❌ Accelerometer NOT available")
            return false
        }
    }

    // MARK: - Debug Testing

    /// Comprehensive diagnostics for CMSensorRecorder
    func testDataRetrieval() {
        DispatchQueue.global(qos: .background).async {
            print("🧪 ========== CMSensorRecorder DIAGNOSTICS ==========")

            // 1. Check CMSensorRecorder authorization
            print("\n1️⃣ AUTHORIZATION CHECK:")
            let isAuthorized = CMSensorRecorder.isAuthorizedForRecording()
            print("   CMSensorRecorder.isAuthorizedForRecording(): \(isAuthorized)")

            if !isAuthorized {
                print("   ❌ NOT AUTHORIZED!")
                print("   Go to: Watch App Settings → Privacy → Motion & Fitness")
                print("   Enable 'Fitness Tracking' and grant permission to this app")
            }

            // 2. Check accelerometer availability
            print("\n2️⃣ ACCELEROMETER CHECK:")
            print("   CMMotionManager.isAccelerometerAvailable: \(self.motion.isAccelerometerAvailable)")

            // 3. Check recording status
            print("\n3️⃣ RECORDING STATUS:")
            if let recordingStartDate = UserDefaults.standard.object(forKey: self.recordingStartDateKey) as? Date {
                let elapsed = Date().timeIntervalSince(recordingStartDate)
                print("   Recording started at: \(recordingStartDate)")
                print("   Time since start: \(String(format: "%.1f", elapsed/60)) minutes")
                print("   Duration requested: \(self.recordingDuration/3600) hours")
            } else {
                print("   ⚠️  No recording start date in UserDefaults!")
                print("   Recording may not have been started properly")
            }

            // 4. Try SHORT recording test (20 seconds)
            print("\n4️⃣ SHORT RECORDING TEST (20 seconds):")
            print("   Starting NEW 20-second recording to test if recording works at all...")
            self.sensorRecorder.recordAccelerometer(forDuration: 20)
            print("   Recording started. Waiting 21 seconds...")
            Thread.sleep(forTimeInterval: 21)

            let testEnd = Date()
            let testStart = testEnd.addingTimeInterval(-20)
            print("   Attempting to retrieve data from the 20-second test:")
            self.testTimeRange(from: testStart, to: testEnd, label: "20s test")

            // 5. Try multiple time ranges from original recording
            print("\n5️⃣ ORIGINAL RECORDING DATA RETRIEVAL TESTS:")
            let now = Date()

            // Test A: Last 1 minute
            print("\n   Test A: Last 1 minute")
            self.testTimeRange(from: now.addingTimeInterval(-1 * 60), to: now, label: "1 min")

            // Test B: Last 5 minutes
            print("\n   Test B: Last 5 minutes")
            self.testTimeRange(from: now.addingTimeInterval(-5 * 60), to: now, label: "5 min")

            // Test C: Since recording started
            if let recordingStartDate = UserDefaults.standard.object(forKey: self.recordingStartDateKey) as? Date {
                print("\n   Test C: Since recording started")
                self.testTimeRange(from: recordingStartDate, to: now, label: "since start")
            }

            // Test D: Try immediate past (last 10 seconds)
            print("\n   Test D: Last 10 seconds")
            self.testTimeRange(from: now.addingTimeInterval(-10), to: now, label: "10 sec")

            print("\n🧪 ========== END DIAGNOSTICS ==========\n")
        }
    }

    /// Helper to test a specific time range
    private func testTimeRange(from: Date, to: Date, label: String) {
        print("      Testing range (\(label)):")
        print("      From: \(from)")
        print("      To:   \(to)")

        let data = self.sensorRecorder.accelerometerData(from: from, to: to)

        if data == nil {
            print("      ❌ NIL - No data available")
        } else {
            var count = 0
            for datum in data! {
                if let accelData = datum as? CMRecordedAccelerometerData {
                    if count < 3 {
                        print("      Sample \(count): x=\(String(format: "%.3f", accelData.acceleration.x)), y=\(String(format: "%.3f", accelData.acceleration.y)), z=\(String(format: "%.3f", accelData.acceleration.z))")
                    }
                    count += 1
                }
            }
            if count > 0 {
                print("      ✅ Retrieved \(count) samples")
            } else {
                print("      ⚠️  Data object exists but 0 samples inside")
            }
        }
    }

    // MARK: - Continuous Background Recording

    /// Start continuous background recording with CMSensorRecorder (12 hours)
    /// This records even when the watch screen is off and app is backgrounded
    func startContinuousRecording() {
        DispatchQueue.global(qos: .background).async {
            let now = Date()
            print("⌚ Starting continuous recording on Apple Watch for 12 hours...")
            self.sensorRecorder.recordAccelerometer(forDuration: self.recordingDuration)
            UserDefaults.standard.set(now, forKey: self.recordingStartDateKey)
            print("   Recording started at \(now)")
        }
    }

    /// Check if we need to restart recording (if >11 hours have passed)
    private func shouldRestartRecording() -> Bool {
        if let recordingStartDate = UserDefaults.standard.object(forKey: recordingStartDateKey) as? Date {
            let elapsed = Date().timeIntervalSince(recordingStartDate)
            let elevenHours: TimeInterval = 11 * 60 * 60

            if elapsed > elevenHours {
                print("⚠️  Recording has been running for \(String(format: "%.1f", elapsed/3600)) hours, needs restart")
                return true
            }
            print("✅ Recording has been running for \(String(format: "%.1f", elapsed/3600)) hours, still valid")
            return false
        }

        print("⚠️  No recording start date found, needs to start")
        return true
    }

    // MARK: - Data Processing

    /// Process and save any unprocessed sensor data
    /// Call this on app launch, app resume, and periodically via background tasks
    func processAndSaveUnprocessedData() {
        DispatchQueue.global(qos: .background).async {
            print("📦 Processing unprocessed sensor data on Apple Watch...")

            let now = Date()
            // Default to 12 hours ago if no last processed date
            let lastProcessedDate = UserDefaults.standard.object(forKey: self.lastProcessedDateKey) as? Date ?? now.addingTimeInterval(-12 * 60 * 60)

            print("   Last processed: \(lastProcessedDate)")
            print("   Current time: \(now)")

            // Retrieve all data since last processed time
            if let data = self.sensorRecorder.accelerometerData(from: lastProcessedDate, to: now) {
                print("   ✅ Found unprocessed data")

                // Break data into 30-minute chunks and save as CSV files
                self.saveDataInChunks(data: data, from: lastProcessedDate, to: now)
            } else {
                print("   ℹ️  No unprocessed data found")
            }

            // Check if we need to restart the 12-hour recording session
            if self.shouldRestartRecording() {
                print("   🔄 Restarting recording session...")
                self.startContinuousRecording()
            }
        }
    }

    /// Save sensor data in time-based chunks (30-minute periods)
    /// Only writes COMPLETE chunks - partial data is saved for next processing cycle
    private func saveDataInChunks(data: CMSensorDataList, from startDate: Date, to endDate: Date) {
        var currentChunkStart = startDate
        var currentChunkData: [(date: Date, x: Double, y: Double, z: Double)] = []
        var lastProcessedTimestamp = startDate

        var totalCount = 0
        var chunksWritten = 0

        // Process each accelerometer sample
        for datum in data {
            if let accelData = datum as? CMRecordedAccelerometerData {
                totalCount += 1

                let timestamp = accelData.startDate
                lastProcessedTimestamp = timestamp

                // If this sample is beyond current chunk duration (30 min), save chunk and start new one
                if timestamp.timeIntervalSince(currentChunkStart) > self.chunkDuration {
                    if !currentChunkData.isEmpty {
                        self.writeChunkToCSV(data: currentChunkData, startDate: currentChunkStart)
                        chunksWritten += 1
                        currentChunkData.removeAll()
                    }
                    currentChunkStart = timestamp
                }

                // Add sample to current chunk
                currentChunkData.append((
                    date: timestamp,
                    x: accelData.acceleration.x,
                    y: accelData.acceleration.y,
                    z: accelData.acceleration.z
                ))
            }
        }

        // DON'T write remaining partial data - wait for it to become a complete 30-minute chunk
        // Update lastProcessedDate to the start of the incomplete chunk so we retrieve it again next time
        if !currentChunkData.isEmpty {
            print("   ⏳ Incomplete chunk with \(currentChunkData.count) samples starting at \(currentChunkStart)")
            print("      Will process in next cycle")
            // Set lastProcessedDate to just before this incomplete chunk
            UserDefaults.standard.set(currentChunkStart.addingTimeInterval(-1), forKey: self.lastProcessedDateKey)
        } else {
            // All data was processed into complete chunks, update to current time
            UserDefaults.standard.set(lastProcessedTimestamp, forKey: self.lastProcessedDateKey)
        }

        print("   📊 Processed \(totalCount) samples, wrote \(chunksWritten) complete chunks")
    }

    /// Write a chunk of accelerometer data to a CSV file
    /// Format: timestamp,x,y,z (one row per sample)
    private func writeChunkToCSV(data: [(date: Date, x: Double, y: Double, z: Double)], startDate: Date) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        // Create filename with timestamp: sensor_data_2025-11-17_14-30-00.csv
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: startDate)
        let filename = "sensor_data_\(dateString).csv"
        let fileURL = documentsURL.appendingPathComponent(filename)

        do {
            // Create CSV content with headers
            var csvContent = "timestamp,x,y,z\n"

            // Add all data rows (timestamp in Unix epoch format)
            for sample in data {
                let timestamp = sample.date.timeIntervalSince1970
                csvContent += "\(timestamp),\(sample.x),\(sample.y),\(sample.z)\n"
            }

            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("   💾 Wrote \(data.count) samples to \(filename)")
        } catch {
            print("   ❌ Error writing chunk to CSV: \(error)")
        }
    }

    // MARK: - File Management

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
