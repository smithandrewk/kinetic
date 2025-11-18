# AI Agent Context - Apple Watch Sensor Recording App

**Use this document to quickly onboard new AI agents when context needs to be cleared.**

---

## Quick Project Overview

This is an **educational repository** that implements a dual-app system for recording Apple Watch accelerometer data with automatic synchronization to iPhone for export and analysis.

**Current Version:** v2.0.0 (November 2025)

---

## Architecture at a Glance

```
Apple Watch App                    iPhone App
├─ Records sensor data         →   ├─ Receives files automatically
├─ Writes 10-min CSV chunks    →   ├─ File manager & export tool
├─ Auto-queues for transfer    →   ├─ No recording capability
└─ Auto-deletes after confirm  →   └─ Share via AirDrop/iCloud
```

**Key Principle:** Watch records everything, iPhone manages everything, WatchConnectivity syncs everything automatically.

---

## Critical Technical Decisions

### 1. **iPhone Does NOT Record Sensors**
- iPhone app has NO `CMMotionManager` or sensor recording
- `CSVFileManager.swift` is read-only (NOT a recorder)
- All sensor data comes from Watch only

### 2. **File Organization**
- **Watch:** Files in `Documents/` directory
- **iPhone:** Files in `Documents/watch_data/` subdirectory
- **Format:** `sensor_data_YYYY-MM-DD_HH-mm-ss.csv`

### 3. **Transfer Strategy (Simplified in v2.0.0)**
- **Automatic:** Files queue immediately on creation
- **No Smart Batching:** Removed in v2.0.0, iOS handles opportunistic delivery
- **High Priority:** Manual downloads bypass normal queue
- **Background:** Works even when both apps closed

### 4. **WatchConnectivity Usage**
| Method | Purpose | Behavior |
|--------|---------|----------|
| `transferFile()` | Actual CSV files | Persistent queue, opportunistic delivery |
| `updateApplicationContext()` | File metadata | Latest only, delivered when iPhone active |
| `sendMessage()` | Manual actions | Requires reachability, real-time |
| `transferUserInfo()` | Confirmations | Queued delivery |

### 5. **State Management**
- **Sync States:** `.pending` (metadata only) → `.transferring` (in progress) → `.synced` (on iPhone)
- **Persistent Storage:** `confirmedTransfers` and `pendingDeletions` saved in UserDefaults (survive app restarts)
- **UI Tracking:** `filesCurrentlyTransferring: Set<String>` prevents state reversion during refresh

---

## Common Pitfalls & Fixes

### ❌ Do NOT:
1. Use `Foundation.FileManager` without `Foundation.` prefix (conflicts with `CSVFileManager`)
2. Use `isPaired` property on watchOS (unavailable - use `activationState == .activated`)
3. Mutate Sets while iterating (use `intersection()` and `subtract()`)
4. Store `confirmedTransfers` only in memory (must persist to UserDefaults)
5. Name variables/classes that conflict with system frameworks

### ✅ Do:
1. Always parse `dataDate` from filename, not file creation date
2. Mark files as `.transferring` before calling `requestFile()`
3. Remove from `pendingFiles` when file received
4. Send transfer confirmation back to Watch for auto-delete
5. Post `RefreshFileList` notification after file operations

---

## File Structure

### iPhone App (`iphone_sensor_app_no_claude/`)
- `iphone_sensor_app_no_claudeApp.swift` - Simple app initialization
- `ContentView.swift` - Main UI with file list, sync controls
- `CSVFileManager.swift` - Read-only file utility (NOT a recorder!)
- `WatchConnectivityManager.swift` - Receives files, handles metadata

### Watch App (`Sensor Watch App/`)
- `SensorWatchApp.swift` - App lifecycle, background timer
- `ContentView.swift` - Minimal read-only UI
- `MotionRecorder.swift` - CMSensorRecorder + CSV writing
- `WatchConnectivityManager.swift` - Transfer queue, confirmations

### Documentation (`docs/`)
- `README.md` - Complete user guide
- `QUICKSTART.md` - 5-minute setup guide
- `ARCHITECTURE.md` - Technical implementation details
- `AI_AGENT_CONTEXT.md` - This file

---

## Version History (Important Changes)

### v2.0.0 (Current) - November 2025
- **Removed smart batching** - Simplified to immediate transfers, iOS handles delivery
- **High-priority downloads** - Manual download button forces immediate transfer
- **Persistent confirmed transfers** - Survives app restarts via UserDefaults
- **Fixed download button** - No longer requires second tap
- **UI improvements** - Show data collection time, not filename
- **Comprehensive docs** - Added full documentation suite

