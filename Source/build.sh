#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WORK=$(mktemp -d "${TMPDIR:-/tmp}/remotelid-build.XXXXXX")
trap 'rm -rf "$WORK"' 0
APP="$WORK/원격지킴이.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Source/Info.plist "$APP/Contents/Info.plist"
xcrun swiftc Source/make-icon.swift -o "$WORK/icon-builder" -module-cache-path "$WORK/swift-cache"
"$WORK/icon-builder" "$WORK/AppIcon.iconset"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
xcrun swiftc Source/main.swift -o "$APP/Contents/MacOS/RemoteLid" -target arm64-apple-macos13.0 -framework AppKit -framework IOKit -module-cache-path "$WORK/swift-cache" -O
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/RemoteLid" --self-test
mkdir -p build website/downloads
ditto "$APP" 'build/원격지킴이.app'
codesign --verify --deep --strict 'build/원격지킴이.app'
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Source/Info.plist)
ARCHIVE="remote-lid-$VERSION-arm64.zip"
ditto -c -k --keepParent --norsrc 'build/원격지킴이.app' "website/downloads/$ARCHIVE"
(cd website/downloads && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
printf '앱: build/원격지킴이.app\n다운로드: website/downloads/%s\n' "$ARCHIVE"
