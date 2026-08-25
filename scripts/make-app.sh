#!/bin/bash
# Builds ONN.app — a universal (arm64 + x86_64), ad-hoc signed bundle — and a
# drag-to-install ONN.dmg beside it.
#
#   scripts/make-app.sh [version]
#
# Version defaults to the current git tag, or 0.0.0-dev outside a tagged commit.
# Output: dist/ONN.app, dist/ONN.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --exact-match 2>/dev/null || echo 0.0.0-dev)}"
VERSION="${VERSION#v}"
APP="dist/ONN.app"

swift build -c release --arch arm64 --arch x86_64
swift scripts/make-icon.swift dist/ONN.icns

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/NewsTicker "$APP/Contents/MacOS/ONN"
cp dist/ONN.icns "$APP/Contents/Resources/ONN.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>ONN</string>
    <key>CFBundleIdentifier</key><string>com.github.jordan-simonovski.ONN</string>
    <key>CFBundleName</key><string>ONN</string>
    <key>CFBundleDisplayName</key><string>ONN — Outage News Network</string>
    <key>CFBundleIconFile</key><string>ONN</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu-bar only: no Dock icon, no app switcher entry. Matches the
         setActivationPolicy(.accessory) call, and applies before launch. -->
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature. Gatekeeper still quarantines downloads (see README), but an
# unsigned binary will not launch at all on Apple silicon.
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

# --- drag-to-install disk image ---------------------------------------------
# ponytail: plain hdiutil image, no custom window background or icon positions.
# Styling a DMG needs Finder AppleScript against a logged-in GUI session, which
# does not work on a CI runner. Add create-dmg if the look ever matters more
# than the build being reproducible.
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f dist/ONN.dmg
hdiutil create -quiet -volname "ONN" -srcfolder "$STAGE" -ov -format UDZO dist/ONN.dmg
rm -rf "$STAGE"

echo "built $APP and dist/ONN.dmg ($VERSION)"
lipo -archs "$APP/Contents/MacOS/ONN"