### v1.0.0 - Initial Release
- Basic Watch sensor recording
- Manual file management
- No automatic sync

---

## Git History Highlights

**Key Commits to Review:**
1. **v2.0.0 release** - Complete WatchConnectivity implementation
2. **v1.0.0 release** - Initial working sensor recording
3. **File metadata sorting** - Added dataDate parsing from filename
4. **Watch app creation** - Complete Watch implementation with CMSensorRecorder

**To quickly review history:**
```bash
git log --oneline --graph --decorate
git show v2.0.0  # See full v2.0.0 changes
```

---

## Quick Start for AI Agents

### When Asked to Add Features:
1. **Check if it's iPhone or Watch functionality**
   - Recording/sensors? → Watch only
   - File management/export? → iPhone only
   - Sync/transfer? → Both (WatchConnectivityManager)

2. **Read relevant docs first:**
   - User-facing changes? → Read `docs/README.md` for user flows
   - Technical changes? → Read `docs/ARCHITECTURE.md` for implementation
   - Quick context? → This file

3. **Understand sync states:**
   - Files can be `.pending` (metadata only), `.transferring`, or `.synced`
   - Always track state in `filesCurrentlyTransferring` Set
   - Always post `RefreshFileList` notification after changes

### When Asked to Debug:
1. **Check logs** - Extensive logging with emoji prefixes (📱 = iPhone, ⌚ = Watch)
2. **Verify WatchConnectivity state:**
   - iPhone: `isPaired`, `isWatchAppInstalled`, `isReachable`
   - Watch: `activationState == .activated`
3. **Check file paths:**
   - iPhone should use `watch_data/` subdirectory
   - Watch uses root `Documents/`
4. **Verify UserDefaults persistence** - `confirmedTransfers`, `pendingDeletions`

### When Asked to Document:
- This is a **teaching repository** - every line should be educational
- Include code comments explaining WHY, not just WHAT
- Update relevant docs in `docs/` folder
- Follow existing documentation style

---

## Important User Instructions

From `/Users/andrew/Desktop/iphone_sensor_app_no_claude/CLAUDE.md`:
> This is a teaching repository. Every line of code is meant to teach the user.

From `/Users/andrew/.claude/CLAUDE.md`:
> - Use gh issue to find issues
> - If we are working on an issue, the commit should always include "closes #<issue number>"

---

## Quick Reference Commands

**Check project state:**
```bash
# Current directory
pwd  # Should be /Users/andrew/Desktop/iphone_sensor_app_no_claude

# Check git status
git status
git log --oneline -10

# Find files
ls -la iphone_sensor_app_no_claude/
ls -la "Sensor Watch App/"
ls -la docs/

# Check iOS/watchOS compatibility
grep -r "isPaired" "Sensor Watch App/"  # Should NOT find any watchOS usage
```

**Test sync:**
1. Build both apps in Xcode
2. Check Watch: Should see "✅ Sensor Ready" and "🟢 📱 Paired"
3. Wait 10 minutes for first file
4. Check iPhone: File appears greyed with "⌚ On Watch"
5. Wait a few minutes: File becomes ungreyed with Share button

---

## Current State (as of v2.0.0)

✅ **Working:**
- Continuous background recording on Watch
- Automatic file transfer to iPhone
- Manual high-priority downloads
- Auto-delete after confirmation
- Persistent transfer tracking
- Complete documentation

❌ **Known Limitations:**
- No built-in data visualization
- No cloud backup integration
- No recording settings UI (must edit code)
- No batch export (one file at a time)

🔮 **Future Enhancements (see docs/ARCHITECTURE.md):**
- Data analysis/visualization
- Cloud backup (iCloud/Dropbox)
- Configurable chunk duration
- Activity detection/tagging
- Data compression before transfer

---

## Final Checklist for New Agents

Before making changes, verify you understand:
- [ ] Is this iPhone or Watch functionality?
- [ ] What is the current sync state model?
- [ ] Where are files stored on each device?
- [ ] How does WatchConnectivity work in this app?
- [ ] What needs to persist across app restarts?
- [ ] Is this user-facing or technical documentation?
- [ ] Have I read the relevant docs files?

**When in doubt:** Read `docs/ARCHITECTURE.md` for technical details or `docs/README.md` for user flows.

---

**Last Updated:** November 2025 (v2.0.0 release)
