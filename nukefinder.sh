#!/usr/bin/env bash
# nukefinder.sh — find and optionally delete macOS metadata files
# Dry-run by default; add --nuke to actually delete.
# Compatible with Bash 3.x+

# Strict mode: Exit on error, unset variable, pipe failure
set -euo pipefail

# --- Initialize options ---
PERFORM_NUKE=false
INCLUDE_VENV=false # Flag to include .venv directories
# Start with types OFF by default if specific flags are used
NUKE_DS=false
NUKE_ICONM=false
NUKE_APPLE=false
# Keep track if any specific type flags were given
SPECIFIC_TARGETS_REQUESTED=false

# --- Pre-parse arguments for long options (--nuke, --venv) ---
# We need to handle these before getopts processes short flags.
args=() # Temporary array to hold arguments not handled here
for a in "$@"; do
  case "$a" in
    --nuke)
      PERFORM_NUKE=true
      ;;
    --venv) # New: Handle --venv here
      INCLUDE_VENV=true
      ;;
    *)
      # Add other args (like short options or target dir) to the temp array
      args+=("$a")
      ;;
  esac
done
# Reset positional parameters ($1, $2, ...) to only contain the arguments
# that were not --nuke or --venv.
# The :- prevents errors if args array is empty
set -- "${args[@]:-}"

# --- Option Parsing (getopts for short options) ---
# Process short options (-d, -i, -a, -h)
while getopts ":diah" opt; do # Removed V from the options string
  case $opt in
    d) NUKE_DS=true; SPECIFIC_TARGETS_REQUESTED=true ;;       # Enable .DS_Store search
    i) NUKE_ICONM=true; SPECIFIC_TARGETS_REQUESTED=true ;;    # Enable Icon^M search
    a) NUKE_APPLE=true; SPECIFIC_TARGETS_REQUESTED=true ;;    # Enable AppleDouble (._*) search
    # V case removed
    h)
      # Display help message and exit
      cat <<EOF
Usage: nukefinder.sh [--nuke] [--venv] [-d] [-i] [-a] [-h] [target_dir]

Finds and optionally deletes macOS metadata files (.DS_Store, Icon^M, ._*).
Compatible with Bash 3.x+. Uses 'fd' if available, falls back to 'find'.

By default, searches for all types and excludes .git, .svn, .venv, node_modules.
Use flags -d, -i, -a to search *only* for those specific types.

Options:
  -d, --ds-store   Target .DS_Store files
  -i, --icon       Target Icon^M files (filename contains a carriage return)
  -a, --apple      Target AppleDouble (._*) files
      --venv       Include .venv directories in the scan (default: excluded)
      --nuke       Actually delete found files (default is a dry-run list)
  -h, --help       Show this help message and exit
  target_dir       Directory to scan (default: current directory '.')

Exclusions: By default excludes .git, .svn, .venv, node_modules directories.
            Use --venv to scan inside .venv directories.
EOF
      exit 0
      ;;
    \?) # Handle invalid options
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
     :) # Handle options missing arguments (none in this script, but good practice)
       echo "Option -$OPTARG requires an argument." >&2
       exit 1
       ;;
  esac
done
# Remove processed options from positional parameters
shift $((OPTIND-1))

# --- Default Target Logic ---
# If no specific target flags (-d, -i, -a) were given, default to enabling all targets.
if ! $SPECIFIC_TARGETS_REQUESTED; then
  NUKE_DS=true
  NUKE_ICONM=true
  NUKE_APPLE=true
fi

# --- Determine Target Directory ---
# Use the first remaining positional parameter as target, or default to '.'
TARGET_DIR=${1:-.}
# Check if the target is actually a directory
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: '$TARGET_DIR' is not a directory." >&2
  exit 1
fi
# Get the absolute path for consistency, especially for exclusions
# Using subshell to avoid changing script's CWD
TARGET_ABS_PATH=$(cd "$TARGET_DIR" && pwd)

