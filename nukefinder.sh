#!/usr/bin/env bash
# nukefinder.sh — find and optionally delete macOS metadata files
# Dry-run by default; add --nuke to actually delete.
# Compatible with Bash 3.x+. Uses 'find'.
# Icon deletion uses a direct, simplified 'find -delete' command.

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
    d) NUKE_DS=true; SPECIFIC_TARGETS_REQUESTED=true ;;      # Enable .DS_Store search
    i) NUKE_ICONM=true; SPECIFIC_TARGETS_REQUESTED=true ;;   # Enable Icon^M search
    a) NUKE_APPLE=true; SPECIFIC_TARGETS_REQUESTED=true ;;   # Enable AppleDouble (._*) search
    # V case removed
    h)
      # Display help message and exit
      cat <<EOF
Usage: nukefinder.sh [--nuke] [--venv] [-d] [-i] [-a] [-h] [target_dir]

Finds and optionally deletes macOS metadata files (.DS_Store, Icon^M, ._*).
Compatible with Bash 3.x+. Uses 'find'.
When --nuke is used, Icon^M deletion uses a simplified 'find -delete'.

By default, searches for all types and excludes .git, .svn, .venv, node_modules.
Use flags -d, -i, -a to search *only* for those specific types.

Options:
  -d, --ds-store    Target .DS_Store files
  -i, --icon        Target Icon^M files (filename contains a carriage return)
  -a, --apple       Target AppleDouble (._*) files
      --venv        Include .venv directories in the scan (default: excluded)
      --nuke        Actually delete found files using 'find -delete' (default is dry-run list)
  -h, --help        Show this help message and exit
  target_dir        Directory to scan (default: current directory '.')

Exclusions: By default excludes .git, .svn, .venv, node_modules directories.
            Use --venv to scan inside .venv directories. Pruning applies to dry-run
            and deletion of non-Icon files.
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

# --- Build Pruning Path Conditions (Used for Dry Run and non-Icon Deletion) ---
# Create an array of the -path condition arguments for pruning
declare -a prune_path_conditions=()
# Use -false as the first element if the array might be empty later,
# ensuring the -o logic works correctly. We'll remove it if paths are added.
prune_path_conditions=( -false )

# Add standard exclusions
prune_path_conditions+=( -o -path "$TARGET_ABS_PATH/.git" )
prune_path_conditions+=( -o -path "$TARGET_ABS_PATH/.svn" )
prune_path_conditions+=( -o -path "$TARGET_ABS_PATH/node_modules" )

# Add .venv exclusion only if --venv flag was NOT used
if ! $INCLUDE_VENV; then
  echo "  (Excluding .venv directories. Use --venv to include them.)"
  prune_path_conditions+=( -o -path "$TARGET_ABS_PATH/.venv" )
else
  echo "  (Including .venv directories in scan due to --venv flag.)"
fi

