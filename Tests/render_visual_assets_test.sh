#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDERER="$ROOT_DIR/scripts/render_visual_assets.sh"

bash -n "$RENDERER"
check_output="$(bash "$RENDERER" --check)"

grep -q "FFmpeg:" <<<"$check_output"
grep -q "Source recording:" <<<"$check_output"
grep -q "Source screenshot:" <<<"$check_output"
grep -q "Font:" <<<"$check_output"
grep -q "Text renderer:" <<<"$check_output"

bash "$RENDERER"

gif_width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 \
  "$ROOT_DIR/docs/assets/copy-path-as-demo.gif")"
promo_size="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 \
  "$ROOT_DIR/docs/assets/copy-path-as-promo.png")"
left_headline_margin="$(ffmpeg -v error -i "$ROOT_DIR/docs/assets/copy-path-as-promo.png" \
  -vf "crop=1:1:5:120,format=rgb24" -frames:v 1 -f rawvideo - | od -An -tx1 | tr -d ' \n')"

(( gif_width <= 1100 ))
[[ "$promo_size" == "1600x900" ]]
[[ "$left_headline_margin" != "ffffff" ]]
