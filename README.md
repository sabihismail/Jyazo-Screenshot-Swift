# ScreenShot - macOS Screenshot & Upload Tool

A native Swift macOS application that captures screenshots and GIFs, uploads them to a server with OAuth2 authentication, and tracks the active window title for context.

## Features

✨ **Screenshot & GIF Capture**
- Capture custom screen regions with region selection overlay
- Record GIFs with adjustable frame rate
- Copy to clipboard automatically
- Save locally with optional auto-save to disk

🔐 **Secure OAuth2 Authentication**
- OAuth2 flow with automatic token management
- Tokens stored securely in macOS Keychain
- Automatic token refresh when expired

📍 **Active Window Tracking**
- Monitors active window title using Accessibility API
- Uses hybrid notification + polling approach for responsiveness
- Includes context with each upload

🎛️ **Customizable Hotkeys**
- Global hotkey for screenshot capture (default: Cmd+Shift+C)
- Global hotkey for GIF recording (default: Cmd+Shift+G)
- Configurable keyboard shortcuts in preferences

🔊 **Settings & Preferences**
- Server URL configuration
- Enable/disable local saving
- Sound notifications on upload
- GIF frame rate adjustment
- Hotkey customization

📋 **Logging**
- Comprehensive debug logging to file and console
- Timestamped logs in `~/Library/Application Support/ScreenShot/Logs/`
- View logs from app menu

## Installation

### Prerequisites
- macOS 12.0 or later
- Xcode 14+ (for building from source)

### Build from Source

```bash
cd /Users/zeen/Repos/ScreenShot
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme ScreenShot -configuration Release build
```

The built app will be at:
```
/Users/zeen/Library/Developer/Xcode/DerivedData/ScreenShot-*/Build/Products/Release/ScreenShot.app
```

## Setup

### 1. Configure Server URL

Open the app → Preferences → enter your server URL (e.g., `https://arkapri.me`)

### 2. Grant Permissions

The app will request these permissions on first launch:
- **Accessibility** - Required to track active window titles
- **Screen Recording** - Required for screenshot capture
- **System Audio Recording** - Required for GIF recording with audio

To manually reset permissions:
```bash
bash /Users/zeen/Repos/ScreenShot/clear_permissions.sh
```

### 3. Authenticate

1. Click "Capture Region" or use the hotkey
2. Browser opens with OAuth2 login
3. Authenticate and authorize the app
4. Token is automatically saved to Keychain

## Usage

### Capture Screenshot

**Via Hotkey:** `Cmd+Shift+C`

**Via Menu:** ScreenShot → Capture Region

1. Select the region you want to capture
2. Screenshot is captured and uploaded
3. Browser opens with uploaded image (copied to clipboard)

### Record GIF

**Via Hotkey:** `Cmd+Shift+G`

**Via Menu:** ScreenShot → Record GIF

1. Select the region to record
2. Recording starts automatically
3. Click to stop recording
4. GIF is uploaded to server

### View Logs

**Via Menu:** ScreenShot → Open Log File (opens latest log)

**Via Terminal:**
```bash
tail -f ~/Library/Application\ Support/ScreenShot/Logs/ScreenShot_*.log
```

## Development

### Quick Build & Run

```bash
cd /Users/zeen/Repos/ScreenShot
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -scheme ScreenShot -configuration Debug build && \
killall ScreenShot 2>/dev/null; sleep 1; \
open /Users/zeen/Library/Developer/Xcode/DerivedData/ScreenShot-*/Build/Products/Debug/ScreenShot.app
```

### Debug with Live Logs

**Option 1: Xcode Console (Recommended)**
```bash
open -a Xcode /Users/zeen/Repos/ScreenShot/ScreenShot.xcodeproj
```
Then press `⌘R` to run and see logs in console.

**Option 2: Terminal Log Stream**
```bash
log stream --predicate 'process == "ScreenShot"' --level debug
```

### Log Tags

