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
KEY_PATH="${NECLIP_NOTARY_KEY_PATH:-}"
KEY_ID="${NECLIP_NOTARY_KEY_ID:-}"
ISSUER="${NECLIP_NOTARY_ISSUER:-}"

for tool in git swift codesign diskutil xcrun spctl ditto shasum lipo; do
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

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "CFBundleShortVersionString must be semantic version x.y.z." >&2
  exit 1
}
[[ "$BUILD" =~ ^[1-9][0-9]*$ ]] || {
  echo "CFBundleVersion must be a positive integer." >&2
  exit 1
}
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || {
  echo "Release requires a clean tracked and untracked working tree." >&2
  exit 1
}
SOURCE_COMMIT=$(git rev-parse --verify HEAD)
EXPECTED_COMMIT="${NECLIP_RELEASE_COMMIT:-}"
[[ -n "$EXPECTED_COMMIT" ]] || {
  echo "Set NECLIP_RELEASE_COMMIT to the reviewed full commit SHA." >&2
  exit 1
}
[[ "$EXPECTED_COMMIT" == "$SOURCE_COMMIT" ]] || {
  echo "NECLIP_RELEASE_COMMIT does not match HEAD." >&2
  exit 1
}
if git rev-parse --verify --quiet "refs/tags/v${VERSION}" >/dev/null; then
  [[ "$(git rev-list -n 1 "v${VERSION}")" == "$SOURCE_COMMIT" ]] || {
    echo "Existing v${VERSION} tag does not point to the reviewed commit." >&2
    exit 1
  }
fi

# Verify notarization credentials before touching any existing dist artifact.
# A direct API key avoids storing another persistent secret in the Keychain.
# Individual API keys need only the key file and key ID; Team keys also set
# NECLIP_NOTARY_ISSUER.
NOTARY_ARGS=()
if [[ -n "$KEY_PATH" || -n "$KEY_ID" || -n "$ISSUER" ]]; then
  [[ -n "$KEY_PATH" && -n "$KEY_ID" ]] || {
    echo "Direct notarization requires NECLIP_NOTARY_KEY_PATH and NECLIP_NOTARY_KEY_ID." >&2
    exit 1
  }
  [[ -f "$KEY_PATH" ]] || {
    echo "Notarization key file is unavailable." >&2
    exit 1
  }
  NOTARY_ARGS=(--key "$KEY_PATH" --key-id "$KEY_ID")
  if [[ -n "$ISSUER" ]]; then
    NOTARY_ARGS+=(--issuer "$ISSUER")
  fi
  echo "== Checking direct notarization credentials =="
else
  NOTARY_ARGS=(--keychain-profile "$PROFILE")
  echo "== Checking notarization profile =="
fi
xcrun notarytool history "${NOTARY_ARGS[@]}" >/dev/null

