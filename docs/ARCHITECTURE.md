# Technical Architecture

## System Overview

This document describes the technical architecture of the Apple Watch Sensor Recording App, including data flow, component interactions, and implementation details.

---

## High-Level Architecture

```
┌─────────────────────────────────────┐
│        Apple Watch App              │
│  ┌──────────────────────────────┐   │
│  │   SensorWatchApp.swift       │   │
│  │   - Background Timer (30s)   │   │
│  │   - File Detection           │   │
│  └──────────┬───────────────────┘   │
│             │                        │
│  ┌──────────▼───────────────────┐   │
│  │   MotionRecorder.swift       │   │
│  │   - CMSensorRecorder         │   │
│  │   - Data Processing          │   │
│  │   - CSV Writing              │   │
│  └──────────┬───────────────────┘   │
│             │                        │
│  ┌──────────▼───────────────────┐   │
│  │ WatchConnectivityManager     │   │
│  │   - File Transfer Queue      │   │
│  │   - Metadata Sync            │   │
│  │   - Confirmed Tracking       │   │
│  └──────────┬───────────────────┘   │
└─────────────┼───────────────────────┘
              │
              │ WatchConnectivity
              │ (iOS System)
              │
┌─────────────▼───────────────────────┐
│         iPhone App                  │
│  ┌──────────────────────────────┐   │
│  │ WatchConnectivityManager     │   │
│  │   - File Reception           │   │
│  │   - Metadata Handling        │   │
│  │   - Manual Sync Requests     │   │
│  └──────────┬───────────────────┘   │
│             │                        │
│  ┌──────────▼───────────────────┐   │
│  │   CSVFileManager.swift       │   │
│  │   - File Reading             │   │
│  │   - Metadata Parsing         │   │
│  └──────────┬───────────────────┘   │
│             │                        │
│  ┌──────────▼───────────────────┐   │
│  │   ContentView.swift          │   │
│  │   - File List UI             │   │
│  │   - Download/Share/Delete    │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## Component Breakdown

### Apple Watch Components

#### 1. SensorWatchApp.swift
**Responsibility**: App lifecycle and background processing orchestration

**Key Components**:
- `AppState`: Manages app-wide state
- Background timer (30-second interval)
- File count tracking
- WatchConnectivity initialization

**Background Timer Logic**:
```swift
Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
    // 1. Process sensor data
    self.motionRecorder.processAndSaveUnprocessedData()

    // 2. Detect new files
    let currentFileCount = self.motionRecorder.getCSVFiles().count
    if currentFileCount > self.previousFileCount {
        // 3. Queue for transfer
        let newFiles = Array(allFiles.suffix(currentFileCount - self.previousFileCount))
        for fileURL in newFiles {
            WatchConnectivityManager.shared.queueFileForTransfer(fileURL)
        }

        // 4. Update metadata
        WatchConnectivityManager.shared.syncFileMetadata()
    }
}
```

**Timer Behavior**:
- Runs on main RunLoop with `.common` mode (survives UI scrolling)
- Continues running when app is backgrounded (watchOS behavior)
- Stops when app is killed, restarts on app launch

#### 2. MotionRecorder.swift
**Responsibility**: Sensor data collection and CSV file writing

**Key Features**:
- Uses `CMSensorRecorder` for background accelerometer recording
- Writes 10-minute chunks to CSV files
- Only writes **complete** chunks (incomplete data stays in buffer)

**Data Flow**:
```swift
CMSensorRecorder Buffer (12 hours)
         ↓
processAndSaveUnprocessedData()
         ↓
saveDataInChunks() - Break into 10-min periods
         ↓
writeChunkToCSV() - Only complete chunks
         ↓
