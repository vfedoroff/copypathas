#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CopyPathAs"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/CopyPath.xcarchive"
EXPORT_DIR="$BUILD_DIR/signed-export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
SHA_PATH="$BUILD_DIR/SHA256SUMS.txt"

SIGNING_IDENTITY="${COPYPATH_SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${COPYPATH_NOTARY_PROFILE:-}"
RELEASE_TAG="${COPYPATH_RELEASE_TAG:-}"
PUBLISH=0

usage() {
  cat <<USAGE
usage: $0 [--publish] [--tag vX.Y.Z]

Build, Developer ID sign, notarize, staple, package, and optionally publish a
GitHub release from this Mac.

Required local setup:
  - Developer ID Application certificate in your keychain
  - Configs/Config.local.xcconfig with your DEVELOPMENT_TEAM
  - xcrun notarytool keychain profile named by COPYPATH_NOTARY_PROFILE
  - gh authenticated if --publish is used

Environment:
  COPYPATH_SIGNING_IDENTITY   Signing identity name. Default: Developer ID Application
  COPYPATH_NOTARY_PROFILE     notarytool keychain profile name. Required.
  COPYPATH_RELEASE_TAG        Release tag. Can also pass --tag.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --publish)
      PUBLISH=1
      shift
      ;;
    --tag)
      RELEASE_TAG="${2:-}"
      if [ -z "$RELEASE_TAG" ]; then
        echo "--tag requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$NOTARY_PROFILE" ]; then
  echo "COPYPATH_NOTARY_PROFILE is required." >&2
  echo "Create one with: xcrun notarytool store-credentials <profile-name>" >&2
  exit 2
fi

if [ ! -f "$ROOT_DIR/Configs/Config.local.xcconfig" ]; then
  echo "Configs/Config.local.xcconfig is required for maintainer signing." >&2
  echo "Copy Configs/Config.local.xcconfig.template and set DEVELOPMENT_TEAM." >&2
  exit 2
fi

if [ -z "$RELEASE_TAG" ]; then
  RELEASE_TAG="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
fi

if [ -z "$RELEASE_TAG" ]; then
  echo "No release tag found. Pass --tag vX.Y.Z or run from an exact tag checkout." >&2
  exit 2
fi

if ! git -C "$ROOT_DIR" diff --quiet; then
  echo "Working tree has unstaged changes. Commit or stash them before releasing." >&2
  exit 2
fi

if ! git -C "$ROOT_DIR" diff --cached --quiet; then
  echo "Index has staged changes. Commit or unstage them before releasing." >&2
  exit 2
fi

RELEASE_COMMIT="$(git -C "$ROOT_DIR" rev-parse --verify "$RELEASE_TAG^{commit}" 2>/dev/null || true)"
if [ -z "$RELEASE_COMMIT" ]; then
  echo "Release tag does not exist or is not a commit/tag object: $RELEASE_TAG" >&2
  exit 2
fi

HEAD_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
if [ "$RELEASE_COMMIT" != "$HEAD_COMMIT" ]; then
  echo "Release tag $RELEASE_TAG points to $RELEASE_COMMIT, but HEAD is $HEAD_COMMIT." >&2
  echo "Check out the exact release tag before building public artifacts." >&2
  exit 2
fi

if ! security find-identity -p codesigning -v | grep -F "$SIGNING_IDENTITY" >/dev/null; then
  echo "Signing identity not found in keychain: $SIGNING_IDENTITY" >&2
  security find-identity -p codesigning -v >&2 || true
  exit 2
fi

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

cd "$ROOT_DIR"
echo "Cleaning previous release artifacts..."
rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR"

echo "Generating Xcode project..."
xcodegen generate

echo "Archiving signed Release build..."
xcodebuild archive \
  -project CopyPathAs.xcodeproj \
  -scheme CopyPathAs \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  -configuration Release \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGN_STYLE=Manual

echo "Extracting app bundle..."
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH"

echo "Validating app signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvvv --entitlements :- "$APP_PATH" >/dev/null

echo "Creating notarization upload ZIP..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting app for notarization..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling app ticket..."
xcrun stapler staple "$APP_PATH"
spctl -a -vv --type execute "$APP_PATH"

echo "Creating final ZIP..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Creating final DMG..."
hdiutil create \
  -volname "Copy Path As" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "Signing and notarizing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
spctl -a -vv --type open --context context:primary-signature "$DMG_PATH"

echo "Writing checksums..."
shasum -a 256 "$ZIP_PATH" "$DMG_PATH" > "$SHA_PATH"

if [ "$PUBLISH" -eq 1 ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh is required for --publish." >&2
    exit 2
  fi

  echo "Publishing GitHub release $RELEASE_TAG..."
  if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
    gh release upload "$RELEASE_TAG" "$ZIP_PATH" "$DMG_PATH" "$SHA_PATH" --clobber
  else
    gh release create "$RELEASE_TAG" "$ZIP_PATH" "$DMG_PATH" "$SHA_PATH" \
      --title "$RELEASE_TAG" \
      --notes-file "$ROOT_DIR/RELEASE_NOTES.md"
  fi
fi

echo "Release artifacts ready:"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $SHA_PATH"
