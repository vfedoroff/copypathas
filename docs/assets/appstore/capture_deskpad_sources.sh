#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/source/deskpad"
SAMPLE_DIR="${SAMPLE_DIR:-/private/tmp/CopyPathAs App Store/Sample Project}"

usage() {
  cat <<'USAGE'
Capture window/region source media for Mac App Store assets.

Production captures intentionally avoid full-screen screenshots. The active
desktop session can reveal the macOS menu bar even when auto-hide preferences
are set, so use selected windows or regions as source media.

Before live Finder context-menu captures:
  1. Run docs/assets/appstore/check_capture_readiness.sh --require-extension.
  2. If the Finder extension is missing, run:
     docs/assets/appstore/check_capture_readiness.sh --install-if-needed
  3. Stage only Finder and Copy Path As with neutral sample files.
  4. Use Computer Use only for fragile menu staging; keep exports script-based.

Commands:
  capture_deskpad_sources.sh --prepare
      Create the source folders and print the required capture list.

  capture_deskpad_sources.sh --screenshot <name>
      Interactively capture a window or selected region to
      source/deskpad/<name>.png.
      Names: 01-context-menu, 02-format-menu, 03-preview-tab,
             04-setup-overview, 05-selections

  capture_deskpad_sources.sh --capture-menu <name>
      Capture a staged menu region after a short delay. Use this only after
      positioning the Finder menu/submenu and excluding the menu bar and Dock.
      Names: 01-context-menu, 02-format-menu

  capture_deskpad_sources.sh --record-preview
      Record an interactive App Preview source movie to
      source/deskpad/app-preview-source.mov.

Optional design tools:
  Figma may be used for layout review, and ParthJadhav/app-store-screenshots
  may be used as design inspiration, but neither is required for this macOS
  16:10 screenshot pipeline.

Examples:
  docs/assets/appstore/capture_deskpad_sources.sh --prepare
  docs/assets/appstore/capture_deskpad_sources.sh --screenshot 01-context-menu
  docs/assets/appstore/capture_deskpad_sources.sh --capture-menu 02-format-menu
  docs/assets/appstore/capture_deskpad_sources.sh --record-preview
USAGE
}

prepare() {
  mkdir -p "$SOURCE_DIR"
  mkdir -p "$SAMPLE_DIR/Design Assets" "$SAMPLE_DIR/Sources"
  printf 'Sample project\nNeutral App Store demo files.\n' >"$SAMPLE_DIR/README.md"
  printf 'month,revenue\nJan,1200\nFeb,1450\nMar,1680\n' >"$SAMPLE_DIR/sales-data.csv"
  printf 'print("Hello, sample project!")\n' >"$SAMPLE_DIR/Sources/App.swift"
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" rx="12" fill="#2563eb"/></svg>\n' >"$SAMPLE_DIR/Design Assets/logo.svg"
  /usr/bin/python3 - "$SAMPLE_DIR/project-plan.pdf" <<'PY'
import sys
from pathlib import Path

Path(sys.argv[1]).write_bytes(b"""%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 69 >>
stream
BT /F1 24 Tf 72 720 Td (Sample Project Plan) Tj 0 -36 Td /F1 12 Tf (Neutral demo document.) Tj ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000241 00000 n 
0000000360 00000 n 
trailer
<< /Size 6 /Root 1 0 R >>
startxref
430
%%EOF
""")
PY
  cat <<EOF
Prepared: $SOURCE_DIR
Sample folder: $SAMPLE_DIR

Required screenshots:
  $SOURCE_DIR/01-context-menu.png
  $SOURCE_DIR/02-format-menu.png
  $SOURCE_DIR/03-preview-tab.png
  $SOURCE_DIR/04-setup-overview.png
  $SOURCE_DIR/05-selections.png

Required preview source:
  $SOURCE_DIR/app-preview-source.mov

Use window or region captures. Do not use full-screen captures as production
sources.
EOF
}

capture_screenshot() {
  local name="$1"
  case "$name" in
    01-context-menu|02-format-menu|03-preview-tab|04-setup-overview|05-selections) ;;
    *) echo "error: unsupported screenshot name: $name" >&2; exit 1 ;;
  esac

  mkdir -p "$SOURCE_DIR"
  local output="$SOURCE_DIR/$name.png"
  echo "Interactive capture starting. Select the staged window or region."
  echo "Output: $output"
  /usr/sbin/screencapture -i -t png "$output"
  [[ -f "$output" ]] || { echo "error: capture was cancelled" >&2; exit 1; }
  echo "Captured: $output"
}

capture_menu() {
  local name="$1"
  case "$name" in
    01-context-menu|02-format-menu) ;;
    *) echo "error: unsupported menu screenshot name: $name" >&2; exit 1 ;;
  esac

  prepare >/dev/null
  open "$SAMPLE_DIR"

  mkdir -p "$SOURCE_DIR"
  local output="$SOURCE_DIR/$name.png"
  local delay="${CAPTURE_DELAY:-6}"
  echo "Timed menu capture starts now. Capture delay: ${delay}s"
  echo "Stage the Finder menu/submenu inside the desired region; avoid full-screen sources."
  echo "Output: $output"
  /usr/sbin/screencapture -T "$delay" -x -t png "$output"
  [[ -f "$output" ]] || { echo "error: capture failed" >&2; exit 1; }
  echo "Captured: $output"
}

record_preview() {
  mkdir -p "$SOURCE_DIR"
  local output="$SOURCE_DIR/app-preview-source.mov"
  echo "Interactive screen recording starting. Select the staged DeskPad preview region."
  echo "Keep the recording between 15 and 30 seconds."
  echo "Output: $output"
  /usr/sbin/screencapture -i -v -t mov "$output"
  [[ -f "$output" ]] || { echo "error: recording was cancelled" >&2; exit 1; }
  echo "Recorded: $output"
}

case "${1:-}" in
  --prepare)
    prepare
    ;;
  --screenshot)
    [[ -n "${2:-}" ]] || { echo "error: missing screenshot name" >&2; usage; exit 1; }
    capture_screenshot "$2"
    ;;
  --capture-menu)
    [[ -n "${2:-}" ]] || { echo "error: missing menu screenshot name" >&2; usage; exit 1; }
    capture_menu "$2"
    ;;
  --record-preview)
    record_preview
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "error: unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