# Remove the initial -false -o if we added actual paths
if [[ ${#prune_path_conditions[@]} -gt 1 ]]; then
    # Remove the first two elements (-false, -o)
    prune_path_conditions=("${prune_path_conditions[@]:2}")
fi


# --- Spinner Function (Disabled) ---
# SPID=""

# --- Cleanup Function ---
cleanup() {
  local exit_status=$?
  # No spinner cleanup needed
  # Ensure we exit with the original status
  exit $exit_status
}
# Set the trap: call 'cleanup' function when script EXITS, receives INT or TERM signal
trap cleanup EXIT INT TERM

# --- Initialize Result Arrays (Used for Dry Run and Summary) ---
# These arrays will store the full paths of found files
DS_FILES=()
ICON_FILES=()
APPLE_FILES=()

# --- Search Helper Function (Used ONLY for Dry Run Listing) ---
# Finds files matching a pattern and stores them in a global array.
# Arguments:
#   $1 = Name of the global array to fill (e.g., DS_FILES)
#   $2 = Search pattern (name pattern for find)
#   $3 = User-friendly label for the file type (e.g., ".DS_Store")
run_search_for_list() {
  local __arr_name=$1 pattern=$2 label=$3 file
  # Use a local array to collect results temporarily
  local -a found_files=()
  # Flag to know if we are searching for Icon files
  local is_icon_search=false
  if [[ "$pattern" == $'\r' ]]; then
      is_icon_search=true
  fi

  echo "🔍 Finding $label files in '$TARGET_ABS_PATH' (for listing)..."

  # Declare raw_output here so it's always in scope
  local raw_output=""
  # Declare the command array variable
  local cmd_array=()
  local using_cmd="find" # Hardcoded to find

  # --- Always use 'find' ---
  local find_pattern="$pattern" # Default pattern

  # Special handling for Icon^M filename
  if $is_icon_search; then
    find_pattern=$'Icon\r'
  fi

  # --- Build the 'find' command with CORRECTED prune logic ---
  cmd_array=(find "$TARGET_ABS_PATH")

  # Add pruning logic only if there are paths to prune
  if [[ ${#prune_path_conditions[@]} -gt 0 ]]; then
      cmd_array+=( \( "${prune_path_conditions[@]}" \) -prune -o )
  fi

  # Add action logic: group conditions (-type f -name ...), then -print0
  cmd_array+=( \( -type f -name "$find_pattern" -print0 \) )

  # *** Assign raw_output ***
  if ! raw_output=$( "${cmd_array[@]}" ); then
       echo "  WARNING ($using_cmd): Command failed during search for list: $?. Output might be empty or incomplete." >&2
  fi

  # Process the captured output
  while IFS= read -r -d '' file <<< "$raw_output"; do
    [[ -z "$file" ]] && continue # Skip empty results
    found_files+=("$file")
  done

  # --- Assign results to the global array using eval ---
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
  printf "  Found %d %s file(s) for listing.\n\n" "$size" "$label"
}


# --- Perform Deletion or List Files ---
if $PERFORM_NUKE; then
  # --nuke flag was given, proceed with deletion using direct find -delete
  echo # Add newline for clarity
  echo "☢️ Preparing to nuke files using 'find -delete'..."

  # --- Delete .DS_Store files (using prune logic) ---
  if $NUKE_DS; then
      echo "💣 Nuking .DS_Store files..."
      delete_cmd_array=(find "$TARGET_ABS_PATH")
      if [[ ${#prune_path_conditions[@]} -gt 0 ]]; then
          delete_cmd_array+=( \( "${prune_path_conditions[@]}" \) -prune -o )
      fi
      delete_cmd_array+=( \( -type f -name ".DS_Store" -print -delete \) )
      echo "  Executing: ${delete_cmd_array[*]}"
      if ! "${delete_cmd_array[@]}"; then
          echo "  WARNING: 'find -delete' for .DS_Store exited with status $?. Some files might not have been deleted." >&2
      else
          echo "✅ Finished nuking .DS_Store files."
      fi
      echo # Add newline
  fi

  # --- Delete Icon^M files (using SIMPLE, DIRECT command) ---
  if $NUKE_ICONM; then
      echo "💣 Nuking Icon^M files (direct method)..."
      # *** USE THE EXACT COMMAND THAT WORKS MANUALLY ***
      delete_cmd_array=(find "$TARGET_ABS_PATH" -name $'Icon\r' -print -delete)
      echo "  Executing: ${delete_cmd_array[*]}"
      if ! "${delete_cmd_array[@]}"; then
           echo "  WARNING: Direct 'find -delete' for Icon^M exited with status $?. Some files might not have been deleted." >&2
      else
          echo "✅ Finished nuking Icon^M files."
      fi
      echo # Add newline
  fi

  # --- Delete AppleDouble files (using prune logic) ---
  if $NUKE_APPLE; then
      echo "💣 Nuking AppleDouble files..."
      delete_cmd_array=(find "$TARGET_ABS_PATH")
      if [[ ${#prune_path_conditions[@]} -gt 0 ]]; then
          delete_cmd_array+=( \( "${prune_path_conditions[@]}" \) -prune -o )
      fi
      delete_cmd_array+=( \( -type f -name "._*" -print -delete \) )
      echo "  Executing: ${delete_cmd_array[*]}"
      if ! "${delete_cmd_array[@]}"; then
          echo "  WARNING: 'find -delete' for AppleDouble exited with status $?. Some files might not have been deleted." >&2
      else
          echo "✅ Finished nuking AppleDouble files."
      fi
      echo # Add newline
  fi

  echo # Add newline
  echo "✅ Deletion process complete."

else
  # --- Dry Run Mode: List the files that *would* be deleted ---
  # Run searches to populate arrays for listing
  $NUKE_DS    && run_search_for_list DS_FILES    ".DS_Store" ".DS_Store"
  $NUKE_ICONM && run_search_for_list ICON_FILES $'\r'       "Icon^M"
  $NUKE_APPLE && run_search_for_list APPLE_FILES "._*"       "AppleDouble"

  echo # Add newline
  echo "🔎 Dry Run Mode: Files identified (run with --nuke to delete):"
  # Check if array is non-empty before printing header and contents
  # Access array size using eval again
  ds_count=$(eval 'echo "${#DS_FILES[@]}"')
  icon_count=$(eval 'echo "${#ICON_FILES[@]}"')
  apple_count=$(eval 'echo "${#APPLE_FILES[@]}"')

  # Print .DS_Store files if found and requested
  if $NUKE_DS && (( ds_count > 0 )); then
      printf "\n--- .DS_Store (%d files) ---\n" "$ds_count"
      printf '%s\n' "${DS_FILES[@]}"
  fi
  # Print Icon^M files if found and requested
  if $NUKE_ICONM && (( icon_count > 0 )); then
      printf "\n--- Icon^M (%d files) ---\n" "$icon_count"
      # Use cat -v to make the carriage return visible in the output list
      printf '%s\n' "${ICON_FILES[@]}" | cat -v
  fi
  # Print AppleDouble files if found and requested
  if $NUKE_APPLE && (( apple_count > 0 )); then
      printf "\n--- AppleDouble (%d files) ---\n" "$apple_count"
      printf '%s\n' "${APPLE_FILES[@]}"
  fi
  # Message if no files of the requested types were found
    # Combine checks: If any requested type was searched AND the total count is zero
    if ($NUKE_DS || $NUKE_ICONM || $NUKE_APPLE) && (( ds_count == 0 && icon_count == 0 && apple_count == 0 )); then
        # Check which types were actually searched for to give a relevant message
        searched_types=()
        $NUKE_DS && searched_types+=(".DS_Store")
        $NUKE_ICONM && searched_types+=("Icon^M")
        $NUKE_APPLE && searched_types+=("AppleDouble")
        # Construct the message based on searched types
        if (( ${#searched_types[@]} > 0 )); then
            printf "  No matching files (%s) found in '%s'.\n" "$(IFS=,; echo "${searched_types[*]}")" "$TARGET_ABS_PATH"
        fi
    # Handle case where no types were specified at all (shouldn't happen with defaults, but safety)
    elif ! $NUKE_DS && ! $NUKE_ICONM && ! $NUKE_APPLE; then
         echo "  No file types were specified for searching in '$TARGET_ABS_PATH'."
    fi
fi # End of if $PERFORM_NUKE

# --- Final Summary ---
# NOTE: The counts for the summary still rely on the arrays populated
# during the dry run OR by the run_search_for_list calls if --nuke was NOT used.
# If --nuke was used, these counts reflect what *would have been* found,
# not necessarily what was *actually* deleted if find -delete failed partially.

# Determine verb based on whether deletion was ATTEMPTED
word=$($PERFORM_NUKE && echo "Deletion Attempted" || echo "Found")
echo # Add newline
echo "🌈✨ Finder Junk $word Report ✨🌈"
echo "🎀-------------------------------------🎀"
# Initialize total count
total=0
# Get counts again using eval from the arrays (populated in dry run)
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
# Print the total based on the dry-run find
printf "🎉 Total Files Found (Dry Run): %d 🎉\n" "$total"
echo "🎀-------------------------------------🎀"
# Add reminder if dry-run was performed
$PERFORM_NUKE || echo "💡 Run with --nuke to ACTUALLY delete these files using 'find -delete'! 💡"
$PERFORM_NUKE && echo "ℹ️  Deletion was performed using 'find ... -delete'. Check output above for details/errors."

# Trap will handle exit and cleanup
exit 0
