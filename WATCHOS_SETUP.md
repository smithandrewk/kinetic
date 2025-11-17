# Apple Watch Sensor Recording App - Setup Guide

This guide will help you add the watchOS sensor recording app to your Xcode project.

## Overview

The watchOS app has been created in the `SensorWatch Watch App/` directory with all necessary files:

- **SensorWatchApp.swift** - App entry point with background task handling
- **ContentView.swift** - Watch-optimized UI with file management
- **MotionRecorder.swift** - Core sensor recording logic (identical API to iOS version)
- **Info.plist** - Permissions and background mode configuration
- **Assets.xcassets/** - App icon and assets configuration

## Features

✅ Continuous background sensor recording (12-hour sessions with auto-restart)
✅ 30-minute data chunks saved as CSV files
✅ Watch-optimized compact UI
✅ File sorting by date, name, or size
✅ Individual file viewing and deletion
✅ Share all files functionality
✅ 10-second test recording feature
✅ Automatic data processing every 30 seconds

## Step-by-Step Setup in Xcode

### Step 1: Add watchOS App Target

1. Open your project in Xcode: `iphone_sensor_app_no_claude.xcodeproj`

2. Click **File** → **New** → **Target**

3. Select **watchOS** → **Watch App** template

4. Configure the target:
   - **Product Name**: `SensorWatch`
   - **Organization Identifier**: (use your existing identifier)
   - **Bundle Identifier**: `com.yourorg.iphone-sensor-app-no-claude.SensorWatch`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - Uncheck "Include Notification Scene" (not needed)

5. Click **Finish**

6. When Xcode asks about activating the scheme, click **Activate**

### Step 2: Replace Generated Files

Xcode will create some template files. Replace them with our custom implementation:

1. **Delete** the generated files in the `SensorWatch Watch App` group:
   - `SensorWatchApp.swift` (we'll replace it)
   - `ContentView.swift` (we'll replace it)

2. **Add existing files** to the target:
   - Right-click on `SensorWatch Watch App` group in Xcode
   - Select **Add Files to "iphone_sensor_app_no_claude"...**
   - Navigate to `SensorWatch Watch App/` folder
   - Select all `.swift` files:
     - `SensorWatchApp.swift`
     - `ContentView.swift`
     - `MotionRecorder.swift`
   - Make sure **"Copy items if needed"** is UNCHECKED (files are already in place)
   - Make sure **"Add to targets"** has `SensorWatch Watch App` checked
   - Click **Add**

### Step 3: Configure Info.plist

1. Select the watch app target in Xcode

2. Go to the **Info** tab

3. Add the following key (or verify it's there):
   - **Key**: Privacy - Motion Usage Description
   - **Type**: String
   - **Value**: "This app continuously records accelerometer data in the background for motion analysis. Data is saved to CSV files on your Apple Watch for later export."

4. Add background modes:
   - Go to **Signing & Capabilities** tab
   - Click **+ Capability**
   - Add **Background Modes**
   - Check **"Workout Processing"**

Alternatively, replace the generated Info.plist with the one in `SensorWatch Watch App/Info.plist`

### Step 4: Configure Signing

1. Select the **SensorWatch Watch App** target

2. Go to **Signing & Capabilities** tab

3. Enable **Automatically manage signing**

4. Select your **Team**

5. Xcode will automatically provision the watch app

### Step 5: Build and Run

1. Connect your iPhone (with paired Apple Watch)

2. Select the watch app scheme: **SensorWatch Watch App** from the scheme selector

3. Select your Apple Watch as the destination

4. Click **Run** (▶️)

5. The app will install on your Apple Watch

## How It Works

### Automatic Background Recording

The app uses `CMSensorRecorder` which records sensor data even when:
- The watch screen is off
- The app is backgrounded
- The user is not interacting with the watch

### Data Collection Process

1. **On Launch**:
   - Starts a 12-hour recording session
   - Processes any unprocessed data from previous sessions
   - Schedules periodic processing timer

2. **While Running**:
   - Every 30 seconds, checks for new sensor data
   - Breaks data into 30-minute chunks
   - Saves complete chunks as CSV files

3. **Background Refresh**:
   - Schedules watchOS background refresh tasks
   - Processes data when system allows
   - Auto-restarts recording after 11 hours

### CSV File Format

Each file contains accelerometer data in this format:

```csv
timestamp,x,y,z
1700234567.123,0.012,-0.998,0.045
1700234567.143,0.015,-0.995,0.048
...
```

- **timestamp**: Unix epoch time (seconds since Jan 1, 1970)
- **x, y, z**: Acceleration in g-forces along each axis

### File Naming

Files are named with the timestamp they started recording:
```
sensor_data_2025-11-17_14-30-00.csv
```

## Usage Tips

### Best Practices

1. **Keep Watch Charged**: Recording uses minimal battery, but keep the watch charged overnight

2. **Don't Force-Quit**: Just press the Digital Crown to exit - don't swipe up to force-quit

3. **Open App Regularly**: Open the app once every 12 hours to ensure data is processed

4. **Check Storage**: Each 30-minute chunk is typically 1-3 MB. Monitor available storage.

### Testing the App

1. **Test 10-Second Recording**:
   - Tap "Test 10s" button
   - Move the watch around
   - Check Xcode console for sample count (should see ~500 samples @ 50Hz)

2. **Verify File Creation**:
   - Let the app run for 30+ minutes
   - Refresh the file list
   - You should see a new CSV file appear

3. **Check Console Logs**:
   - Watch Xcode console for log messages
   - Look for: "✅ Recording started", "📊 Processed X samples"

## Troubleshooting

### No Files Appearing

**Problem**: App runs but no files are created after 30 minutes

**Solutions**:
- Check that motion permission was granted (Settings → Privacy → Motion & Fitness)
- Verify "Fitness Tracking" is enabled on iPhone (Settings → Privacy → Motion & Fitness)
- Move the watch around during recording (CMSensorRecorder may not record if completely stationary)
- Check Xcode console for error messages

### "Sensor Unavailable" Message

**Problem**: Red "Sensor Unavailable" message shows

**Solutions**:
- Restart the Apple Watch
- Re-pair the watch with iPhone if issue persists
- Verify watch has accelerometer (all watches Series 1+ should have it)

### Background Recording Not Working

**Problem**: Data only records when app is open

**Solutions**:
- Verify Info.plist has NSMotionUsageDescription key
- Check Background Modes capability is enabled
- Don't force-quit the app (just press Digital Crown)
- Ensure watch isn't in Power Reserve mode

### Build Errors

**Problem**: Xcode shows build errors

**Solutions**:
- Clean build folder: **Product** → **Clean Build Folder** (⇧⌘K)
- Verify all files are added to watch app target (check Target Membership in File Inspector)
- Update deployment target to watchOS 9.0+ in target settings
- Restart Xcode

## Architecture Notes

### Why watchOS Instead of iOS?

**Advantages of Watch Recording:**
- ✅ Worn consistently (24/7 potential)
- ✅ Better for wrist motion capture
- ✅ People less likely to force-quit watch apps
- ✅ Always with the user (phone might be left behind)

**Considerations:**
- ⚠️ Limited storage space (manage file count)
- ⚠️ Smaller screen for UI
- ⚠️ Background tasks less predictable than iOS

### CMSensorRecorder on watchOS

The CMSensorRecorder API works identically on watchOS and iOS:
- Same 12-hour recording limit
- Same ~50Hz sampling rate for accelerometer
- Same data retrieval methods
- Same background recording capabilities

### UI Differences from iOS Version

**Watch UI Optimizations:**
- More compact file rows
- Navigation-based interface (no tabs)
- Smaller fonts and tighter spacing
- Simplified share functionality
- Confirmation dialogs instead of alerts

## Data Export Options

### Option 1: Transfer to iPhone (Future Enhancement)

You can implement WatchConnectivity to automatically transfer files to the iPhone app:

```swift
import WatchConnectivity

// Send file to iPhone
WCSession.default.transferFile(fileURL, metadata: nil)
```

### Option 2: AirDrop from Watch

Users can AirDrop files directly from the watch to nearby devices (Mac, iPhone, iPad).

### Option 3: iCloud Sync

Add iCloud capability and save files to iCloud Drive for automatic sync.

## Next Steps

### Recommended Enhancements

1. **WatchConnectivity Integration**
   - Auto-transfer files to iPhone
   - View watch files in iPhone app
   - Unified file management

2. **Workout Integration**
   - Start recording during workouts
   - Tag files with workout type
   - Show workout heart rate data

3. **Complications**
   - Show recording status on watch face
   - Quick access to app
   - File count display

4. **Watch-Specific Features**
   - Heart rate recording (if desired)
   - Gyroscope data addition
   - Custom recording durations

## Support

If you encounter issues:

1. Check Xcode console for detailed error messages
2. Verify all permissions are granted
3. Ensure watch and iPhone are running compatible OS versions
4. Try the 10-second test recording first

## File Structure Summary

```
SensorWatch Watch App/
├── SensorWatchApp.swift          # App entry point + background tasks
├── ContentView.swift              # Main UI + file management views
├── MotionRecorder.swift           # Sensor recording + CSV export
├── Info.plist                     # Permissions + capabilities
└── Assets.xcassets/               # App icons + assets
    ├── AppIcon.appiconset/
    ├── AccentColor.colorset/
    └── Contents.json
```

All files are ready to use - just add them to your Xcode project and build!

---

**Happy Sensor Recording! ⌚📊**