# --- Exclusion Rules ---
# Define paths to exclude/prune for 'find' and 'fd' conditionally
# Note: These paths must be absolute for reliable pruning with 'find'
PRUNE_ARGS=( -path "$TARGET_ABS_PATH/.git" -o -path "$TARGET_ABS_PATH/.svn" -o \
             -path "$TARGET_ABS_PATH/node_modules" -prune -o )
# Exclusions for 'fd' (uses relative paths from target dir)
FD_EX=( --hidden --exclude .git --exclude .svn --exclude node_modules )

# Add .venv exclusion only if --venv flag was NOT used
if ! $INCLUDE_VENV; then
  echo "  (Excluding .venv directories. Use --venv to include them.)"
  PRUNE_ARGS=( -path "$TARGET_ABS_PATH/.venv" -prune -o "${PRUNE_ARGS[@]}" ) # Add .venv to find's prune
  FD_EX+=( --exclude .venv ) # Add .venv to fd's exclude
else
  echo "  (Including .venv directories in scan due to --venv flag.)"
fi

# --- Spinner Function ---
# Displays a simple rotating spinner animation
# NOTE: Spinner is currently disabled for debugging deletion issues.
# spin() {
#   local marks='/-\|' i=0
#   # Loop indefinitely until killed
#   while :; do
#     # Print the next spinner character, overwriting the previous one
#     printf "\r[%c] Nuking..." "${marks:i++%${#marks}:1}"
#     sleep 0.1 # Pause briefly
#   done
# }
# Global variable to hold the spinner's Process ID (PID)
# SPID="" # Spinner PID management disabled

# --- Cleanup Function ---
# This function is called on script exit (normal or error) via 'trap'
cleanup() {
  local exit_status=$? # Capture the script's exit status
  # echo "[Cleanup Trap Activated - Exit Status: $exit_status]" # Debugging trap
  # Check if the spinner PID is set and the process exists
  # Spinner killing logic is commented out as spinner is disabled
  # if [[ -n "${SPID:-}" ]] && kill -0 "$SPID" 2>/dev/null; then
  #     echo "[Cleanup: Killing spinner PID $SPID]" # Debug message
  #     kill "$SPID"      # Kill the spinner process
  #     wait "$SPID" 2>/dev/null # Wait for it to prevent "Terminated" message
  #     printf "\r%s\n" "Nuking process ended." # Clean up the spinner line
  # fi
  # Exit with the original exit status
  # This ensures errors that triggered the trap are propagated
  exit $exit_status
}
# Set the trap: call 'cleanup' function when script EXITS, receives INT or TERM signal
trap cleanup EXIT INT TERM

# --- Initialize Result Arrays ---
# These arrays will store the full paths of found files
DS_FILES=()
ICON_FILES=()
APPLE_FILES=()

