# BLACKBOX Studio for macOS

A native macOS local-first music player (`BlackBoxStudio.app`) built with **SwiftUI, AppKit, and WebKit (`WKWebView`)**, forked from [sherlockfrfr/Black-Box-Studio](https://www.google.com/search?q=https://github.com/sherlockfrfr/Black-Box-Studio) and ported to macOS in [atlaswuzhere/Black-Box-Studio-Mac](https://github.com/atlaswuzhere/Black-Box-Studio-Mac).

## What Is Included

* **Native macOS Application (`BlackBoxStudioApp.swift`)**:
  * **Native Folder Picker & Persistent Access**: Bridges `window.showDirectoryPicker()` to macOS `NSOpenPanel` and stores **Security-Scoped Bookmarks** in `UserDefaults`, automatically remounting your music library on every app launch.
  * **Embedded Loopback Audio Server**: High-speed POSIX HTTP server bound strictly to `127.0.0.1` (`8765–8795`) with `206 Partial Content` byte-range streaming for instant audio scrubbing, zero CORS restrictions, and full Web Audio API compatibility.
  * **Floating Mini Player (`NSPanel`)**: Always-on-top translucent macOS utility panel hosting [mini.html](https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/mini.html) and [mini.js](https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/mini.js), synced live via `BroadcastChannel`.
  * **macOS Hardware Media Keys & Control Center**: Native integration with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` for Play/Pause, Next, Previous, AirPods controls, and Now Playing artwork.
* **BLACKBOX Audio & Visual Engine ([index.html](https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/index.html), [style.css](https://www.google.com/search?q=https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/style.css), [app.js](https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/app.js), [config.json](https://www.google.com/search?q=https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/config.json))**:
  * Dual-deck gapless and crossfade audio engine (`AudioContext`).
  * 10-band parametric Equalizer (`32 Hz – 16 kHz`), preamp gain, and spatial stereo width control.
  * 6 real-time Canvas visualizers (`SPECTRUM`, `MIRROR`, `LED`, `TRAP RING`, `MONSTERCAT`, `OFF`) with beat/BPM detection.
  * ID3v2 metadata & cover art extraction, sidecar `.lrc`/`.txt` lyrics, and optional [LRCLIB](https://lrclib.net) synced lyrics lookup.
* **One-Command Xcode Project Generator (`setup_macos_xcode.sh`)**:
  * Generates `macOS-Xcode/BlackBoxStudio.xcodeproj`, `Info.plist`, `BlackBoxStudio.entitlements`, and `Assets.xcassets`, bundles the web UI, and opens the project in Xcode.

## Requirements

* **macOS 13.0 (Ventura)** or later (Apple Silicon or Intel).
* **Xcode 14.0** or later.

## Build & Run on macOS

1. Clone this repository:
   ```bash
   git clone https://github.com/atlaswuzhere/Black-Box-Studio-Mac.git
   cd Black-Box-Studio-Mac
   ```
2. Generate and open the Xcode project:
   ```bash
   chmod +x setup_macos_xcode.sh
   ./setup_macos_xcode.sh
   ```
3. In Xcode, press **`⌘R`** to build and launch **BLACKBOX Studio**, or build a standalone release bundle from Terminal:
   ```bash
   xcodebuild -project macOS-Xcode/BlackBoxStudio.xcodeproj -scheme BlackBoxStudio -configuration Release build
   ```
4. Inside the app, click **CONNECT MUSIC FOLDER** (or press **`⌘O`**) and select the folder containing your audio files (`.mp3`, `.flac`, `.m4a`, `.wav`, `.aac`, `.ogg`, `.opus`). Your folder selection is saved automatically across launches.

Because **BLACKBOX Studio** is an open-source release without an Apple Developer certificate, macOS Gatekeeper will block it on first launch with an alert stating:
> *"Apple cannot check it for malicious software"* or *"BlackBoxStudio cannot be opened because the developer cannot be verified."*

Choose any of the methods below to open the application:

### Method 1: Control-Click (Quickest)
1. Open `BlackBoxStudio.dmg` and drag **BlackBoxStudio** into your **Applications** folder.
2. Open your **Applications** folder in Finder.
3. **Right-click** (or hold **Control** and click) on `BlackBoxStudio.app` and select **Open**.
4. In the dialog box that appears, click **Open**.  
   *(macOS remembers this decision—subsequent launches will open normally).*

### Method 2: System Settings
1. Attempt to launch `BlackBoxStudio.app` once.
2. Open **System Settings** > **Privacy & Security**.
3. Scroll down to the **Security** header.
4. Locate the notification stating *"BlackBoxStudio was blocked from use..."* and click **Open Anyway**.
5. Enter your Mac login password or confirm with Touch ID.

### Method 3: Terminal Command
Clear the macOS quarantine attribute directly:
```bash
xattr -cr /Applications/BlackBoxStudio.app

## macOS Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘O` | Connect Music Folder (`NSOpenPanel`) |
| `⌘R` | Rescan Music Library |
| `Space` | Play / Pause |
| `⌘→` | Next Track |
| `⌘←` | Previous Track |
| `⇧⌘M` | Toggle Floating Mini Player Window |

## Privacy & Network Behaviour

BLACKBOX Studio is a local-first music player. Its embedded HTTP server binds exclusively to `127.0.0.1` (loopback) and is never exposed to your local network or the internet. Your music, playlists, lyrics, artwork, and personal app data stay on your Mac.

## Security & Contributing

* Read [CONTRIBUTING.md](https://www.google.com/search?q=https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/CONTRIBUTING.md) before opening a pull request.
* Read [SECURITY.md](https://www.google.com/search?q=https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/SECURITY.md) for vulnerability reporting guidelines. Never commit private music, personal playlists, backups, or signing certificates.

## License

BLACKBOX Studio is licensed under the **GNU General Public License v3.0 only (GPL-3.0-only)**. See [LICENSE](https://www.google.com/search?q=https://github.com/atlaswuzhere/Black-Box-Studio-Mac/blob/main/LICENSE) for full details.