CSV File: sensor_data_YYYY-MM-DD_HH-mm-ss.csv
```

**Important Implementation Details**:
- Tracks `lastProcessedDate` in UserDefaults
- Never processes same data twice
- Restarts 12-hour recording when 11 hours elapsed
- Incomplete chunks are re-processed in next cycle

#### 3. WatchConnectivityManager.swift (Watch)
**Responsibility**: File transfer orchestration and sync state management

**Key Features**:
- File transfer queue management
- Metadata synchronization
- Confirmed transfers tracking (persisted in UserDefaults)
- Auto-delete with grace period

**Transfer Queue**:
```swift
private var transferQueue: [URL] = []
private var activeTransfers: Set<URL> = []
private let maxConcurrentTransfers = 3
```

**Confirmed Transfers** (Persistent):
```swift
private var confirmedTransfers: Set<String> {
    get {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "confirmedTransfers"),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return set
        }
        return []
    }
    set {
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(newValue) {
            UserDefaults.standard.set(data, forKey: "confirmedTransfers")
        }
    }
}
```

**WCSession Delegate Methods**:
- `activationDidCompleteWith`: Session initialization
- `sessionReachabilityDidChange`: Connection status updates
- `didReceiveMessage`: Handle sync/delete/transfer requests from iPhone
- `didReceiveUserInfo`: Handle transfer confirmations from iPhone

---

### iPhone Components

#### 1. WatchConnectivityManager.swift (iPhone)
**Responsibility**: File reception and sync coordination

**Key Features**:
- Receives files from Watch
- Manages pending files list
- Sends manual sync/delete/download requests
- Sends transfer confirmations

**Published Properties** (Observable):
```swift
@Published var isPaired: Bool = false
@Published var isWatchAppInstalled: Bool = false
@Published var isReachable: Bool = false
@Published var receivedFiles: [FileInfo] = []
@Published var pendingFiles: [FileInfo] = []
@Published var syncInProgress: Bool = false
```

**File Reception Flow**:
```swift
didReceive file: WCSessionFile
         ↓
saveReceivedFile()
         ↓
Move to Documents/watch_data/
         ↓
loadReceivedFiles() - Update receivedFiles
         ↓
Remove from pendingFiles
         ↓
sendTransferConfirmation() - Tell Watch
         ↓
Post notification - Refresh UI
```

**Metadata Update Flow**:
```swift
didReceiveApplicationContext
         ↓
updatePendingFiles()
         ↓
Parse metadata into FileInfo objects
         ↓
Filter out already-received files
         ↓
Update pendingFiles array
         ↓
Post notification - Refresh UI
```

#### 2. CSVFileManager.swift
**Responsibility**: Local file management and metadata extraction

**Key Features**:
- Reads files from `Documents/watch_data/`
- Extracts file metadata (size, dates)
- Parses data collection time from filename

**Filename Parsing**:
```swift
"sensor_data_2025-11-17_16-00-21.csv"
         ↓
Components: ["sensor", "data", "2025-11-17", "16-00-21.csv"]
         ↓
Date: "2025-11-17" Time: "16:00:21"
         ↓
DateFormatter: "yyyy-MM-dd HH:mm:ss"
         ↓
Date object: Nov 17, 2025 at 4:00:21 PM
```

#### 3. ContentView.swift
**Responsibility**: UI and user interaction

**Key Features**:
- File list display with sync states
- Download/Share/Delete actions
- Auto-refresh on app lifecycle events
- Transfer state tracking

**Sync State Management**:
```swift
@State var filesCurrentlyTransferring: Set<String> = []

// When download tapped
filesCurrentlyTransferring.insert(fileName)
         ↓
refreshFiles() - Mark as .transferring
         ↓
watchConnectivity.requestFile(fileName)

// When file received
refreshFiles() checks if file in syncedFiles
         ↓
Remove from filesCurrentlyTransferring
         ↓
UI updates: Progress → Share button
```

---

## Data Flow Diagrams

### Automatic File Transfer (Background)

```
Watch: Background Timer (30s)
         ↓
Detect new file created
         ↓
queueFileForTransfer(fileURL)
         ↓
WCSession.transferFile(fileURL, metadata)
         ↓
updateApplicationContext(metadata)
         ↓
[iOS WatchConnectivity System]
         ↓
iPhone: didReceive file: WCSessionFile
         ↓
Save to Documents/watch_data/
         ↓
Update receivedFiles
         ↓
Post RefreshFileList notification
         ↓
Watch: didReceiveUserInfo (confirmation)
         ↓
Mark as confirmed, schedule delete
```

### Manual Download (High Priority)

```
iPhone: User taps download arrow
         ↓
