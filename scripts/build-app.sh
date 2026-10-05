#!/bin/bash
# Builds D4Mac.app (release) into ./dist, signed ad hoc for local use.
set -euo pipefail
cd "$(dirname "$0")/.."

version="0.1.0"
app="dist/D4Mac.app"

swift build -c release --product D4MacApp
swift build -c release --product d4mac
bin="$(swift build -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
cp "$bin/D4MacApp" "$app/Contents/MacOS/D4Mac"
# Helpers/, not MacOS/: "d4mac" and "D4Mac" are the same name on a case-insensitive disk.
cp "$bin/d4mac" "$app/Contents/Helpers/d4mac"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>D4Mac</string>
    <key>CFBundleIdentifier</key><string>org.d4mac.D4Mac</string>
    <key>CFBundleName</key><string>D4Mac</string>
    <key>CFBundleDisplayName</key><string>D4Mac</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${version}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Allow microphone access for in-game voice chat.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$app"
echo "Built $app"
