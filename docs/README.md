# Apple Watch Sensor Recording App

## Overview

A dual-app system for recording and managing Apple Watch sensor data (accelerometer) with automatic synchronization to iPhone for easy export and analysis.

### Key Features

- **Continuous Background Recording**: Records accelerometer data on Apple Watch even when screen is off
- **Automatic File Sync**: Files automatically transfer from Watch to iPhone via WatchConnectivity
- **Smart File Management**: View, download, share, and manage sensor data files
- **Minimal User Intervention**: Set it and forget it - everything works automatically
- **Battery Optimized**: iOS handles opportunistic transfers based on battery, connectivity, and proximity

---

## Architecture

### Apple Watch App
- **Purpose**: Record sensor data continuously in background
- **Data Collection**: Uses `CMSensorRecorder` to capture accelerometer data
- **File Format**: CSV files with 10-minute chunks
- **Sync**: Automatically queues files for transfer to iPhone
- **UI**: Minimal, read-only display of recording status and file list

### iPhone App
- **Purpose**: File manager and export tool for Watch data
- **Storage**: Receives files in `Documents/watch_data/` directory
- **Features**: View all files (local + remote), download on-demand, share via AirDrop/Files
- **Sync**: Receives files automatically in background

---

## User Flows

### 1. Normal Operation (Automatic Sync)

**No user action required - everything happens automatically!**

#### On Apple Watch:
1. **Background timer** (runs every 30 seconds, even when screen is off):
   - Processes sensor data from CMSensorRecorder buffer
   - Writes complete 10-minute chunks to CSV files
   - Detects new files
   - **Immediately queues for transfer** via `WCSession.transferFile()`
   - **Sends metadata** via `updateApplicationContext()`