# --- Search Helper Function ---
# Finds files matching a pattern and stores them in a global array.
# Arguments:
#   $1 = Name of the global array to fill (e.g., DS_FILES)
#   $2 = Search pattern (glob for fd, name pattern for find)
#   $3 = User-friendly label for the file type (e.g., ".DS_Store")
run_search() {
  local __arr_name=$1 pattern=$2 label=$3 file
  # Use a local array to collect results temporarily
  local -a found_files=()

  echo "🔍 Finding $label files in '$TARGET_ABS_PATH'..."

  # Check if 'fd' command is available
  if command -v fd &>/dev/null; then
    # echo "  (Using 'fd' command)" # DEBUG
    local fd_pattern="$pattern" # Default pattern
    # --- CORRECTED PATTERN FOR FD ---
    # If the input pattern is just CR, construct the literal 'Icon<CR>' pattern for fd
    if [[ "$pattern" == $'\r' ]]; then
        fd_pattern=$'Icon\r' # Use the literal filename "Icon<CR>" for fd's glob
        # echo "  (Using literal 'Icon^M' pattern '$fd_pattern' for fd --glob)" # DEBUG
    fi
    # ---------------------------------
    # Use 'fd': faster, simpler syntax, handles exclusions easily
    # -0 prints null-separated filenames for safe handling
    local fd_cmd_array=(fd "${FD_EX[@]}" --type f --glob "$fd_pattern" "$TARGET_ABS_PATH" -0) # Store command parts in array
    # echo "  DEBUG: Running fd command: ${fd_cmd_array[*]}" # Print the command array elements (Commented out for less noise)
    while IFS= read -r -d '' file; do
      # echo "  DEBUG: fd found: [$file]" # DEBUG: Print found file path, bracketed for clarity (Commented out for less noise)
      found_files+=("$file")
    done < <("${fd_cmd_array[@]}") # Execute the command from the array
    # echo "  DEBUG: fd command finished." # DEBUG (Commented out for less noise)
  else
    # echo "  (Using 'find' command fallback)" # DEBUG
    # Fallback to 'find': standard, but syntax is more complex
    local find_pattern="$pattern"
    # Special handling for Icon^M filename (contains carriage return)
    if [[ "$pattern" == $'\r' ]]; then
        # The $'' syntax creates the literal carriage return character for find's -name
        find_pattern=$'Icon\r'
        # echo "  (Using 'find -name' with pattern '$find_pattern')" # DEBUG
    fi
    # Use 'find':
    # \( ... \) - grouping for prune logic
    # "${PRUNE_ARGS[@]}" - expands to the exclusion paths/prune logic
    # -type f - search only for files
    # -name "$find_pattern" - match the filename pattern
    # -print0 - print null-separated filenames
    local find_cmd_array=(find "$TARGET_ABS_PATH" \( "${PRUNE_ARGS[@]}" \) -type f -name "$find_pattern" -print0) # Store command parts
    # echo "  DEBUG: Running find command: ${find_cmd_array[*]}" # Print the command array elements (Commented out for less noise)
    while IFS= read -r -d '' file; do
      # echo "  DEBUG: find found: [$file]" # DEBUG: Print found file path (Commented out for less noise)
      found_files+=("$file")
    done < <("${find_cmd_array[@]}") # Execute the command from the array
    # echo "  DEBUG: find command finished." # DEBUG (Commented out for less noise)
  fi

  # --- Assign results to the global array using eval (Bash 3.x compatible) ---
  local assignment_cmd
  printf -v assignment_cmd "%s=(" "$__arr_name"
  local i
  for i in "${!found_files[@]}"; do
      printf -v assignment_cmd "%s %q" "$assignment_cmd" "${found_files[$i]}"
  done
  assignment_cmd+=")"
  eval "$assignment_cmd"

  # --- Report count ---
  local count_cmd size
  printf -v count_cmd 'echo "${#%s[@]}"' "$__arr_name"
  size=$(eval "$count_cmd")
  printf "  Found %d %s file(s).\n\n" "$size" "$label"
}

# --- Collect Files ---
# Call run_search for each enabled file type
$NUKE_DS    && run_search DS_FILES   ".DS_Store" ".DS_Store"
# Pass the CR character; run_search adapts the pattern for fd or find
$NUKE_ICONM && run_search ICON_FILES $'\r'       "Icon^M"
$NUKE_APPLE && run_search APPLE_FILES "._*"       "AppleDouble"


