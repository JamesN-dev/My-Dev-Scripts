#!/usr/bin/env bash
# nuke: fd-based macOS junk remover (NOW --hidden is actually a toggle!)
set -euo pipefail

PERFORM_NUKE=false
NUKE_DS=false
NUKE_ICONM=false
NUKE_APPLE=false
SHOW_HELP=false
INCLUDE_HIDDEN=false
TARGET_DIR="."

# CLI parsing
while [ $# -gt 0 ]; do
  case "$1" in
    --nuke) PERFORM_NUKE=true ;;
    --hidden) INCLUDE_HIDDEN=true ;;
    -d) NUKE_DS=true ;;
    -i) NUKE_ICONM=true ;;
    -a) NUKE_APPLE=true ;;
    -h|--help) SHOW_HELP=true ;;
    *) TARGET_DIR="$1" ;;
  esac
  shift
done

[ -z "${TARGET_DIR:-}" ] && TARGET_DIR="."

if $SHOW_HELP; then
cat <<EOF
Usage: nuke [--nuke] [--hidden] [-d] [-i] [-a] [-h] [target_dir]

Finds and optionally deletes macOS trash: .DS_Store, Icon^M, ._*
Uses fd.
By default, searches ONLY visible files/dirs.
Use --hidden to also search hidden files/dirs like .venv, .git, etc.

Options:
  --hidden    Include hidden files and folders in scan (uses fd --hidden)
  --nuke      Actually delete files (default: dry run, just lists)
  -d          Only .DS_Store
  -i          Only Icon^M
  -a          Only AppleDouble (._*)
  -h, --help  Show this help
  target_dir  Directory to scan (default: .)
EOF
exit 0
fi

# Default: search all types if none selected
if ! $NUKE_DS && ! $NUKE_ICONM && ! $NUKE_APPLE; then
  NUKE_DS=true
  NUKE_ICONM=true
  NUKE_APPLE=true
fi

# Build fd args
FD_FLAGS=(--no-ignore --type f "$TARGET_DIR")
$INCLUDE_HIDDEN && FD_FLAGS=(--hidden "${FD_FLAGS[@]}")

echo "🔍 Scanning '$TARGET_DIR' $($INCLUDE_HIDDEN && echo '(including hidden files/dirs)' || echo '(visible files/dirs only)')..."

total=0

if $NUKE_DS; then
  if $PERFORM_NUKE; then
    count=$(fd --glob ".DS_Store" "${FD_FLAGS[@]}" -X rm -v | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "Deleted $count .DS_Store files"
  else
    count=$(fd --glob ".DS_Store" "${FD_FLAGS[@]}" | tee /dev/tty | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "Found $count .DS_Store files"
  fi
  total=$((total + count))
fi

if $NUKE_ICONM; then
  if $PERFORM_NUKE; then
    count=$(fd -a "${FD_FLAGS[@]}" | awk -F/ '$NF=="Icon\r"{print}' | tee >(xargs -0 rm -v) | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "Deleted $count Icon^M files"
  else
    count=$(fd -a "${FD_FLAGS[@]}" | awk -F/ '$NF=="Icon\r"{print}' | tee /dev/tty | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "Found $count Icon^M files"
  fi
  total=$((total + count))
fi

if $NUKE_APPLE; then
  if $PERFORM_NUKE; then
    count=$(fd --glob "._*" "${FD_FLAGS[@]}" -X rm -v | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "Deleted $count AppleDouble files"
  else
    count=$(fd --glob "._*" "${FD_FLAGS[@]}" | tee /dev/tty | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "Found $count AppleDouble files"
  fi
  total=$((total + count))
fi

echo "🎀------------------------------🎀"
if $PERFORM_NUKE; then
  echo "🎉 Total files deleted: $total"
else
  echo "🎉 Total files found: $total"
  echo "💡 Run with --nuke to actually delete files."
fi