2. **iOS WatchConnectivity System**:
   - Stores transfer in persistent queue
   - Delivers opportunistically based on:
     - Battery level (won't drain battery)
     - Network conditions (Bluetooth/WiFi proximity)
     - Device state (charging prioritized)
   - **Works completely in background** - apps don't need to be running
   - Retries automatically until successful

3. **File Transfer Complete**:
   - Watch receives confirmation from iPhone
   - Marks file as confirmed (tracked in UserDefaults)
   - Schedules auto-delete after 5-minute grace period

#### On iPhone:
1. **Receives file** (automatic, works when app is closed):
   - `WatchConnectivityManager` receives file
   - Saves to `Documents/watch_data/`
   - Sends confirmation back to Watch
   - Posts notification to refresh UI (if app is open)

2. **When user opens iPhone app**:
   - Loads latest metadata from Watch
   - **Shows all files immediately**:
     - **Synced files** (already on iPhone): Not greyed, with Share button
     - **Pending files** (only on Watch): Greyed with "⌚ On Watch" badge and download arrow

### 2. Manual Download (Force Immediate Transfer)

**When user wants a specific file RIGHT NOW:**

1. **User taps download arrow** on greyed file (pending)
2. **iPhone**:
   - Marks file as "transferring" (shows progress indicator)
   - Sends `transferFile` message to Watch (requires Watch to be reachable)
3. **Watch** (must be reachable - app recently active or open):
   - Receives HIGH PRIORITY request
   - Removes file from normal queue
   - **Starts transfer immediately** with high priority flag
   - Bypasses normal transfer queue
4. **Transfer completes**:
   - File appears on iPhone
   - Progress indicator disappears
   - Share button appears

**Limitation**: Requires Watch to be reachable (app recently used or open)

### 3. Manual Sync All

**When user wants to force sync of all pending files:**

1. **User taps "Sync from Watch"** button on iPhone
2. **Requires**: Watch must be reachable
3. **Watch**:
   - Gets list of all unconfirmed files
   - Queues all for transfer
   - Starts transfers immediately
4. **Result**: All pending files start transferring at once

### 4. Delete Synced Files from Watch

**Free up storage on Watch after files are safely on iPhone:**

1. **User taps "Delete Synced"** button on iPhone
2. **Requires**: Watch must be reachable
3. **iPhone sends list** of all files it has locally
4. **Watch**:
   - Compares local files with iPhone's list
   - Deletes any files that exist on iPhone
   - Updates metadata
   - Refreshes UI
5. **Result**: Watch storage freed up, files safe on iPhone

---

## File Format

### CSV File Structure

**Filename Format**: `sensor_data_YYYY-MM-DD_HH-mm-ss.csv`

Example: `sensor_data_2025-11-17_16-00-21.csv`
- Data collection started: November 17, 2025 at 4:00:21 PM

**CSV Contents**:
```csv
timestamp,x,y,z
1700236821.523,0.012,-0.987,0.156
1700236821.543,0.015,-0.985,0.158
...
```

- `timestamp`: Unix epoch time (seconds since Jan 1, 1970)
- `x`, `y`, `z`: Acceleration in g-forces

### File Timing

- **Chunk Duration**: 10 minutes per file (configurable in code)
- **Recording Frequency**: ~50 Hz (determined by CMSensorRecorder)
- **File Size**: ~1.8 MB per 10-minute file
- **Storage**: Watch can store ~12 hours in CMSensorRecorder buffer

---

## UI Guide

### iPhone App

#### Status Section (Blue Header)
- **"⌚ Apple Watch Sensor Data"**: Header
- **Connection Status**:
  - 🟢 "Watch Connected" - Can do manual actions
  - 🟠 "Watch Not Reachable" - Automatic sync still works
- **Sync Status**: Shows "X syncing" when files transferring

#### Action Buttons
- **"Sync from Watch"**: Force immediate sync of all pending files (requires Watch reachable)
- **"Delete Synced"**: Remove files from Watch that are already on iPhone (requires Watch reachable)

#### File List
Each file shows:
- **Date/Time**: Actual data collection time (parsed from filename)
  - Example: "Nov 17, 2024 at 4:00:21 PM"
- **File Size**: Human-readable format (e.g., "1.8 MB")
- **Status Badge**:
  - **"⌚ On Watch"**: File is on Watch, not yet transferred
  - **Progress Indicator**: Transfer in progress
  - **No badge**: File is on iPhone (synced)
- **Action Button**:
  - **Download Arrow**: For pending files - force immediate transfer
  - **"Share"**: For synced files - export via AirDrop/Files

#### Sorting
Files sorted by: Newest First (based on data collection time, not transfer time)

### Apple Watch App

#### Status Section (Blue Header)
- **Sensor Status**:
  - ✅ "Sensor Ready" - Accelerometer working
  - ❌ "Sensor Unavailable" - Check permissions
- **"Recording in Background"**: Confirms continuous recording
- **Connection Status**:
  - 🟢 "📱 Paired" - Connected to iPhone
  - 🔴 "Not Paired" - Check pairing
- **Sync Status**: Shows "X syncing" when files transferring

#### File List
- **Read-only**: Just shows what's been recorded
- **No actions**: All management done on iPhone
- Shows: Filename, file size, creation date

---

## Technical Details

### Background Recording on Watch

**CMSensorRecorder**:
- Provides 12-hour accelerometer data buffer
- Continues recording when app is backgrounded or screen is off
- Requires Motion & Fitness permissions

**Background Timer**:
- Runs every 30 seconds (even in background on watchOS)
- Processes data from CMSensorRecorder buffer
- Writes complete 10-minute chunks to CSV
- Automatically queues new files for transfer

**Data Processing**:
- Only writes **complete chunks** (full 10 minutes)
- Incomplete data stays in buffer for next processing cycle
- Ensures data continuity and completeness

### WatchConnectivity Transfer System

**Transfer Types**:

1. **File Transfer** (`transferFile()`):
   - For actual CSV files
   - Queued persistently (survives app termination)
   - Delivered opportunistically by iOS
   - FIFO (first in, first out) delivery
   - Works completely in background

2. **Metadata Sync** (`updateApplicationContext()`):
   - For file list metadata
   - Replaces previous context (only latest matters)
   - Delivered when iPhone app next becomes active
   - Allows iPhone to show pending files immediately

3. **Messages** (`sendMessage()`):
   - For manual actions (download, delete, sync)
   - Requires both apps to be reachable
   - Real-time bidirectional communication

**Confirmed Transfers**:
- Watch tracks confirmed files in `UserDefaults` (persists across restarts)
- Auto-delete scheduled 5 minutes after confirmation
- Prevents re-transferring files already on iPhone

### Storage Locations

**Watch**:
- Files: `Documents/` directory
- Confirmed transfers list: `UserDefaults`

**iPhone**:
- Synced files: `Documents/watch_data/`
- Pending files: Metadata only (from `applicationContext`)

---

## Permissions Required

### Apple Watch
- **Motion & Fitness**: Required for CMSensorRecorder
  - Settings → Privacy → Motion & Fitness → [App Name] → ON
  - Also enable "Fitness Tracking"

### iPhone
- **None**: No special permissions needed (WatchConnectivity works automatically)

---

## Troubleshooting

### Files Not Appearing on iPhone

**Check**:
1. Watch app is paired: Look for 🟢 "📱 Paired" on Watch
2. Both devices on same Apple ID
3. Open iPhone app - metadata loads on app open
4. Wait a few minutes - background transfers take time

**What's Happening**:
- Files queue automatically on Watch when created
- iOS delivers when conditions are optimal (battery, connectivity)
- Metadata appears first (greyed files), actual transfer follows

### Download Button Not Working

**Check**:
1. iPhone shows "Watch Connected" (🟢 green dot)
2. Watch app recently used or currently open
3. Watch and iPhone in Bluetooth range

**Why**:
- Manual download requires `sendMessage()` which needs both apps reachable
- If not reachable, file will still transfer automatically in background

### Files Not Deleting from Watch

**Check**:
1. Watch shows 🟢 "📱 Paired"
2. Watch app is open or recently used
3. Files exist on iPhone (check file list shows as synced, not greyed)

**How It Works**:
- Delete command only removes files that iPhone confirms it has
- Prevents data loss from deleting files not yet backed up

### Watch Not Recording

**Check**:
1. Motion & Fitness permissions enabled
2. Sensor status shows ✅ "Sensor Ready"
3. App has been launched at least once

**Background Recording**:
- Continues even when screen is off
- Doesn't require app to stay open
- Check file count increases every ~10 minutes

---

## Battery Impact

### Apple Watch
- **Recording**: Minimal impact (CMSensorRecorder is battery efficient)
- **File Transfer**: iOS manages opportunistically
  - Prioritizes when charging
  - Reduces frequency on low battery
  - Uses efficient Bluetooth/WiFi

### iPhone
- **Receiving Files**: Negligible (happens in background)
- **App Usage**: Normal app power consumption only when app is open

---

## Data Export Workflow

### Recommended Process

1. **Let data collect**: Watch records automatically for hours/days
2. **Open iPhone app periodically**: Check what's been collected
3. **Wait for auto-sync** OR **tap "Sync from Watch"** if in a hurry
4. **Export files**:
   - Tap "Share" on individual files
   - Or tap "Share All" for batch export
   - Use AirDrop to Mac/iPad
   - Or save to Files app for cloud storage
5. **Free up Watch storage**: Tap "Delete Synced" on iPhone

### Export Destinations

**Via Share Sheet**:
- **AirDrop**: Direct to Mac/iPad/iPhone
- **Files**: Save to iCloud Drive, OneDrive, Dropbox, etc.
- **Mail**: Email as attachment
- **Messages**: Send to contacts
- **Third-party apps**: Any app that accepts CSV files

---

## Version History

### v2.0.0 (Current)
- Complete WatchConnectivity implementation
- Automatic background file sync
- Manual download for immediate transfer
- Auto-delete confirmed files from Watch
- Metadata sync for instant file visibility
- Simplified automatic transfer (removed smart batching)
- High-priority transfers for manual downloads
- Persistent confirmed transfers tracking

### v1.0.0
- Initial release
- Basic Watch sensor recording
- Manual file management on Watch
- No automatic sync
