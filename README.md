# MacYT Downloader 🚀
> Premium, high-performance, and award-winning macOS (14+) YouTube video/audio downloader. Built entirely in Swift with **zero external package dependencies**.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue.svg?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Swift%206.2-orange.svg?style=flat-square" alt="Language">
  <img src="https://img.shields.io/badge/Framework-SwiftUI-red.svg?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=flat-square" alt="License">
</p>

---

## ✨ Features

- **Futuristic Fluid Aesthetic**: A gorgeous, macOS-native interface featuring hardware-accelerated animated backdrop blobs, dynamic linear glowing gradients, and ultra-thin frosted glass panels (`.ultraThinMaterial`).
- **Concurrent Fragment Downloader**: Download multiple streams concurrently. Configurable concurrent active download queue (up to 2 parallel downloads + sequential queueing + immediate parallel override).
- **Flexible Quality & Format Configurations**: 
  - **Video Formats**: MP4 (Standard/Default), MP4 Video Only (No Audio).
  - **Audio Formats**: MP3, FLAC, WAV, Opus, M4A.
  - **Quality Presets**: Best, Balanced, Storage Saver.
- **Robust Meta Profiling**: Instant drag-and-drop or paste processing that crawls and previews video details, thumbnails, exact duration, and file metadata before starting download.
- **Precision Metrics Tracking**: Displays stable overall download speed, absolute percentage complete, pulsing status indicators, and a high-precision stable overall ETA (Estimated Time of Arrival) calculation for the entire batch.
- **Persistent SQLite History**: A lightweight, C-bound persistent SQLite database that catalogs download history, searchable and sortable by date, complete with one-click Finder reveal links.
- **Completely Free Github Updater**: Features a custom-written Swift `UpdateManager` that checks the GitHub Releases API, fetches updates, downloads the DMG file, and auto-mounts it natively using standard `NSWorkspace` APIs—all completely serverless and free!

---

## 🛠️ Zero-Dependency Architecture

To keep the application light, robust, and lightning-fast:
- **No external Swift packages** (no Cocoapods, SPM, or Carthage).
- Standard APIs only: `Foundation`, `SwiftUI`, `SQLite3`, `Combine`, `UniformTypeIdentifiers`.
- Built directly using the Swift compiler (`swiftc`) to bypass heavy DerivedData build caches, producing a tiny **1.5 MB `.app`** and a **453 KB `.dmg` installer**!

---

## 🚀 Installation & Usage

1. Download the latest `.dmg` installer from the **Releases** tab.
2. Open the DMG and drag **MacYT Downloader** to your `Applications` folder.
3. Open the app and paste any YouTube link!

### Settings & Customization
- **Download Location**: Change where your files are saved using the native macOS `NSOpenPanel` inside the settings menu.
- **Auto-Update**: Hooked directly to GitHub Releases to check for updates with a single click.

---

## 💻 Developer Guide (Building from Source)

The project includes custom bash scripts to build the application and compile the DMG installer without needing Xcode UI.

### Prerequisites
Make sure `yt-dlp` and `ffmpeg` are installed via Homebrew:
```bash
brew install yt-dlp ffmpeg
```

### Build & Run
To compile the `.app` bundle:
```bash
./build.sh
```
The compiled app will be placed in `build/MacYTDownloader.app`.

### Package into DMG
To package the app into a compressed disk image:
```bash
./make_dmg.sh
```
This generates a highly optimized `build/MacYT Downloader.dmg` installer.

---

## 📝 License
This project is licensed under the MIT License - see the LICENSE file for details.
