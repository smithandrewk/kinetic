# Background Recording Setup Instructions

This app now supports continuous background recording using CMSensorRecorder and BGProcessingTask.

## Required Info.plist Configuration

You need to add the following to your app's Info.plist (or in Xcode project settings):

### 1. Add Background Modes

In Xcode:
1. Select your project in the Project Navigator
2. Select your target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Background Modes"
6. Check "Background processing"

Or add to Info.plist:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

### 2. Register Background Task Identifier

Add this to Info.plist:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.yourapp.processensordata</string>
</array>
```

**IMPORTANT**: Replace `com.yourapp.processensordata` with your actual app's bundle identifier prefix if needed. The identifier in the code (iphone_sensor_app_no_claudeApp.swift:27) must match this exactly.

### 3. Motion Usage Description

Add this if not already present:
```xml
<key>NSMotionUsageDescription</key>
<string>This app needs access to motion sensors to record accelerometer data continuously in the background.</string>
```

## How It Works

### Automatic Recording
- On app launch: The app starts a 12-hour CMSensorRecorder recording session
- Every 2 hours: BGProcessingTask wakes up to process and save data to CSV files
- On app resume: The app processes any data accumulated while backgrounded

### Data Storage
- Data is saved in 2-hour chunks
- Files are named: `sensor_data_YYYY-MM-DD_HH-mm-ss.csv`
- Format: `timestamp,x,y,z` (timestamp is Unix epoch)

### User Responsibilities
- Don't force-quit the app (swipe up in app switcher)
- Just press home button to background the app
- Open the app at least once every 12 hours to ensure no data loss

### Limitations
- If device reboots: Recording stops, resumes when app is opened
- If force-quit: Background tasks stop, resume when app is opened
- If >12 hours pass without opening app: Unprocessed data older than 12 hours is lost

## Testing Background Tasks

To test BGProcessingTask in simulator:

1. Run the app in Xcode
2. Background the app
3. In Xcode debug console, run:
   ```
   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.yourapp.processensordata"]
   ```
4. Check console logs to see background task execution

## Architecture

### Components

1. **MotionRecorder** (MotionRecorder.swift)
   - `startContinuousRecording()`: Starts 12-hour CMSensorRecorder session
   - `processAndSaveUnprocessedData()`: Retrieves and saves data since last processed time
   - `saveDataInChunks()`: Breaks data into 2-hour chunks
   - `writeChunkToCSV()`: Writes data to CSV files

2. **AppDelegate** (iphone_sensor_app_no_claudeApp.swift)
   - Registers and schedules BGProcessingTask
   - Handles app lifecycle events (launch, background, foreground)
   - Coordinates data processing

3. **ContentView** (ContentView.swift)
   - Displays user education about background recording
   - Shows list of CSV files
   - Allows sharing of data files

### Data Flow

```
App Launch
    ↓
Start 12-hour CMSensorRecorder recording
    ↓
Schedule BGProcessingTask (2 hours)
    ↓
[Every 2 hours or when app resumes]
    ↓
Retrieve data since last processed time
    ↓
Break into 2-hour chunks
    ↓
Write each chunk to CSV
    ↓
Update last processed timestamp
    ↓
Restart 12-hour recording if needed
```

## Monitoring

Check console logs for:
- "Starting continuous CMSensorRecorder recording for 12 hours..."
- "Background task scheduled for [date]"
- "Processing data in background task..."
- "Wrote [N] samples to sensor_data_[timestamp].csv"

## Troubleshooting

**Background tasks not running:**
- Ensure Info.plist is configured correctly
- Check that identifier matches in code and Info.plist
- Background tasks don't run reliably in simulator - test on device
- iOS decides when to run background tasks based on usage patterns

**Data gaps:**
- Check if app was force-quit
- Check if device was rebooted
- Check if >12 hours passed without opening app

**No data being saved:**
- Check motion permissions
- Verify CMSensorRecorder.isAccelerometerRecordingAvailable()
- Check console for error messages
