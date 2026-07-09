#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${SOURCE:-$SCRIPT_DIR/source/deskpad/app-preview-source.mov}"
OUTPUT_DIR="$SCRIPT_DIR/preview"
OUTPUT_BASENAME="${OUTPUT_BASENAME:-copy-path-as-app-preview}"
if [[ "${TIMESTAMPED_OUTPUT:-false}" == "true" ]]; then
  OUTPUT_BASENAME="${OUTPUT_BASENAME}-$(date +%Y%m%d-%H%M%S)"
fi
OUTPUT="$OUTPUT_DIR/${OUTPUT_BASENAME}.mp4"
GIF_OUTPUT="$OUTPUT_DIR/${OUTPUT_BASENAME}.gif"

fail() {
  echo "error: $*" >&2
  exit 1
}

FFMPEG="${FFMPEG:-$(command -v ffmpeg || true)}"
FFPROBE="${FFPROBE:-$(command -v ffprobe || true)}"
[[ -n "$FFMPEG" ]] || fail "FFmpeg is required"
[[ -n "$FFPROBE" ]] || fail "ffprobe is required"

if [[ "${1:-}" == "--check" ]]; then
  [[ -f "$SOURCE" ]] || fail "missing preview source: $SOURCE"
  echo "FFmpeg: $FFMPEG"
  echo "ffprobe: $FFPROBE"
  echo "Source: $SOURCE"
  echo "MP4 output: $OUTPUT"
  echo "GIF output: $GIF_OUTPUT"
  "$FFPROBE" -v error -show_entries format=duration -of default=noprint_wrappers=1 "$SOURCE"
  exit 0
fi

[[ -f "$SOURCE" ]] || fail "missing preview source: $SOURCE"
mkdir -p "$OUTPUT_DIR"

duration="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$SOURCE")"
target_duration="$duration"
loop_args=()
if awk -v d="$duration" 'BEGIN { exit !(d < 15) }'; then
  target_duration="16.2"
  loop_args=(-stream_loop -1 -t "$target_duration")
elif awk -v d="$duration" 'BEGIN { exit !(d > 30) }'; then
  target_duration="30"
  loop_args=(-t "$target_duration")
fi

"$FFMPEG" -hide_banner -loglevel error -y \
  "${loop_args[@]+"${loop_args[@]}"}" -i "$SOURCE" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
  -filter_complex "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0xF7F8FA,fps=30,fade=t=in:st=0:d=0.25,fade=t=out:st=$(awk -v d="$target_duration" 'BEGIN { printf "%.2f", d - 0.35 }'):d=0.35,format=yuv420p[v]" \
  -map "[v]" -map 1:a \
  -t "$target_duration" \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -b:v 12M -maxrate 12M -bufsize 24M \
  -c:a aac -b:a 256k -ar 48000 -ac 2 \
  -movflags +faststart \
  "$OUTPUT"

"$FFMPEG" -hide_banner -loglevel error -y \
  "${loop_args[@]+"${loop_args[@]}"}" -i "$SOURCE" \
  -filter_complex "fps=15,scale=960:540:force_original_aspect_ratio=decrease:flags=lanczos,pad=960:540:(ow-iw)/2:(oh-ih)/2:color=0xF7F8FA,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 \
  "$GIF_OUTPUT"

echo "Generated App Preview: $OUTPUT"
echo "Generated Preview GIF: $GIF_OUTPUT"