Mark as .transferring in UI
         ↓
sendMessage(["action": "transferFile", "fileName": "..."])
         ↓
[Requires Watch reachable]
         ↓
Watch: didReceiveMessage
         ↓
Remove from normal queue
         ↓
transferFile(fileURL, highPriority: true)
         ↓
WCSession.transferFile() with priority metadata
         ↓
Reply: ["status": "transferring"]
         ↓
[iOS handles immediate transfer]
         ↓
iPhone: didReceive file
         ↓
Save, remove from transferring set
         ↓
UI updates: Progress → Share
```

### Metadata Sync

```
Watch: File created or status changed
         ↓
syncFileMetadata()
         ↓
Get all CSV files with metadata
         ↓
Build context:
{
  "availableFiles": [
    {
      "fileName": "...",
      "size": 1859614,
      "creationDate": 1700236821.0,
      "dataDate": 1700236821.0
    },
    ...
  ],
  "lastUpdated": 1700240000.0
}
         ↓
updateApplicationContext(context)
         ↓
[iOS delivers when iPhone app active]
         ↓
iPhone: didReceiveApplicationContext
         ↓
updatePendingFiles(from: metadata)
         ↓
Create FileInfo with .pending state
         ↓
Filter out already-received
         ↓
Update pendingFiles array
         ↓
Post notification → UI refresh
```

---

## State Management

### File Sync States

```swift
enum SyncState {
    case pending      // Metadata known, file not yet transferred
    case transferring // Download in progress (manual)
    case synced       // File exists on iPhone
}
```

**State Transitions**:

```
Metadata arrives from Watch
         ↓
    .pending (greyed out, "⌚ On Watch" badge)
         ↓
User taps download OR automatic transfer completes
         ↓
    .transferring (progress indicator)
         ↓
File saved to Documents/watch_data/
         ↓
    .synced (Share button visible)
```

### Watch Confirmation Tracking

```swift
// Watch side
private var confirmedTransfers: Set<String>  // Persistent in UserDefaults
private var pendingDeletions: [String: Date] // Persistent in UserDefaults

// Flow
File transferred
         ↓
iPhone sends confirmation
         ↓
confirmedTransfers.insert(fileName)
         ↓
pendingDeletions[fileName] = Date()
         ↓
Timer checks every 5 minutes
         ↓
If confirmationTime > 5 minutes ago
         ↓
Delete file from Watch
         ↓
Update metadata
```

---

## WatchConnectivity Usage

### Transfer File (Background)

```swift
let transfer = WCSession.default.transferFile(fileURL, metadata: metadata)

// iOS handles:
// - Persistent queueing (survives app termination)
// - Opportunistic delivery (battery, connectivity, proximity)
// - Automatic retries (FIFO order)
// - Background operation (no app needs to be running)
```

**Metadata Structure**:
```swift
[
    "fileName": "sensor_data_2025-11-17_16-00-21.csv",
    "fileSize": 1859614,
    "timestamp": 1700236821.0,
    "priority": "high"  // Only for manual downloads
]
```

### Update Application Context (Metadata)

```swift
try WCSession.default.updateApplicationContext(context)

// Behavior:
// - Replaces previous context (only latest matters)
// - Delivered when iPhone app next becomes active
// - Works even if iPhone app is closed
// - Small data only (file list metadata, not files)
```

### Send Message (Manual Actions)

```swift
WCSession.default.sendMessage(message, replyHandler: { reply in
    // Handle response
}, errorHandler: { error in
    // Handle failure
})

// Requirements:
// - Both apps must be reachable (recently active or open)
// - Real-time bidirectional communication
// - Used for: manual download, sync request, delete request
```

### Transfer User Info (Confirmations)

```swift
WCSession.default.transferUserInfo(message)

// Behavior:
// - Queued delivery (like transferFile but for data)
// - Works when not reachable
// - Used for transfer confirmations
```

---

## File Storage

### Watch File System

```
Documents/
    sensor_data_2025-11-17_14-00-00.csv (1.8 MB)
    sensor_data_2025-11-17_14-10-00.csv (1.8 MB)
    sensor_data_2025-11-17_14-20-00.csv (1.8 MB)
    ...
