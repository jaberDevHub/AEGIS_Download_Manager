# Aegis Download Manager

A modern, high-speed, zero-license desktop download manager built with Python and PyQt6. Featuring multi-connection acceleration, integrated video/stream extraction (YouTube, HLS, DASH), FFmpeg post-processing, clipboard sniffing, and a zero-setup browser extension.

---

## ⚡ Quick Start (Windows)

If you just downloaded or cloned this repository:

### Step 1: Run Setup
Double-click **`setup_windows.bat`** (or run it in Command Prompt / PowerShell):
```cmd
setup_windows.bat
```

**That's it!** The smart installer handles everything automatically:
- Scans for Python 3.10+ (downloads and installs it if missing).
- Configures the isolated virtual environment (`.venv`).
- Detects or downloads verified FFmpeg for high-resolution video/audio merging.
- Installs required packages and launches Aegis Download Manager immediately.

---

## 🌐 Browser Extension Setup (Zero-Friction)

Add the Aegis floating video download button to YouTube and streaming sites in seconds:

1. Open your browser and go to your extensions page:
   - **Chrome / Brave:** `chrome://extensions`
   - **Microsoft Edge:** `edge://extensions`
2. Turn on **Developer mode** (toggle switch in the top-right corner).
3. Click **Load unpacked** and select the **`browser_extension`** folder inside this project.
4. Launch Aegis Download Manager.

**How it works:**
- Whenever you open YouTube or any video webpage, a floating **"Download Video"** button appears directly on the video player.
- Click it to select your preferred quality:
  - **4K / Best Quality** `[MAX]`
  - **1080p Full HD**
  - **720p HD**
  - **Audio Only (MP3)**
  - Direct sniffed video streams (`.mp4`, `.m3u8`, `.mpd`)
- The download is instantly sent to Aegis with zero manual URL copying!

> [!NOTE]
> No batch files, host installers, or browser restarts are needed. The extension connects directly to Aegis through the secure local desktop bridge (`127.0.0.1`).

---

## 📦 Build Standalone Executable (.exe)

Want to package Aegis into a single, portable `.exe` that runs without Python installed?

Double-click **`build_exe.bat`**:
```cmd
build_exe.bat
```
- Automatically prepares PyInstaller and all dependencies.
- Generates the standalone executable in:
  `dist\Aegis Download Manager.exe`
- Generates the packaged browser extension in:
  `dist\Aegis-Browser-Extension.zip`

---

## 🐧 Run on Linux

1. Install Python 3.10+ and FFmpeg via your package manager:
   ```bash
   # Ubuntu / Debian / Mint:
   sudo apt update && sudo apt install -y python3 python3-pip python3-venv ffmpeg aria2
   ```

2. Clone and start Aegis:
   ```bash
   git clone https://github.com/jaberDevHub/AEGIS_Download_Manager.git
   cd AEGIS_Download_Manager
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   python3 main.py
   ```

---

## ✨ Key Features

- **Extreme Download Acceleration:** Multi-threaded segmented downloading (up to 32 parallel connections per file) powered by `aria2c`.
- **Media & Stream Extraction:** Native `yt-dlp` integration across 1,000+ video and audio platforms with one-click format and resolution selection.
- **FFmpeg Post-Processing:** Automatically merges separate adaptive video and audio streams into standard `.mp4`/`.mkv` files and extracts high-quality `.mp3` tracks.
- **Batch URL Import:** Paste multiple links or load text files (`.txt`) with instant validation and queueing.
- **Bandwidth Speed Limiter:** Set global or per-download speed caps (KB/s or unlimited) without dropping active connections.
- **Clipboard Monitoring:** Optional link sniffer that detects copied download links and prompts to download with a single click.
- **Scheduled Downloads:** Schedule downloads for off-peak hours with persistent timer queues that survive app restarts.
- **Headless CLI Mode:** Download from terminal or scripts without launching the GUI:
  ```bash
  python main.py --download "https://example.com/file.zip" --dest ./downloads
  ```
- **100% Offline & Private:** No user tracking, no telemetry, no expiration dates, and no licensing fees. All settings and history are stored locally in SQLite (`%APPDATA%\AegisDownloadManager`).

---

## 📁 Repository Structure

```
AegisDownloadManager/
├── main.py                     # Main application entry point (GUI & CLI)
├── ui.py                       # Modern PyQt6 dark user interface and dialogs
├── engine.py                   # Download workers (aria2, yt-dlp, direct HTTP)
├── database.py                 # SQLite database & settings manager
├── ipc_server.py               # Local HTTP bridge & IPC server for extensions
├── setup_windows.bat           # 1-Click setup: scans & installs dependencies, then launches
├── build_exe.bat               # 1-Click packager: builds standalone .exe distribution
├── build_linux.sh              # Linux packaging script
├── requirements.txt            # Python dependencies (PyQt6, yt-dlp, beautifulsoup4)
├── tools/                      # Bundled tools (aria2c, ffmpeg, qjs)
└── browser_extension/          # Chrome/Edge extension (drag-and-drop unpacked)
    ├── manifest.json           # Manifest V3 configuration
    ├── background.js           # Background service worker & HTTP bridge client
    ├── content.js              # Floating video sniffer & download menu
    ├── content.css             # Floating overlay styling
    ├── popup.html / popup.js   # Extension status popup
    └── INSTALL_WINDOWS.txt     # Quick extension installation guide
```

---

## 🧪 Testing

To run the automated test suite:
```bash
python -m unittest tests.test_security -v
python -m tests.test_new_features
python -m tests.test_file_management_automation
```

---

## 🔒 Security

For security audit details, verified fixes, and vulnerability reporting, see [SECURITY.md](SECURITY.md).
