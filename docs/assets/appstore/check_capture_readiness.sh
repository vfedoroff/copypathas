#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APP_BUNDLE="${APP_BUNDLE:-/Applications/CopyPathAs.app}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.vfedoroff.CopyPathAs}"
EXTENSION_ID="${EXTENSION_ID:-com.vfedoroff.CopyPathAs.FinderExtension}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

REQUIRE_EXTENSION=false
INSTALL_IF_NEEDED=false

usage() {
  cat <<'USAGE'
Check whether this Mac is ready to capture Copy Path As App Store source media.

Usage:
  check_capture_readiness.sh [--require-extension] [--install-if-needed]

Options:
  --require-extension
      Fail when the Finder extension is not registered and enabled. Use this
      before live Finder context-menu captures.

  --install-if-needed
      If the Finder extension is missing, run scripts/build_and_run.sh --verify
      and scripts/verify_lifecycle.sh to rebuild, install, register, and verify
      the local app. This modifies /Applications/CopyPathAs.app and Finder
      extension registration.

Notes:
  Production capture uses window/region sources, not full-screen screenshots.
  Figma and ParthJadhav/app-store-screenshots are optional design references,
  not required export dependencies for this macOS pipeline.
USAGE
}

failures=0
warnings=0

ok() {
  echo "OK: $*"
}

warn() {
  echo "WARN: $*" >&2
  warnings=$((warnings + 1))
}

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

require_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name found at $(command -v "$name")"
  else
    fail "$name is required"
  fi
}

default_value() {
  local domain="$1"
  local key="$2"
  defaults read "$domain" "$key" 2>/dev/null || true
}

check_default() {
  local domain="$1"
  local key="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(default_value "$domain" "$key")"
  if [[ "$actual" == "$expected" ]]; then
    ok "$label ($key=$actual)"
  else
    fail "$label expected $key=$expected, got '${actual:-unset}'"
  fi
}

extension_enabled() {
  /usr/bin/pluginkit -m -A -D -i "$EXTENSION_ID" 2>/dev/null | /usr/bin/grep -q "^+.*$EXTENSION_ID"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-extension)
      REQUIRE_EXTENSION=true
      ;;
    --install-if-needed)
      INSTALL_IF_NEEDED=true
      REQUIRE_EXTENSION=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

echo "== Capture environment =="
require_command xcodegen
require_command ffmpeg
require_command ffprobe

if /usr/bin/xcrun --find swift >/dev/null 2>&1; then
  ok "Swift found at $(/usr/bin/xcrun --find swift)"
else
  fail "Swift is required; checked DEVELOPER_DIR=$DEVELOPER_DIR"
fi

if DEVELOPER_DIR="$DEVELOPER_DIR" /usr/bin/xcodebuild -version >/dev/null 2>&1; then
  ok "Xcode available through DEVELOPER_DIR=$DEVELOPER_DIR"
else
  fail "Xcode is not available through DEVELOPER_DIR=$DEVELOPER_DIR"
fi

enrollment="$(profiles status -type enrollment 2>/dev/null || true)"
if grep -q "MDM enrollment: No" <<<"$enrollment"; then
  ok "MDM enrollment is off"
else
  warn "MDM enrollment is not confirmed off"
  [[ -n "$enrollment" ]] && echo "$enrollment" >&2
fi

accessibility_enabled="$(/usr/bin/osascript -e 'tell application "System Events" to UI elements enabled' 2>/dev/null || true)"
if [[ "$accessibility_enabled" == "true" ]]; then
  ok "Accessibility/UI scripting is enabled"
else
  fail "Accessibility/UI scripting is not enabled for this capture host"
fi

tmp_capture="${TMPDIR:-/tmp}/copypath-capture-readiness.png"
if /usr/sbin/screencapture -x -m -t png "$tmp_capture" >/dev/null 2>&1 && [[ -f "$tmp_capture" ]]; then
  ok "Screen capture works"
else
  fail "Screen Recording permission or display capture is not working"
fi

echo
echo "== Screenshot profile =="
check_default com.apple.finder AppleShowAllFiles 0 "Finder hidden files are off"
check_default com.apple.dock autohide 1 "Dock auto-hide is on"
check_default com.apple.WindowManager GloballyEnabled 0 "Stage Manager is off"

menu_bar_hidden="$(default_value NSGlobalDomain _HIHideMenuBar)"
if [[ "$menu_bar_hidden" == "1" ]]; then
  ok "Menu bar auto-hide preference is set"
else
  warn "Menu bar auto-hide preference is not set; window/region capture avoids this"
fi

if defaults read NSGlobalDomain AppleInterfaceStyle >/dev/null 2>&1; then
  fail "Dark Mode is active; use Light appearance for production captures"
else
  ok "Light appearance is active"
fi

echo
echo "== App health =="
if [[ -d "$APP_BUNDLE" ]]; then
  ok "Installed app exists at $APP_BUNDLE"
  installed_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$installed_bundle_id" == "$APP_BUNDLE_ID" ]]; then
    ok "Installed app bundle id is $installed_bundle_id"
  else
    fail "Installed app bundle id expected $APP_BUNDLE_ID, got '${installed_bundle_id:-unknown}'"
  fi

  signature="$("/usr/bin/codesign" -dv --verbose=2 "$APP_BUNDLE" 2>&1 || true)"
  if grep -q "Signature=adhoc" <<<"$signature"; then
    warn "Installed app is ad-hoc signed; acceptable for local capture, not release representation"
  elif grep -q "Signature=" <<<"$signature"; then
    ok "Installed app has a non-ad-hoc signature"
  else
    fail "Unable to inspect installed app signature"
  fi
else
  fail "Installed app is missing at $APP_BUNDLE"
fi

if extension_enabled; then
  ok "Finder extension is registered and enabled"
else
  if $INSTALL_IF_NEEDED; then
    warn "Finder extension is missing; rebuilding and verifying local install"
    "$ROOT_DIR/scripts/build_and_run.sh" --verify
    "$ROOT_DIR/scripts/verify_lifecycle.sh"
    if extension_enabled; then
      ok "Finder extension is registered and enabled after reinstall"
    else
      fail "Finder extension is still not registered and enabled after reinstall"
    fi
  elif $REQUIRE_EXTENSION; then
    fail "Finder extension is not registered and enabled; run with --install-if-needed or enable it manually"
  else
    warn "Finder extension is not registered and enabled; live Finder menu captures will be blocked"
  fi
fi

echo
echo "== Result =="
if [[ "$failures" -gt 0 ]]; then
  echo "Capture readiness failed with $failures failure(s) and $warnings warning(s)." >&2
  exit 1
fi

echo "Capture readiness passed with $warnings warning(s)."