Watch for these tags in logs for different events:
- `[APP]` - App lifecycle
- `[WINDOW]` - Window monitoring
- `[POLL]` - Window title polling
- `[NOTIFY]` - App switch notifications
- `[CAPTURE]` - Screenshot capture events
- `[UPLOAD]` - Upload flow
- `[OAUTH]` - OAuth authentication
- `[AUTH]` - Local auth server
- `[PERMISSIONS]` - Permission requests
- `[GIF]` - GIF recording

### Project Structure

```
ScreenShot/
├── ScreenShotApp.swift           # App entry point
├── WindowMonitor.swift           # Active window tracking
├── ScreenshotManager.swift       # Screenshot capture logic
├── GifRecorder.swift             # GIF recording
├── UploadManager.swift           # Server upload & OAuth2
├── LocalAuthServer.swift         # OAuth callback handler
├── AppConfig.swift               # Settings & Keychain storage
├── ContentView.swift             # UI
├── HotkeyManager.swift           # Global hotkey handling
├── Logger.swift                  # Logging system
└── PreferencesView.swift         # Settings UI
```

## Configuration

### Preferences (via UI)

- **Server URL** - Base URL of your upload server
- **Save All Images** - Auto-save screenshots to disk
- **Save Directory** - Where to save images locally
- **Enable Sound** - Play sound on successful upload
- **GIF Frame Rate** - Frames per second for GIF recording
- **Image Hotkey** - Customize screenshot hotkey
- **GIF Hotkey** - Customize GIF recording hotkey

### Server API Requirements

The server must implement:

**POST /api/ss/uploadScreenShot**

Request:
```
multipart/form-data
- title: string (active window title)
- uploaded_image: file (PNG image)
```

Response:
```json
{
  "success": true,
  "output": "https://example.com/image-url",
  "error": null
}
```

### OAuth2 Flow

1. App redirects to server's OAuth endpoint
2. User authenticates and grants permission
3. Server redirects to `http://localhost:52805/callback?token=<token>`
4. App extracts token and stores in Keychain
5. Token included in `Authorization: Bearer <token>` header for uploads

## Troubleshooting

### Permission Dialog Not Appearing

**Issue:** App says accessibility permission is denied but dialog won't appear

**Solution:**
```bash
bash /Users/zeen/Repos/ScreenShot/clear_permissions.sh
```

Then restart the app and grant permissions when prompted.

### Socket Failed to Start Listening

**Issue:** "Socket failed to start listening within 10.0s"

**Cause:** Port 52805 is already in use

**Solution:**
```bash
killall ScreenShot
```

### OAuth Authentication Hangs

**Issue:** OAuth dialog appears but times out

**Check:**
1. Server URL is correct and reachable
2. OAuth endpoint is working
3. Redirect URI is set to `http://localhost:52805/callback`

View detailed logs:
```bash
tail -f ~/Library/Application\ Support/ScreenShot/Logs/ScreenShot_*.log | grep OAUTH
```

### Window Title Shows "ScreenShot" Instead of Actual App

**Expected behavior:** When capturing, ScreenShot app comes to foreground but the upload should use the *previous* window's title

**If not working:** Make sure accessibility permissions are granted:
```bash
tccutil reset Accessibility arkaprime.ScreenShot
```

## Architecture

### Window Monitoring (Hybrid Approach)

- **NSWorkspace notifications** - Instant detection when user switches apps
- **2-second polling timer** - Catches window title changes within same app (e.g., switching browser tabs, IDE files)
- **Accessibility API** - Reads window title using AX framework
- **Fallback** - Uses app name if window title unavailable

This hybrid approach balances responsiveness with CPU efficiency.

### Upload Flow

1. Region captured via ScreenCaptureKit
2. Saved to temp file (or user's save directory)
3. Window title retrieved from WindowMonitor
4. File uploaded to server with OAuth token
5. Server returns URL
6. URL opened in browser and copied to clipboard

## License

Private project

## Support

For issues and development questions, refer to logs:
```bash
open ~/Library/Application\ Support/ScreenShot/Logs/
```

Check [CLAUDE.md](CLAUDE.md) for detailed development workflow and testing instructions.
