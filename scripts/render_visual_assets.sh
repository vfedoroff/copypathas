#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/docs/assets/source"
ASSET_DIR="$ROOT_DIR/docs/assets"
SOURCE_MOV="$SOURCE_DIR/copy-path-as-demo.mov"
SOURCE_PNG="$SOURCE_DIR/copy-path-as-menu.png"
GIF_OUTPUT="$ASSET_DIR/copy-path-as-demo.gif"
SCREENSHOT_OUTPUT="$ASSET_DIR/copy-path-as-menu.png"
PROMO_OUTPUT="$ASSET_DIR/copy-path-as-promo.png"

fail() {
  echo "error: $*" >&2
  exit 1
}

FFMPEG="$(command -v ffmpeg || true)"
[[ -n "$FFMPEG" ]] || fail "FFmpeg is required"
[[ -f "$SOURCE_MOV" ]] || fail "missing source recording: $SOURCE_MOV"
[[ -f "$SOURCE_PNG" ]] || fail "missing source screenshot: $SOURCE_PNG"

FONT=""
for candidate in \
  /System/Library/Fonts/SFNS.ttf \
  /System/Library/Fonts/SFCompact.ttf \
  /System/Library/Fonts/Helvetica.ttc; do
  if [[ -f "$candidate" ]]; then
    FONT="$candidate"
    break
  fi
done
[[ -n "$FONT" ]] || fail "no suitable San Francisco system font found"

if "$FFMPEG" -hide_banner -filters 2>/dev/null | grep -q ' drawtext '; then
  TEXT_RENDERER="FFmpeg drawtext"
else
  [[ -x /usr/bin/swift ]] || fail "FFmpeg lacks drawtext and the AppKit fallback requires Swift"
  TEXT_RENDERER="AppKit fallback"
fi

if [[ "${1:-}" == "--check" ]]; then
  echo "FFmpeg: $FFMPEG"
  echo "Source recording: $SOURCE_MOV"
  echo "Source screenshot: $SOURCE_PNG"
  echo "Font: $FONT"
  echo "Text renderer: $TEXT_RENDERER"
  exit 0
fi

[[ $# -eq 0 ]] || fail "usage: $0 [--check]"

TMP_ROOT="${TMPDIR:-/tmp}/copypath-visuals"
mkdir -p "$TMP_ROOT" "$ASSET_DIR"
WORK_DIR="$(mktemp -d "$TMP_ROOT/render.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

cp "$SOURCE_PNG" "$WORK_DIR/copy-path-as-menu.png"

"$FFMPEG" -hide_banner -loglevel error -y \
  -i "$SOURCE_MOV" \
  -filter_complex "fps=15,scale='min(1100,iw)':-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 "$WORK_DIR/copy-path-as-demo.gif"

if [[ "$TEXT_RENDERER" == "FFmpeg drawtext" ]]; then
  "$FFMPEG" -hide_banner -loglevel error -y \
    -i "$SOURCE_PNG" \
    -filter_complex \
    "[0:v]scale='min(1320,iw*620/ih)':-2:flags=lanczos[shot];\
[shot]pad=iw+6:ih+6:3:3:color=0x5B7895[frame];\
color=c=0x081B33:s=1600x900[background];\
[background][frame]overlay=(W-w)/2:(H-h)/2+65[composite];\
[composite]drawtext=fontfile='$FONT':text='Copy any Finder path. Your way.':fontcolor=white:fontsize=58:x=(w-text_w)/2:y=72" \
    -frames:v 1 "$WORK_DIR/copy-path-as-promo.png"
else
  /usr/bin/swift -e '
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1400, height: 100)
let image = NSImage(size: size)
image.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 58, weight: .semibold),
  .foregroundColor: NSColor.white,
  .paragraphStyle: paragraph
]
NSString(string: "Copy any Finder path. Your way.").draw(
  in: NSRect(x: 0, y: 12, width: size.width, height: 76),
  withAttributes: attributes
)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
  fatalError("unable to render promotional headline")
}
try png.write(to: URL(fileURLWithPath: output))
' "$WORK_DIR/headline.png"

  "$FFMPEG" -hide_banner -loglevel error -y \
    -i "$SOURCE_PNG" -i "$WORK_DIR/headline.png" \
    -filter_complex \
    "[0:v]scale='min(1320,iw*620/ih)':-2:flags=lanczos[shot];\
[shot]pad=iw+6:ih+6:3:3:color=0x5B7895[frame];\
color=c=0x081B33:s=1600x900[background];\
[background][frame]overlay=(W-w)/2:(H-h)/2+65[composite];\
[1:v]scale=1400:100:flags=lanczos[headline];\
[composite][headline]overlay=(W-w)/2:58" \
    -frames:v 1 "$WORK_DIR/copy-path-as-promo.png"
fi

mv "$WORK_DIR/copy-path-as-demo.gif" "$GIF_OUTPUT"
mv "$WORK_DIR/copy-path-as-menu.png" "$SCREENSHOT_OUTPUT"
mv "$WORK_DIR/copy-path-as-promo.png" "$PROMO_OUTPUT"

echo "Rendered:"
echo "  $GIF_OUTPUT"
echo "  $SCREENSHOT_OUTPUT"
echo "  $PROMO_OUTPUT"
