#!/bin/bash

# Default behavior: List files only. Deletion requires --nuke flag.
NUKE_DS=true
NUKE_ICONM=true
NUKE_APPLE=true
PERFORM_NUKE=false # Default to listing, not nuking

# --- Pre-parse for --nuke ---
# Need to handle long options manually before getopts
_args=()
for arg in "$@"; do
    case $arg in
        --nuke)
            PERFORM_NUKE=true
            shift # Remove --nuke from argument list for getopts
            ;;
        *)
            _args+=("$arg") # Keep other arguments
            ;;
    esac
done
# Reset positional parameters for getopts
set -- "${_args[@]}"
# --- End Pre-parse ---


# Parse Short Args
while getopts "diah" opt; do
    case $opt in
        d) NUKE_ICONM=false; NUKE_APPLE=false ;; # Only DS_Store
        i) NUKE_DS=false; NUKE_APPLE=false ;;    # Only Icon\r
        a) NUKE_DS=false; NUKE_ICONM=false ;;   # Only AppleDouble ._*
        h)
            echo "Usage: nukefinder.sh [--nuke] [-d] [-i] [-a] [-h]"
            echo "  Lists specified macOS metadata files recursively by default."
            echo "  --nuke   Actually delete the found files."
            echo "  -d       Target only .DS_Store files."
            echo "  -i       Target only Icon^M files (Icon + carriage return)."
            echo "  -a       Target only AppleDouble ._* files."
            echo "  -h       Show this help message."
            exit 0
            ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Determine action message
action_msg="Listing"
if $PERFORM_NUKE; then
    action_msg="Nuking (deleting)"
fi

echo "🔎 $action_msg Finder trash from $(pwd)..."
echo "   (Run with --nuke to actually delete files)"

ds_count=0
iconm_count=0
appledouble_count=0

# --- .DS_Store ---
if $NUKE_DS; then
    echo "--- Finding .DS_Store files ---"
    # List files first (default action)
    find . -name ".DS_Store" -print
    # Count files (needs to run find again or process output differently)
    ds_count=$(find . -name ".DS_Store" -print | wc -l | xargs) # xargs trims whitespace
    # Perform deletion only if --nuke is specified
    if $PERFORM_NUKE; then
        find . -name ".DS_Store" -delete
        echo "--- .DS_Store deletion attempted ---"
    fi
    echo # Add a newline for spacing
fi

# --- Icon\r ---
if $NUKE_ICONM; then
    echo "--- Finding Icon^M files ---"
    # List files first
    find . -type f -name "Icon?" -exec bash -c '
        f=$(basename "$1")
        [[ "$f" == $'\''Icon\r'\'' ]] && echo "$1"
    ' bash {} \;
    # Count files
    iconm_count=$(find . -type f -name "Icon?" -exec bash -c '
        f=$(basename "$1")
        [[ "$f" == $'\''Icon\r'\'' ]] && echo "$1"
    ' bash {} \; | wc -l | xargs)
    # Perform deletion only if --nuke is specified
    if $PERFORM_NUKE; then
        find . -type f -name "Icon?" -exec bash -c '
            f=$(basename "$1")
            [[ "$f" == $'\''Icon\r'\'' ]] && rm "$1"
        ' bash {} \;
        echo "--- Icon^M deletion attempted ---"
    fi
    echo # Add a newline for spacing
fi

# --- ._* AppleDouble ---
if $NUKE_APPLE; then
    echo "--- Finding ._* AppleDouble files ---"
    # List files first
    find . -name "._*" -print
    # Count files
    appledouble_count=$(find . -name "._*" -print | wc -l | xargs)
    # Perform deletion only if --nuke is specified
    if $PERFORM_NUKE; then
        find . -name "._*" -delete
        echo "--- ._* AppleDouble deletion attempted ---"
    fi
    echo # Add a newline for spacing
fi

# --- Final Report ---
report_action="Found"
if $PERFORM_NUKE; then
    report_action="Destroyed"
fi

echo "" # Add a blank line for spacing before the report
echo "✅ Finder garbage $report_action:"
# Use echo with literal emojis for better compatibility
$NUKE_DS      && echo "   🗑️  .DS_Store      : $ds_count"
$NUKE_ICONM   && echo "   👻  Icon^M         : $iconm_count"
$NUKE_APPLE   && echo "   🧟  ._AppleDouble  : $appledouble_count"

# Add reminder only if not nuking
if ! $PERFORM_NUKE; then
    echo "(Run again with --nuke to delete these files)"
fi