# Aegis Download Manager

A modern, high-speed, zero-license desktop download manager built with Python and PyQt6. Featuring multi-connection acceleration, integrated video/stream extraction (YouTube, HLS, DASH), FFmpeg post-processing, clipboard sniffing, and a zero-setup browser extension.

---

## 🚀 Quick Setup (3 Simple Steps)

You only need to run setup and build the app once. After building, you get a standalone desktop executable and never have to touch Python or terminal commands again!

```
[Step 1: setup_windows.bat] ──> [Step 2: build_exe.bat] ──> [Step 3: Load Extension] ──> Done!
```

---

### Step 1: Run Prerequisites Setup
Double-click **`setup_windows.bat`** (or run it in Command Prompt):
```cmd
setup_windows.bat
```
* **What it does:** Scans your PC for Python 3.10+ (installs it if missing), prepares the `.venv` virtual environment, checks FFmpeg for video/audio merging, and installs required packages.

---

### Step 2: Build the Standalone Executable (.exe)
Double-click **`build_exe.bat`**:
```cmd
build_exe.bat
```
* **What it does:** Packages everything into a single, portable Windows application:
  - **Standalone Executable:** `dist\Aegis Download Manager.exe`
  - **Desktop Shortcut:** Automatically places a 1-click **Aegis Download Manager** icon on your Desktop.
  - **Extension Package:** Creates `dist\Aegis-Browser-Extension.zip`.

> [!TIP]
> From now on, you can simply launch Aegis directly from your Desktop shortcut or from `dist\Aegis Download Manager.exe`. You never need to run `python main.py` or open a terminal!

---

### Step 3: Add the Browser Extension (Drag & Drop)
Add the 1-click video download button to YouTube and media sites:

1. Open your browser and go to your extensions page:
   - **Chrome / Brave:** `chrome://extensions`
   - **Microsoft Edge:** `edge://extensions`
2. Turn on **Developer mode** (toggle in the top-right corner).
3. Click **Load unpacked** and choose the **`browser_extension`** folder inside this project.
4. Launch Aegis from your Desktop!

#### ✨ How Video Downloading Works:
- Open YouTube or any streaming site. A floating **"Download Video"** button appears directly on video players.
- Click it to select your preferred quality:
  - **4K / Maximum Quality** `[MAX]`
  - **1080p Full HD** `[1080p]`
  - **720p HD** `[720p]`
  - **Audio Only (MP3)** `[AUDIO]`
  - Direct sniffed video streams (`.mp4`, `.m3u8`, `.mpd`)
- Aegis immediately accepts the download—no manual link copying or browser restarts required!

---

## 🐧 Run on Linux

1. Install Python 3.10+ and system tools:
   ```bash
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

To package a standalone Linux release:
```bash
bash build_linux.sh
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
├── setup_windows.bat           # Step 1: Scans & installs dependencies (Python, FFmpeg, pip)
├── build_exe.bat               # Step 2: Builds standalone .exe + Desktop shortcut
├── build_linux.sh              # Linux packaging script
├── requirements.txt            # Python dependencies (PyQt6, yt-dlp, beautifulsoup4)
├── tools/                      # Bundled tools (aria2c, ffmpeg, qjs)
└── browser_extension/          # Step 3: Zero-setup Chrome/Edge extension (load unpacked)
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
