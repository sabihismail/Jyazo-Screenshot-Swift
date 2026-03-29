# ScreenShot Releases

This directory contains release builds of the ScreenShot application.

## Files

- **ScreenShot.app** — Standalone macOS application (520 KB)
  - Ready to run directly
  - Copy to `/Applications/` or run from any location
  - Signed with "Sign to Run Locally"

- **ScreenShot_v1.0.0.dmg** — Distributable disk image (173 KB)
  - Double-click to mount
  - Drag `ScreenShot.app` to Applications folder
  - Standard macOS installation method

## Installation

### Method 1: Direct App (Fastest)

```bash
cp -r ScreenShot.app /Applications/
open /Applications/ScreenShot.app
```

### Method 2: DMG (Standard macOS)

1. Double-click `ScreenShot_v1.0.0.dmg`
2. Drag `ScreenShot` app to Applications folder
3. Open from Applications folder or Launchpad

### Method 3: From Terminal

```bash
# Mount DMG
hdiutil attach ScreenShot_v1.0.0.dmg

# Copy app
cp -r "/Volumes/ScreenShot/ScreenShot.app" /Applications/

# Unmount
hdiutil unmount "/Volumes/ScreenShot"

# Run
open /Applications/ScreenShot.app
```

## First Run

1. Open the app
2. Grant required permissions:
   - Accessibility (for window tracking)
   - Screen Recording (for screenshots)
   - System Audio Recording (for GIF recording)
3. Go to Preferences and enter your server URL
4. Use `Cmd+Shift+C` to capture

## Troubleshooting

### "ScreenShot is damaged and can't be opened"

This happens if the signature is invalid. Rebuild from source:

```bash
cd /Users/zeen/Repos/ScreenShot
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme ScreenShot -configuration Release build
```

### Permission Denied

If you get permission errors, check file permissions:

```bash
chmod +x /Applications/ScreenShot.app/Contents/MacOS/ScreenShot
```

## Version Info

- **Version:** 1.0.0
- **Build Date:** 2026-03-29
- **Architecture:** ARM64 (Apple Silicon)
- **macOS Minimum:** 12.0

## Building Release Locally

If you need to rebuild:

```bash
cd /Users/zeen/Repos/ScreenShot
xcodebuild -scheme ScreenShot -configuration Release build
```

The built app will be in:
```
~/Library/Developer/Xcode/DerivedData/ScreenShot-*/Build/Products/Release/ScreenShot.app
```

See [README.md](../README.md) for full documentation.
