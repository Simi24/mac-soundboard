#!/bin/zsh
# Build VoiceFX.app. It must be an app bundle, not a bare binary: macOS grants
# microphone access (TCC) per app, and a bare binary launched in the background
# gets digital silence instead of a permission prompt.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/VoiceFX.app"

swift build -c release --package-path "$DIR"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$DIR/.build/release/voicefx" "$APP/Contents/MacOS/voicefx"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.soundboard.voicefx</string>
  <key>CFBundleName</key><string>VoiceFX</string>
  <key>CFBundleExecutable</key><string>voicefx</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>VoiceFX applies effects to your voice and sends it to your call app through BlackHole.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for TCC. A rebuild changes the signature, so
# macOS may ask for microphone permission again.
codesign --force --sign - --identifier com.soundboard.voicefx "$APP"
echo "Built $APP"
