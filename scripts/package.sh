#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CopyPathAs"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
EXPORT_DIR="$BUILD_DIR/export"

echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR"

cd "$ROOT_DIR"
echo "🛠️ Generating Xcode project..."
xcodegen generate

echo "📦 Archiving app (Release configuration)..."
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
xcodebuild archive \
  -project CopyPath.xcodeproj \
  -scheme CopyPath \
  -archivePath "$BUILD_DIR/CopyPath.xcarchive" \
  -destination 'generic/platform=macOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="-" # Ad-hoc sign for local packaging checks

echo "📂 Extracting App bundle..."
cp -R "$BUILD_DIR/CopyPath.xcarchive/Products/Applications/CopyPathAs.app" "$EXPORT_DIR/CopyPathAs.app"

echo "🤐 Creating ZIP archive..."
cd "$EXPORT_DIR"
zip -q -r "$BUILD_DIR/CopyPathAs.zip" "CopyPathAs.app"
cd "$ROOT_DIR"

echo "💿 Creating DMG disk image..."
hdiutil create \
  -volname "Copy Path As" \
  -srcfolder "$EXPORT_DIR/CopyPathAs.app" \
  -ov \
  -format UDZO \
  "$BUILD_DIR/CopyPathAs.dmg" > /dev/null

echo "✅ Packaging complete! Output located at:"
echo "   - build/CopyPathAs.zip"
echo "   - build/CopyPathAs.dmg"
