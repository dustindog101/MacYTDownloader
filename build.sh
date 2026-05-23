#!/bin/bash
set -e

# MacYT Downloader Build Script
# Compiles Swift code directly to bypass heavy Xcode DerivedData cache directories (conserves disk space)

echo "=== Starting MacYT Downloader Compilation ==="

# 1. Clean previous build folders
echo "Cleaning old build files..."
rm -rf build
mkdir -p "build/MacYTDownloader.app/Contents/MacOS"
mkdir -p "build/MacYTDownloader.app/Contents/Resources"

# 2. Compile Swift files directly using swiftc
echo "Compiling Swift source files..."
swiftc \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macosx14.0 \
  -O \
  -lsqlite3 \
  -o "build/MacYTDownloader.app/Contents/MacOS/MacYT Downloader" \
  src/*.swift \
  src/Views/*.swift

echo "Swift source compiled successfully."

# 3. Copy Plist configurations
echo "Copying Info.plist..."
cp Info.plist "build/MacYTDownloader.app/Contents/Info.plist"

# 4. Copy bundled yt-dlp and ffmpeg executables
echo "Bundling dependencies (yt-dlp and ffmpeg)..."
FFMPEG_SOURCE=$(readlink -f /opt/homebrew/bin/ffmpeg)
YTDLP_SOURCE=$(readlink -f /opt/homebrew/bin/yt-dlp)

if [ -f "$FFMPEG_SOURCE" ]; then
    echo "Found ffmpeg binary: $FFMPEG_SOURCE"
    cp "$FFMPEG_SOURCE" "build/MacYTDownloader.app/Contents/Resources/ffmpeg"
    chmod +x "build/MacYTDownloader.app/Contents/Resources/ffmpeg"
else
    echo "WARNING: ffmpeg not found in path! Make sure it is installed via homebrew."
fi

if [ -f "$YTDLP_SOURCE" ]; then
    echo "Found yt-dlp binary: $YTDLP_SOURCE"
    cp "$YTDLP_SOURCE" "build/MacYTDownloader.app/Contents/Resources/yt-dlp"
    chmod +x "build/MacYTDownloader.app/Contents/Resources/yt-dlp"
else
    echo "WARNING: yt-dlp not found in path! Make sure it is installed via homebrew."
fi

# 5. Ad-hoc codesign the bundle (Critical for execution on arm64 Apple Silicon)
echo "Applying ad-hoc code signature..."
codesign --force --deep --sign - "build/MacYTDownloader.app"

echo "=== Build Complete! App bundle is located at build/MacYTDownloader.app ==="
ls -lh build/
