# Quick Start Guide

Get started with the Apple Watch Sensor Recording App in 5 minutes.

---

## Prerequisites

- Apple Watch (Series 3 or later)
- iPhone (iOS 14+)
- Both devices paired and signed in with same Apple ID
- Xcode 14+ (for building from source)

---

## Installation

### 1. Build and Install

```bash
# Clone repository
git clone https://github.com/smithandrewk/iphone-sensor-app.git
cd iphone-sensor-app

# Open in Xcode
open iphone_sensor_app_no_claude.xcodeproj

# Select target and device
# - Select "iphone_sensor_app_no_claude" scheme → Your iPhone
# - Build and run (Cmd+R)
# - Select "Sensor Watch App" scheme → Your Apple Watch
# - Build and run (Cmd+R)
```

### 2. Grant Permissions

**On Apple Watch**:
1. When app launches, it will request Motion & Fitness permission
2. Tap "Allow"
3. Verify: Settings → Privacy → Motion & Fitness
   - "Fitness Tracking" should be ON
   - App should be listed and enabled

---

## First Time Setup

### 1. Start Recording (Watch)

1. **Launch Watch app**
2. **Check status**:
   - ✅ "Sensor Ready" (green) = Good to go
   - 🟢 "📱 Paired" = Connected to iPhone
3. **Recording starts automatically** - no button to press!
4. **Lock Watch screen** - recording continues in background

### 2. View Files (iPhone)

1. **Open iPhone app**
2. **You should see**:
   - Connection status at top
   - "Files: 0" initially (no data collected yet)
3. **Wait 10 minutes** for first file to be created

---

## Typical Usage

### Normal Operation (Set and Forget)

**No user action needed!** The system works automatically:

1. **Wear your Watch normally**
   - Screen can be off
   - App doesn't need to be open
   - Recording happens in background

2. **Files are created every 10 minutes**
   - Watch processes sensor data
   - Writes complete chunks to CSV
   - Automatically queues for transfer

3. **Files transfer to iPhone automatically**
   - Happens in background
   - iOS chooses optimal time (battery, connectivity)
   - Both apps can be closed

4. **Check iPhone app periodically**
   - See all collected files
   - Export what you need
   - Delete old files

### Exporting Data

**When you want to analyze your data**:

1. **Open iPhone app**
2. **Find the file** you want (sorted newest first)
3. **Tap "Share"** button
4. **Choose destination**:
   - AirDrop → Mac (easiest for analysis)
   - Files → iCloud Drive (cloud backup)
   - Mail → Email to yourself
   - Any app that accepts CSV

### Free Up Watch Storage

**When Watch is running low on space**:

1. **Open iPhone app**
2. **Verify files are synced** (not greyed out)
3. **Tap "Delete Synced"** button
4. **Watch removes** files that are safely on iPhone
5. **Watch storage freed up**

---

## Understanding the UI

### iPhone App

#### Status Indicators
- **🟢 "Watch Connected"**: Can do manual actions right now
- **🟠 "Watch Not Reachable"**: Automatic sync still works, manual actions unavailable
- **"X syncing"**: Files currently transferring

#### File States
- **Normal (white)**: File is on iPhone, ready to share
- **Greyed with "⌚ On Watch"**: File exists on Watch, will auto-transfer
- **Progress indicator**: Transfer in progress

#### Action Buttons
- **Download arrow**: Force immediate transfer (on greyed files)
- **"Share"**: Export file via share sheet
- **"Sync from Watch"**: Force sync all pending files
- **"Delete Synced"**: Free up Watch storage

### Watch App

#### Status Indicators
- **✅ "Sensor Ready"**: Accelerometer working correctly
- **🟢 "📱 Paired"**: Connected to iPhone
- **"X syncing"**: Files transferring to iPhone

#### File List
- **Read-only display**: Shows what's been recorded
- **No actions needed**: All management done on iPhone

---

## Verification Checklist

### After 10 Minutes

**Watch**:
- [ ] File count shows 1 or more
- [ ] Status shows "Sensor Ready"
- [ ] Shows "📱 Paired"

**iPhone**:
- [ ] File appears (may be greyed initially)
- [ ] After a few minutes, file becomes ungreyed
- [ ] Can tap "Share" to export

### After 1 Hour

**Watch**:
- [ ] File count shows ~6 files (one every 10 min)
- [ ] May show "X syncing" periodically

**iPhone**:
- [ ] Multiple files visible
- [ ] Most or all are ungreyed (synced)
- [ ] File sizes are ~1.8 MB each

---

## Common First-Time Issues

### "Sensor Unavailable" on Watch

**Fix**:
1. Open Watch Settings app
2. Privacy → Motion & Fitness
3. Enable "Fitness Tracking"
4. Find your app, enable it
5. Restart Watch app

### No Files Appearing

**Check**:
- Wait at least 10 minutes (first file needs time)
- Watch app was launched at least once
- Motion & Fitness permission granted
- Both devices on same Apple ID

