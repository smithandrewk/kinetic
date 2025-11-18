# Apple Watch Sensor Recording App

Continuous background sensor data recording on Apple Watch with automatic sync to iPhone.

## Features

- 📱 **Continuous Background Recording**: Records accelerometer data even when Watch screen is off
- ☁️ **Automatic Sync**: Files automatically transfer from Watch to iPhone via WatchConnectivity
- 📊 **CSV Export**: Export sensor data for analysis via AirDrop, iCloud, or any file sharing method
- 🔋 **Battery Optimized**: iOS handles opportunistic transfers during charging and good conditions
- 🎯 **Simple UI**: Minimal interface - set it and forget it

## Quick Start

1. Build and install both Watch and iPhone apps via Xcode
2. Grant Motion & Fitness permissions on Watch
3. Recording starts automatically - no button needed
4. Files appear on iPhone automatically
5. Export via Share button when ready

**[📖 Read the Quick Start Guide](docs/QUICKSTART.md)** for detailed setup instructions.

## Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[User Guide](docs/README.md)** - Complete feature documentation and user flows
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical implementation details

## System Requirements

- Apple Watch Series 3 or later (watchOS 7+)
- iPhone (iOS 14+)
- Both devices paired and on same Apple ID
- Xcode 14+ for building from source

## How It Works

### Automatic Operation

```
Watch (background) → Records data every 10 minutes → Auto-queues for transfer
                                    ↓
                            iOS WatchConnectivity
                                    ↓
iPhone (any state) ← Receives files automatically ← Ready to export
```

**No user intervention required!** The system handles everything automatically.

### File Format

CSV files with accelerometer data:
- **Filename**: `sensor_data_YYYY-MM-DD_HH-mm-ss.csv`
- **Columns**: `timestamp,x,y,z`
- **Sample Rate**: ~50 Hz
- **Chunk Size**: 10 minutes per file (~1.8 MB)

Example:
```csv
timestamp,x,y,z
1700236821.523,0.012,-0.987,0.156
1700236821.543,0.015,-0.985,0.158
```

## Usage

### Normal Operation

1. **Wear Watch**: Recording happens automatically in background
2. **Check iPhone periodically**: See collected files
3. **Export data**: Tap "Share" to export via AirDrop, Files, etc.
4. **Free up storage**: Tap "Delete Synced" to remove files from Watch

### Manual Controls

**iPhone App**:
- **Download arrow**: Force immediate transfer of specific file (requires Watch nearby)
- **"Sync from Watch"**: Force sync all pending files
- **"Delete Synced"**: Remove synced files from Watch
- **"Share"**: Export files

**Watch App**:
- **Read-only**: Just shows recording status and file count
- All actions performed on iPhone

## Architecture

```
┌─────────────────┐
│  Apple Watch    │
│  - Recording    │
│  - CSV Writing  │
│  - Auto-Queue   │
└────────┬────────┘
         │
    WatchConnectivity
         │
┌────────▼────────┐
│    iPhone       │
│  - File Manager │
│  - Export Tool  │
│  - Storage      │
└─────────────────┘
```

## Version History

### v2.0.0 (Current)
- ✅ Complete WatchConnectivity implementation
- ✅ Automatic background file sync
- ✅ Manual high-priority downloads
- ✅ Auto-delete confirmed files from Watch
- ✅ Persistent transfer tracking
- ✅ Metadata sync for instant file visibility

### v1.0.0
- Initial release
- Basic Watch sensor recording
- Manual file management

## Contributing

This is an educational repository. Feel free to fork and modify for your research or projects.

## License

MIT License - See LICENSE file for details

## Acknowledgments

Built using:
- Apple WatchConnectivity Framework
- Core Motion / CMSensorRecorder
- SwiftUI

---

**Need help?** Check the [Quick Start Guide](docs/QUICKSTART.md) or [User Guide](docs/README.md).
