#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "nogit"
  exit 0
fi

git -C "$ROOT_DIR" ls-files -z -- Sources Tests Configs scripts project.yml Makefile |
  LC_ALL=C sort -z |
  while IFS= read -r -d '' file; do
    printf '%s\0' "$file"
    shasum -a 256 "$ROOT_DIR/$file"
  done |
  shasum -a 256 |
  awk '{ print substr($1, 1, 12) }'