WORK_DIR=$(mktemp -d /tmp/neclip-release.XXXXXX)
MOUNT_DIR=""
DIST_STAGE=""
cleanup() {
  if [[ -n "$MOUNT_DIR" ]]; then
    diskutil eject "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  if [[ -n "$DIST_STAGE" && -d "$DIST_STAGE" ]]; then
    rm -rf "$DIST_STAGE"
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
[[ "$(lipo -archs "$BIN_DIR/NeClip")" == "arm64" ]] || {
  echo "Release binary must contain exactly arm64." >&2
  exit 1
}

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NeClip" "$APP/Contents/MacOS/NeClip"
# Keep crash-symbolication data outside the shipped app. Strip only local and
# debug symbols; preserve global symbols, Swift metadata and runtime behavior.
xcrun dsymutil "$BIN_DIR/NeClip" -o "$WORK_DIR/NeClip.dSYM"
APP_UUID=$(xcrun dwarfdump --uuid "$APP/Contents/MacOS/NeClip" | awk '{print $2}')
DSYM_UUID=$(xcrun dwarfdump --uuid "$WORK_DIR/NeClip.dSYM" | awk '{print $2}')
[[ -n "$APP_UUID" && "$APP_UUID" == "$DSYM_UUID" ]] || {
  echo "Debug symbols do not match the release binary." >&2
  exit 1
}
xcrun strip -S -x "$APP/Contents/MacOS/NeClip"
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
xcrun notarytool submit "$ZIP" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

mkdir -p "$WORK_DIR/dmg"
cp -R "$APP" "$WORK_DIR/dmg/"
ln -s /Applications "$WORK_DIR/dmg/Applications"
diskutil image create from --format UDZO --volumeName "NeClip" "$WORK_DIR/dmg" "$DMG"

codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --strict --verbose=2 "$DMG"

echo "== Notarizing disk image =="
xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$DMG"

echo "== Verifying exact release artifacts =="
codesign --verify --strict --verbose=2 "$APP"
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

MOUNT_DIR=$(mktemp -d /tmp/neclip-dmg.XXXXXX)
diskutil image attach --readOnly --nobrowse --mountPoint "$MOUNT_DIR" "$DMG"
codesign --verify --strict --verbose=2 "$MOUNT_DIR/NeClip.app"
xcrun stapler validate "$MOUNT_DIR/NeClip.app"
spctl --assess --type execute --verbose=2 "$MOUNT_DIR/NeClip.app"
diskutil eject "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
MOUNT_DIR=""

(cd "$WORK_DIR" && shasum -a 256 "NeClip-${VERSION}.dmg" > "NeClip-${VERSION}.dmg.sha256")
DMG_SHA=$(awk '{print $1}' "$DMG.sha256")
printf '{"version":"%s","build":%s,"commit":"%s","architecture":"arm64","sha256":"%s"}\n' \
  "$VERSION" "$BUILD" "$SOURCE_COMMIT" "$DMG_SHA" > "$WORK_DIR/NeClip-${VERSION}.release.json"

# Publish one immutable local release directory, then atomically move the
# `current` pointer. Compatibility paths resolve through that single pointer,
# so an interrupted copy can never expose a mixed app/DMG/checksum set.
mkdir -p dist/releases
DIST_STAGE=$(mktemp -d "dist/releases/.stage-${VERSION}.XXXXXX")
DIST_RELEASE="dist/releases/${VERSION}-${BUILD}-${SOURCE_COMMIT}"
[[ ! -e "$DIST_RELEASE" ]] || {
  echo "Local release directory already exists: $DIST_RELEASE" >&2
  exit 1
}
cp -R "$APP" "$DIST_STAGE/NeClip.app"
cp -R "$WORK_DIR/NeClip.dSYM" "$DIST_STAGE/NeClip.dSYM"
cp "$DMG" "$DIST_STAGE/NeClip-${VERSION}.dmg"
cp "$DMG.sha256" "$DIST_STAGE/NeClip-${VERSION}.dmg.sha256"
cp "$WORK_DIR/NeClip-${VERSION}.release.json" "$DIST_STAGE/"
(cd "$DIST_STAGE" && shasum -a 256 -c "NeClip-${VERSION}.dmg.sha256")
mv "$DIST_STAGE" "$DIST_RELEASE"
DIST_STAGE=""
CURRENT_LINK="dist/releases/.current-${SOURCE_COMMIT}"
ln -s "$(basename "$DIST_RELEASE")" "$CURRENT_LINK"
mv -fh "$CURRENT_LINK" dist/releases/current
rm -rf dist/NeClip.app
ln -s "releases/current/NeClip.app" dist/NeClip.app
ln -sfn "releases/current/NeClip-${VERSION}.dmg" "dist/NeClip-${VERSION}.dmg"
ln -sfn "releases/current/NeClip-${VERSION}.dmg.sha256" "dist/NeClip-${VERSION}.dmg.sha256"
ln -sfn "releases/current/NeClip-${VERSION}.release.json" "dist/NeClip-${VERSION}.release.json"

echo "OK: NeClip ${VERSION} (${BUILD}) signed, notarized, stapled and verified"
