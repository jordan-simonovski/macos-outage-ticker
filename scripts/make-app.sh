#!/bin/bash
# Builds NewsTicker.app — a universal (arm64 + x86_64), ad-hoc signed bundle.
#
#   scripts/make-app.sh [version]
#
# Version defaults to the current git tag, or 0.0.0-dev outside a tagged commit.
# Output: dist/NewsTicker.app
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --exact-match 2>/dev/null || echo 0.0.0-dev)}"
VERSION="${VERSION#v}"
APP="dist/NewsTicker.app"

swift build -c release --arch arm64 --arch x86_64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/apple/Products/Release/NewsTicker "$APP/Contents/MacOS/NewsTicker"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NewsTicker</string>
    <key>CFBundleIdentifier</key><string>com.github.jordan-simonovski.NewsTicker</string>
    <key>CFBundleName</key><string>NewsTicker</string>
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

echo "built $APP ($VERSION)"
lipo -archs "$APP/Contents/MacOS/NewsTicker"