### Files Stay Greyed on iPhone

**What's happening**:
- Files are queued, transfer in progress
- iOS chooses optimal time to transfer
- Can take a few minutes depending on conditions

**Speed it up**:
- Put Watch on charger (iOS prioritizes charging time)
- Keep Watch and iPhone close together
- Or tap download arrow for immediate transfer

### Download Button Doesn't Work

**Requirements**:
- iPhone must show "Watch Connected" (🟢)
- Watch app recently used or currently open
- Devices in Bluetooth range

**Alternative**:
- Just wait - automatic transfer will happen in background
- Check back in a few minutes

---

## Best Practices

### For Continuous Recording

1. **Charge Watch overnight**
   - Recording continues while charging
   - Files transfer during charge (optimal time)

2. **Don't worry about the app**
   - No need to keep Watch app open
   - Screen can be off
   - Works in background

3. **Check iPhone daily**
   - Verify files are syncing
   - Export what you need
   - Free up Watch storage if needed

### For Data Collection Studies

1. **Start recording session**:
   - Launch Watch app once
   - Verify "Sensor Ready"
   - Let it run

2. **During session**:
   - Wear Watch normally
   - Don't need to interact with app
   - Files auto-transfer

3. **End of session**:
   - Open iPhone app
   - Tap "Sync from Watch" if you want files immediately
   - Export all files via "Share All"
   - Archive or analyze data

### For Battery Life

1. **Let iOS manage transfers**
   - Don't force manual sync constantly
   - Automatic sync is battery-optimized

2. **Delete synced files from Watch**
   - Frees storage without losing data
   - Do this weekly or when storage low

3. **Export and delete from iPhone**
   - After exporting to Mac/cloud
   - Free up iPhone storage
   - Data is safe in your analysis environment

---

## Data Analysis

### Opening CSV Files

**On Mac**:
```bash
# View in terminal
cat sensor_data_2025-11-17_16-00-21.csv | head

# Open in Excel/Numbers
open sensor_data_2025-11-17_16-00-21.csv

# Python analysis
import pandas as pd
df = pd.read_csv('sensor_data_2025-11-17_16-00-21.csv')
print(df.head())
```

**File Structure**:
```csv
timestamp,x,y,z
1700236821.523,0.012,-0.987,0.156
1700236821.543,0.015,-0.985,0.158
...
```

- `timestamp`: Unix time (seconds since 1970)
- `x`, `y`, `z`: Acceleration in g-forces
- ~50 Hz sampling rate
- ~30,000 rows per 10-minute file

---

## Troubleshooting

### Problem: Recording Stops

**Check**:
1. Watch hasn't been restarted (clears background tasks)
2. App hasn't been force-quit
3. Storage isn't full

**Fix**:
- Launch Watch app again
- Check "Sensor Ready" status
- Recording resumes automatically

### Problem: Files Not Transferring

**Symptoms**:
- Files stay greyed on iPhone for hours
- File count increases on Watch but not iPhone

**Check**:
1. Both devices on same Apple ID
2. Bluetooth enabled on both devices
3. Devices are paired (Watch app on iPhone shows paired)

**Fix**:
- Bring devices close together
- Open both apps
- Tap "Sync from Watch" on iPhone

### Problem: High Battery Drain

**Normal battery usage**:
- Watch: ~5-10% more per day than without recording
- iPhone: Negligible impact

**If draining faster**:
1. Check Watch isn't constantly transferring (indicator would show)
2. Verify other apps aren't also using sensors
3. Consider reducing recording time or chunk size (requires code change)

---

## Next Steps

### Learn More
- Read [README.md](README.md) for complete feature documentation
- Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details

### Customize
- Adjust chunk duration (default: 10 minutes)
- Change recording frequency
- Modify file format
- See code comments in MotionRecorder.swift

### Get Help
- Check Issues on GitHub
- Review logs in Xcode Console
- Enable detailed logging (already in code)

---

## Quick Reference

### File Transfer Flow
```
Watch creates file (every 10 min)
    ↓
Auto-queues for transfer
    ↓
iOS transfers in background (may take minutes)
    ↓
Appears on iPhone (greyed → normal)
    ↓
Ready to export
```

### Manual Actions
| Action | iPhone Button | Requires |
|--------|--------------|----------|
| Download specific file | Download arrow | Watch reachable |
| Sync all files | "Sync from Watch" | Watch reachable |
| Delete from Watch | "Delete Synced" | Watch reachable |
| Export file | "Share" | Nothing |

### App States
| State | Files Created? | Files Transfer? |
|-------|---------------|-----------------|
| Watch: Foreground | ✅ Yes | ✅ Yes |
| Watch: Background | ✅ Yes | ✅ Yes |
| Watch: Closed | ❌ No | ✅ Yes* |
| iPhone: Any | N/A | ✅ Receives |

*Queued transfers continue, but no new files created

---

**You're all set!** The app is now recording and syncing automatically. Check back in an hour to see your collected data.