```

### iPhone File System

```
Documents/
    watch_data/
        sensor_data_2025-11-17_14-00-00.csv (1.8 MB)
        sensor_data_2025-11-17_14-10-00.csv (1.8 MB)
        ...
```

### Persistent State (UserDefaults)

**Watch**:
```swift
// Confirmed transfers (survives app restart)
UserDefaults.standard.set(encodedSet, forKey: "confirmedTransfers")

// Pending deletions (survives app restart)
UserDefaults.standard.set(encodedDict, forKey: "pendingDeletions")

// Last processed date (for data continuity)
UserDefaults.standard.set(date, forKey: "lastProcessedDate")

// Recording start date (for 12-hour restart)
UserDefaults.standard.set(date, forKey: "recordingStartDate")
```

**iPhone**:
- No persistent state needed (files are the source of truth)

---

## Performance Considerations

### Battery Optimization

**Watch**:
- CMSensorRecorder is battery-efficient (uses motion coprocessor)
- Background timer runs on main thread (minimal impact)
- WCSession handles opportunistic transfer (iOS manages battery impact)

**iPhone**:
- File reception happens in background (negligible impact)
- UI updates only when app is active

### Storage Management

**Watch** (Limited Storage):
- Auto-delete confirmed files after 5 minutes
- User can manually delete via iPhone "Delete Synced" button
- CMSensorRecorder buffer: 12 hours max

**iPhone** (More Storage):
- Files accumulate in `Documents/watch_data/`
- User manually deletes or exports via Share sheet
- No automatic cleanup

### Network Efficiency

- WatchConnectivity uses Bluetooth when available (low power)
- Falls back to WiFi when needed
- iOS handles compression and chunking
- Transfers happen during idle time when possible

---

## Error Handling

### Watch Side

**Recording Errors**:
- Check `CMSensorRecorder.isAuthorizedForRecording()`
- Fall back gracefully if sensor unavailable
- Log errors, don't crash

**Transfer Errors**:
- WCSession handles retries automatically
- Log transfer failures
- Files remain queued until successful

### iPhone Side

**Reception Errors**:
- Check file exists before moving
- Create directories if needed
- Log failures, continue operation

**UI Errors**:
- Disable buttons when Watch not reachable
- Show connection status clearly
- Handle missing files gracefully

---

## Testing Considerations

### Unit Testing Focus Areas

1. **Filename Parsing**: `dataDate` computed property
2. **File Metadata Extraction**: CSVFileManager
3. **State Management**: Sync state transitions
4. **Persistent Storage**: Confirmed transfers encoding/decoding

### Integration Testing Focus Areas

1. **File Transfer**: End-to-end Watch → iPhone
2. **Metadata Sync**: Context updates
3. **Manual Actions**: Download, sync, delete
4. **Background Operation**: Timer continues when backgrounded

### Manual Testing Checklist

- [ ] Files auto-transfer in background (both apps closed)
- [ ] Metadata appears immediately on iPhone
- [ ] Manual download works (Watch reachable)
- [ ] Delete synced files frees Watch storage
- [ ] Recording continues when Watch screen off
- [ ] Files sorted by data collection time (not transfer time)
- [ ] Progress indicator updates correctly
- [ ] Share sheet exports files successfully

---

## Future Enhancements

### Potential Features

1. **Data Analysis**: Built-in visualization of sensor data
2. **Cloud Backup**: Automatic iCloud/Dropbox sync
3. **Data Export Formats**: JSON, Parquet, HDF5 options
4. **Recording Settings**: Configurable chunk duration, sample rate
5. **Storage Warnings**: Alert when Watch storage low
6. **Activity Detection**: Tag files with activity type
7. **Data Compression**: GZIP compress before transfer
8. **Batch Export**: Zip multiple files for easier sharing

### Architecture Improvements

1. **Core Data**: Replace file-based storage for better querying
2. **Background Tasks**: Use BGTaskScheduler for guaranteed processing
3. **Streaming**: Stream data directly instead of batching
4. **Delta Sync**: Only transfer new data since last sync
5. **Conflict Resolution**: Handle file naming conflicts
