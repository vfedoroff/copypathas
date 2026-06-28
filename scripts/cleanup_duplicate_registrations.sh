#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-}"
if [ -z "$APP_BUNDLE" ]; then
  echo "usage: $0 /path/to/CopyPathAs.app" >&2
  exit 2
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
EXTENSION_ID="${EXTENSION_ID:-com.vfedoroff.CopyPathAs.FinderExtension}"
EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/CopyPathFinderExtension.appex"

echo "Clearing duplicate CopyPathAs registrations..."

set +o pipefail
"$LSREGISTER" -dump 2>/dev/null |
  grep -i "path:" |
  grep -i "CopyPath" |
  sed -E 's/^path:[[:space:]]+//; s/[[:space:]]+\(0x[0-9a-fA-F]+\)//' |
  while IFS= read -r path; do
    if [ -n "$path" ] && [ "$path" != "$APP_BUNDLE" ] && [ "$path" != "$EXTENSION_BUNDLE" ]; then
      "$LSREGISTER" -u "$path" 2>/dev/null || true
    fi
  done || true
set -o pipefail

/usr/bin/pluginkit -r "$EXTENSION_BUNDLE" >/dev/null 2>&1 || true

for candidate in \
  "/Applications/CopyPathAs.app/Contents/PlugIns/CopyPathFinderExtension.appex" \
  "$HOME/Applications/CopyPathAs.app/Contents/PlugIns/CopyPathFinderExtension.appex" \
  "/Applications/CopyPath.app/Contents/PlugIns/CopyPathFinderExtension.appex" \
  "$HOME/Applications/CopyPath.app/Contents/PlugIns/CopyPathFinderExtension.appex"; do
  if [ "$candidate" != "$EXTENSION_BUNDLE" ]; then
    /usr/bin/pluginkit -r "$candidate" >/dev/null 2>&1 || true
  fi
done
