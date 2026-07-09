#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_DIR="${ASSET_DIR:-$SCRIPT_DIR}"

fail() {
  echo "error: $*" >&2
  exit 1
}

SIPS="${SIPS:-/usr/bin/sips}"
FFPROBE="${FFPROBE:-$(command -v ffprobe || true)}"
[[ -x "$SIPS" ]] || fail "sips is required"
[[ -n "$FFPROBE" ]] || fail "ffprobe is required"

RESOLUTIONS=("1280x800" "1440x900" "2560x1600" "2880x1800")
EXPECTED_COUNT=5

for resolution in "${RESOLUTIONS[@]}"; do
  width="${resolution%x*}"
  height="${resolution#*x}"
  dir="$ASSET_DIR/$resolution"
  [[ -d "$dir" ]] || fail "missing screenshot directory: $dir"

  for index in $(seq 1 "$EXPECTED_COUNT"); do
    image="$dir/$index.png"
    [[ -f "$image" ]] || fail "missing screenshot: $image"
    actual_width="$("$SIPS" -g pixelWidth "$image" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
    actual_height="$("$SIPS" -g pixelHeight "$image" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
    [[ "$actual_width" == "$width" && "$actual_height" == "$height" ]] \
      || fail "$image is ${actual_width}x${actual_height}, expected $resolution"
    echo "OK: $image ($resolution)"
  done
done

preview="$ASSET_DIR/preview/copy-path-as-app-preview.mp4"
if [[ -f "$preview" ]]; then
  preview_width="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$preview")"
  preview_height="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$preview")"
  codec="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$preview")"
  duration="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$preview")"

  [[ "$preview_width" == "1920" && "$preview_height" == "1080" ]] \
    || fail "$preview is ${preview_width}x${preview_height}, expected 1920x1080"
  [[ "$codec" == "h264" ]] || fail "$preview codec is $codec, expected h264"
  awk -v d="$duration" 'BEGIN { exit !(d >= 15 && d <= 30) }' \
    || fail "$preview duration is ${duration}s, expected 15-30s"
  echo "OK: $preview (${preview_width}x${preview_height}, h264, ${duration}s)"
else
  echo "warning: preview not found: $preview"
fi

gif_preview="$ASSET_DIR/preview/copy-path-as-app-preview.gif"
if [[ -f "$gif_preview" ]]; then
  gif_width="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$gif_preview")"
  gif_height="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$gif_preview")"
  gif_duration="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$gif_preview")"

  [[ "$gif_width" == "960" && "$gif_height" == "540" ]] \
    || fail "$gif_preview is ${gif_width}x${gif_height}, expected 960x540"
  awk -v d="$gif_duration" 'BEGIN { exit !(d >= 15 && d <= 30) }' \
    || fail "$gif_preview duration is ${gif_duration}s, expected 15-30s"
  echo "OK: $gif_preview (${gif_width}x${gif_height}, ${gif_duration}s)"
else
  echo "warning: preview GIF not found: $gif_preview"
fi

echo "Validation complete."
