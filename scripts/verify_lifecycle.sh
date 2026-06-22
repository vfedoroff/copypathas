#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CopyPathAs"
EXTENSION_ID="com.vfedoroff.CopyPathAs.FinderExtension"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

accessibility_enabled="$(
  /usr/bin/osascript -e 'tell application "System Events" to UI elements enabled' 2>/dev/null || true
)"

if [[ "$accessibility_enabled" != "true" ]]; then
  echo "System Events UI scripting is not authorized." >&2
  echo "Enable the terminal or development tool running this script in:" >&2
  echo "System Settings → Privacy & Security → Accessibility" >&2
  exit 1
fi

"$ROOT_DIR/scripts/build_and_run.sh" --verify

if ! /usr/bin/osascript <<'APPLESCRIPT'
tell application "System Events"
    tell process "CopyPathAs"
        repeat 20 times
            if exists window 1 then exit repeat
            delay 0.25
        end repeat

        if not (exists window 1) then error "CopyPathAs settings window did not appear"
        click (first button of window 1 whose subrole is "AXCloseButton")
    end tell
end tell
APPLESCRIPT
then
  echo "Unable to close CopyPathAs through System Events." >&2
  echo "Allow Automation access if macOS prompted, then run this script again." >&2
  exit 1
fi

for _ in {1..20}; do
  if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
    break
  fi
  sleep 0.25
done

if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
  echo "CopyPathAs remained running after its last settings window closed." >&2
  exit 1
fi

if ! /usr/bin/pluginkit -m -A -D -i "$EXTENSION_ID" | /usr/bin/grep -q "^+.*$EXTENSION_ID"; then
  echo "The CopyPathAs Finder extension is not registered and enabled." >&2
  exit 1
fi

echo "Lifecycle verification passed: the host exited and the Finder extension remains enabled."