# --- Deletion Function ---
# Deletes files listed in a global array (passed by name).
# Arguments:
#   $1 = Name of the global array containing files to delete (e.g., "DS_FILES")
#   $2 = User-friendly label for the file type (e.g., ".DS_Store")
delete_files() {
    local arr_name=$1 # Get the *name* of the array
    local label=$2
    local file_count_cmd file_print_cmd file_count

    # --- Access the global array using eval (Bash 3.x compatible) ---
    printf -v file_count_cmd 'echo "${#%s[@]}"' "$arr_name"
    printf -v file_print_cmd 'printf "%%s\\0" "${%s[@]}"' "$arr_name"
    file_count=$(eval "$file_count_cmd")

    if (( file_count > 0 )); then
        echo "💣 Nuking ${file_count} $label files... (Spinner disabled)" # Indicate spinner is off
        # Output from rm -v will now be visible
        eval "$file_print_cmd" | xargs -0 rm -v
        echo "✅ Nuked $label files."
    else
        echo "👻 No $label files to nuke."
    fi
}

# --- Perform Deletion or List Files ---
if $PERFORM_NUKE; then
  # --nuke flag was given, proceed with deletion
  echo # Add newline for clarity
  echo "☢️ Preparing to nuke files..."
  # Call delete_files for each enabled type, passing the array *name*
  $NUKE_DS    && delete_files "DS_FILES"    ".DS_Store"
  $NUKE_ICONM && delete_files "ICON_FILES"  "Icon^M"
  $NUKE_APPLE && delete_files "APPLE_FILES" "AppleDouble"
  echo # Add newline
  echo "✅ Deletion process complete."
else
  # Dry Run Mode: List the files that *would* be deleted
  echo # Add newline
  echo "🔎 Dry Run Mode: Files identified (run with --nuke to delete):"
  # Check if array is non-empty before printing header and contents
  # Access array size using eval again
  ds_count=$(eval 'echo "${#DS_FILES[@]}"')
  icon_count=$(eval 'echo "${#ICON_FILES[@]}"')
  apple_count=$(eval 'echo "${#APPLE_FILES[@]}"')

  if $NUKE_DS && (( ds_count > 0 )); then
      printf "\n--- .DS_Store (%d files) ---\n" "$ds_count"
      printf '%s\n' "${DS_FILES[@]}"
  fi
  if $NUKE_ICONM && (( icon_count > 0 )); then
      printf "\n--- Icon^M (%d files) ---\n" "$icon_count"
      printf '%s\n' "${ICON_FILES[@]}"
  fi
  if $NUKE_APPLE && (( apple_count > 0 )); then
      printf "\n--- AppleDouble (%d files) ---\n" "$apple_count"
      printf '%s\n' "${APPLE_FILES[@]}"
  fi
   if (( ds_count == 0 && icon_count == 0 && apple_count == 0 )); then
       echo "  No matching files found in '$TARGET_ABS_PATH'."
   fi
fi

# --- Final Summary ---
# Determine verb based on whether deletion occurred
word=$($PERFORM_NUKE && echo "Deleted" || echo "Found")
echo # Add newline
echo "🌈✨ Finder Junk $word Report ✨🌈"
echo "🎀-------------------------------------🎀"
# Initialize total count
total=0
# Get counts again using eval for the summary
ds_count=$(eval 'echo "${#DS_FILES[@]}"')
icon_count=$(eval 'echo "${#ICON_FILES[@]}"')
apple_count=$(eval 'echo "${#APPLE_FILES[@]}"')

# Display count for each type *if* it was searched for
if $NUKE_DS; then
    printf "  🗑️  .DS_Store    : %d\n" "$ds_count"
    total=$(( total + ds_count ))
fi
if $NUKE_ICONM; then
    printf "  👻  Icon^M       : %d\n" "$icon_count"
    total=$(( total + icon_count ))
fi
if $NUKE_APPLE; then
    printf "  🧟  AppleDouble  : %d\n" "$apple_count"
    total=$(( total + apple_count ))
fi
# Print the total
printf "🎉 Total %s : %d 🎉\n" "$word" "$total"
echo "🎀-------------------------------------🎀"
# Add reminder if dry-run was performed
$PERFORM_NUKE || echo "💡 Run with --nuke to delete these files! 💡"

# Trap will handle exit and cleanup
exit 0
