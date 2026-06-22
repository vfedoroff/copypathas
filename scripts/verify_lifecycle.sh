#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CopyPathAs"
EXTENSION_ID="com.vfedoroff.CopyPathAs.FinderExtension"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

wait_for_process() {
  local process_name="$1"
  local stage="$2"
  for _ in {1..40}; do
    if /usr/bin/pgrep -x "$process_name" >/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out: $stage" >&2
  return 1
}

wait_for_process_exit() {
  local process_name="$1"
  local stage="$2"
  for _ in {1..40}; do
    if ! /usr/bin/pgrep -x "$process_name" >/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out: $stage" >&2
  return 1
}

extension_pids() {
  /usr/bin/pgrep -f '/CopyPathFinderExtension($| )'
}

wait_for_extension() {
  local stage="$1"
  for _ in {1..40}; do
    if extension_pids >/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out: $stage" >&2
  return 1
}

wait_for_pid_exit() {
  local pid="$1"
  local stage="$2"
  for _ in {1..40}; do
    if ! /bin/kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out: $stage" >&2
  return 1
}

wait_for_new_extension() {
  local previous_pids="$1"
  local stage="$2"
  local pid
  for _ in {1..40}; do
    while read -r pid; do
      if [[ -n "$pid" && "$previous_pids" != *" $pid "* ]]; then
        return 0
      fi
    done < <(extension_pids || true)
    sleep 0.25
  done
  echo "Timed out: $stage" >&2
  return 1
}

restore_finder() {
  /usr/bin/open -a Finder / >/dev/null 2>&1 || true
}

trap restore_finder EXIT

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

wait_for_process_exit "$APP_NAME" "host app remained running after its last window closed"

if ! /usr/bin/pluginkit -m -A -D -i "$EXTENSION_ID" | /usr/bin/grep -q "^+.*$EXTENSION_ID"; then
  echo "The CopyPathAs Finder extension is not registered and enabled." >&2
  exit 1
fi

/usr/bin/killall Finder 2>/dev/null || true
/usr/bin/open -a Finder /
wait_for_process Finder "Finder did not relaunch"
wait_for_extension "Finder extension did not load after Finder restarted"

if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
  echo "The host app relaunched while Finder loaded the extension." >&2
  exit 1
fi

extension_pids_before=" $(extension_pids | /usr/bin/tr '\n' ' ')"
for extension_pid in $extension_pids_before; do
  /bin/kill "$extension_pid"
done
for extension_pid in $extension_pids_before; do
  wait_for_pid_exit "$extension_pid" "Finder extension process did not terminate"
done
/usr/bin/open -a Finder /
wait_for_new_extension "$extension_pids_before" "Finder extension did not recover after process termination"

echo "Lifecycle verification passed: Finder and the extension recovered without the host app."
