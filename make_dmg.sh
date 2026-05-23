#!/bin/bash
set -e

# MacYT Downloader DMG Packager
# Packages the compiled .app bundle into a compressed, read-only .dmg installer

echo "=== Starting MacYT Downloader DMG Packaging ==="

# 1. Clean previous packaging files
echo "Cleaning packaging directories..."
rm -f "build/MacYT Downloader.dmg"
rm -f "build/temp.dmg"
rm -rf "build/dmg"

# 2. Verify .app bundle exists
if [ ! -d "build/MacYTDownloader.app" ]; then
    echo "ERROR: build/MacYTDownloader.app not found! Run ./build.sh first."
    exit 1
fi

# 3. Create structure for DMG contents
echo "Preparing folder layout for DMG..."
mkdir -p "build/dmg"
cp -R "build/MacYTDownloader.app" "build/dmg/"
ln -s /Applications "build/dmg/Applications"

# 4. Create raw read-write temporary DMG image
echo "Creating temporary raw disk image..."
hdiutil create \
  -volname "MacYT Downloader" \
  -srcfolder "build/dmg" \
  -ov \
  -format UDRW \
  "build/temp.dmg"

# 5. Convert temporary DMG to a highly compressed, read-only production DMG
echo "Converting to highly compressed production DMG..."
hdiutil convert \
  "build/temp.dmg" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "build/MacYT Downloader.dmg"

# 6. Clean up temporary files to conserve disk space immediately
echo "Cleaning up temporary files to reclaim storage..."
rm -f "build/temp.dmg"
rm -rf "build/dmg"

echo "=== DMG Packaging Complete! DMG installer is located at build/MacYT Downloader.dmg ==="
ls -lh "build/MacYT Downloader.dmg"
