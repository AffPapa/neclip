#!/bin/bash
# Build, sign, notarize, staple and verify the exact NeClip release artifacts.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT_DIR"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  for candidate in /Applications/Xcode.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer; do
    if [[ -d "$candidate" ]]; then
      export DEVELOPER_DIR="$candidate"
      break
    fi
  done
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Resources/Info.plist)
IDENTITY="${NECLIP_SIGN_IDENTITY:-474F7C78F33EE324C24F6F5AE0443EB713E85E60}"
PROFILE="${NECLIP_NOTARY_PROFILE:-neclip}"

for tool in swift codesign hdiutil xcrun spctl ditto shasum; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
[[ -n "${DEVELOPER_DIR:-}" && -d "$DEVELOPER_DIR" ]] || {
  echo "Full Xcode is required. Set DEVELOPER_DIR explicitly." >&2
  exit 1
}
security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null || {
  echo "Developer ID identity is unavailable: $IDENTITY" >&2
  exit 1
}

# Verify notarization credentials before touching any existing dist artifact.
echo "== Checking notarization profile =="
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null

WORK_DIR=$(mktemp -d /tmp/neclip-release.XXXXXX)
MOUNT_DIR=""
cleanup() {
  if [[ -n "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

APP="$WORK_DIR/NeClip.app"
DMG="$WORK_DIR/NeClip-${VERSION}.dmg"
ZIP="$WORK_DIR/NeClip-${VERSION}.zip"

echo "== Swift 6 tests and strict build =="
swift test --disable-sandbox
swift build --disable-sandbox -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
BIN_DIR=$(swift build --disable-sandbox -c release --show-bin-path)

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NeClip" "$APP/Contents/MacOS/NeClip"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"

echo "== Developer ID signing =="
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# Notarize and staple the app before it is placed into the disk image. This
# makes the exact app inside the DMG independently verifiable offline.
ditto -c -k --keepParent "$APP" "$ZIP"
echo "== Notarizing application =="
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

mkdir -p "$WORK_DIR/dmg"
cp -R "$APP" "$WORK_DIR/dmg/"
ln -s /Applications "$WORK_DIR/dmg/Applications"
hdiutil create -volname "NeClip" -srcfolder "$WORK_DIR/dmg" -ov -format UDZO "$DMG"

codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --strict --verbose=2 "$DMG"

echo "== Notarizing disk image =="
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "== Verifying exact release artifacts =="
codesign --verify --strict --verbose=2 "$APP"
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

MOUNT_DIR=$(mktemp -d /tmp/neclip-dmg.XXXXXX)
hdiutil attach "$DMG" -mountpoint "$MOUNT_DIR" -nobrowse -readonly
codesign --verify --strict --verbose=2 "$MOUNT_DIR/NeClip.app"
xcrun stapler validate "$MOUNT_DIR/NeClip.app"
spctl --assess --type execute --verbose=2 "$MOUNT_DIR/NeClip.app"
hdiutil detach "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
MOUNT_DIR=""

shasum -a 256 "$DMG" > "$DMG.sha256"

# Publish locally only after every gate passes. Existing known-good downloads
# remain untouched on any earlier error.
mkdir -p dist
rm -rf dist/NeClip.app
cp -R "$APP" dist/NeClip.app
cp "$DMG" "dist/NeClip-${VERSION}.dmg"
cp "$DMG.sha256" "dist/NeClip-${VERSION}.dmg.sha256"

echo "OK: NeClip ${VERSION} (${BUILD}) signed, notarized, stapled and verified"
