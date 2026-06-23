#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CopyPathAs"
BUNDLE_ID="com.vfedoroff.CopyPathAs"
EXTENSION_ID="$BUNDLE_ID.FinderExtension"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/CopyPathAs.app"
BUILT_EXTENSION="$BUILT_APP/Contents/PlugIns/CopyPathFinderExtension.appex"
INSTALL_DIR="${COPYPATH_INSTALL_DIR:-/Applications}"
APP_BUNDLE="$INSTALL_DIR/CopyPathAs.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/CopyPathAs"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x CopyPathFinderExtension >/dev/null 2>&1 || true
cd "$ROOT_DIR"
xcodegen generate
xcodebuild build \
  -project CopyPathAs.xcodeproj \
  -scheme CopyPathAs \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA"

# Finder extensions need a stable containing-app location to appear reliably
# in System Settings. Do not register the transient DerivedData copy.
mkdir -p "$INSTALL_DIR"

echo "🧹 Clearing duplicate registrations..."
set +o pipefail
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -dump 2>/dev/null | grep -i "path:" | grep -i "CopyPath" | sed -E 's/^path:[[:space:]]+//; s/[[:space:]]+\(0x[0-9a-fA-F]+\)//' | while read -r path; do
  if [ -n "$path" ] && [ "$path" != "$APP_BUNDLE" ] && [ "$path" != "$APP_BUNDLE/Contents/PlugIns/CopyPathFinderExtension.appex" ]; then
    /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$path" 2>/dev/null || true
  fi
done || true
set -o pipefail

/usr/bin/pluginkit -r "$BUILT_EXTENSION" >/dev/null 2>&1 || true
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"

# Register the stable path
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APP_BUNDLE"
/usr/bin/pluginkit -a "$APP_BUNDLE/Contents/PlugIns/CopyPathFinderExtension.appex"
/usr/bin/pluginkit -e use -i "$EXTENSION_ID"

# Clean up transient build registrations generated during this build
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$BUILT_APP" 2>/dev/null || true


open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR process == \"CopyPathFinderExtension\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\" OR subsystem == \"$BUNDLE_ID.FinderExtension\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
