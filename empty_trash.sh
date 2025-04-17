#!/bin/zsh
# Using zsh shebang as preferred, but full paths make it robust

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Define Full Paths ---
# (Standard macOS paths)
_date="/bin/date"
_tee="/usr/bin/tee"
_stat="/usr/bin/stat"
_tail="/usr/bin/tail"
_find="/usr/bin/find"
_wc="/usr/bin/wc"
_tr="/usr/bin/tr"
_du="/usr/bin/du"
_cut="/usr/bin/cut"
_sort="/usr/bin/sort"
_head="/usr/bin/head"
_mkdir="/bin/mkdir"
_id="/usr/bin/id"
_rm="/bin/rm"

# Set up logging
LOG_DIR="$HOME/Developer/Scripts/backup_logs"
LOG_FILE="$LOG_DIR/trash_empty.log"
MAX_LOG_SIZE=$((5 * 1024 * 1024)) # 5MB in bytes
# Use full path for mkdir
$_mkdir -p "$LOG_DIR" # Ensure log directory exists

# Log rotation function
rotate_log() {
    local size
    if [[ -f "$LOG_FILE" ]]; then
        # Use full paths for stat and tail
        size=$($_stat -f%z "$LOG_FILE" 2>/dev/null || $_stat -c%s "$LOG_FILE" 2>/dev/null)
        if [[ -n "$size" ]] && [[ "$size" -gt "$MAX_LOG_SIZE" ]]; then
            echo "$($_date '+%Y-%m-%d %H:%M:%S') - Rotating log..." >> "${LOG_FILE}.old"
            $_tail -n 1000 "$LOG_FILE" >> "${LOG_FILE}.old"
            echo "Log rotated at $($_date)" > "$LOG_FILE"
            echo "Previous log saved/appended to ${LOG_FILE}.old" >> "$LOG_FILE"
            echo "$($_date '+%Y-%m-%d %H:%M:%S') - Starting new log." >> "$LOG_FILE"
        fi
    fi
}

# Logging function
log() {
    # Use full paths for date and tee
    local timestamp=$($_date '+%Y-%m-%d %H:%M:%S')
    print "$timestamp - $1" | $_tee -a "$LOG_FILE"
}

# --- Script Start ---
rotate_log

log "Starting trash analysis..."
print "${BLUE}Analyzing Trash contents...${NC}"

# Get user's UID using full path for id
USER_UID=$($_id -u)

# Safely find actual trash paths
TRASH_PATHS=()
if [[ -d "$HOME/.Trash" ]]; then
    TRASH_PATHS+=("$HOME/.Trash")
fi
setopt null_glob
for vol_trash in /Volumes/*/.Trashes/"$USER_UID"; do
    if [[ -d "$vol_trash" ]]; then
        TRASH_PATHS+=("$vol_trash")
    fi
done
unsetopt null_glob

# Analyze trash locations
total_files_overall=0
locations_with_files=0
declare -A location_summary # Use zsh associative array

for actual_path in "${TRASH_PATHS[@]}"; do
    print "\n${BLUE}Checking Location: $actual_path${NC}"
    # Use full paths for find, wc, tr
    file_count=$($_find "$actual_path" -type f -print 2>/dev/null | $_wc -l | $_tr -d ' ')

    if [[ "$file_count" -gt 0 ]]; then
        locations_with_files=$((locations_with_files + 1))
        total_files_overall=$((total_files_overall + file_count))
        # Use full paths for du, cut
        total_size=$($_du -sh "$actual_path" 2>/dev/null | $_cut -f1)
        print "${GREEN}Files: $file_count${NC}"
        print "${GREEN}Total size: $total_size${NC}"
        location_summary[$actual_path]=" ($file_count files, size: $total_size)"
        log "Location $actual_path: $file_count files, size: $total_size"

        print "${BLUE}Largest files:${NC}"
        # Use full paths for find, du, sort, head, cut
        ( $_find "$actual_path" -type f -exec $_du -sh {} + 2>/dev/null | $_sort -rh | $_head -n 5 ) | \
            while IFS= read -r line; do
                size=$(echo "$line" | $_cut -f1)
                file=$(echo "$line" | $_cut -f2-)
                print "  $size  ${file:t}" # Use zsh :t for basename
            done
    else
         print "${BLUE}Location is empty.${NC}"
         location_summary[$actual_path]=" (empty)"
         log "Location $actual_path: empty"
    fi
done

# Confirmation Phase
if [[ "$locations_with_files" -gt 0 ]]; then
    print "\n${BLUE}Found $total_files_overall file(s) in $locations_with_files location(s).${NC}"
    print "${BLUE}Do you want to empty the contents of these trash locations?${NC}"
    for path in "${(@k)location_summary}"; do # zsh key iteration
        print "  - ${path}${location_summary[$path]}"
    done
    read -q "REPLY?Empty Trash? (y/n) "
    print

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Starting trash emptying process..."
        print "\n${BLUE}Emptying Trash...${NC}"
        # Use full path for date
        START_TIME=$($_date +%s)

        for actual_path in "${(@k)location_summary}"; do
            if [[ -d "$actual_path" ]]; then
                 if [[ "${location_summary[$actual_path]}" != *" (empty)"* ]]; then
                    print "${BLUE}Emptying contents of $actual_path...${NC}"
                    # Use full path for rm inside subshell
                    ( setopt local_options null_glob dot_glob; $_rm -rf "$actual_path"/* 2>> "$LOG_FILE" )
                    exit_code=$?
                    if [[ $exit_code -eq 0 ]]; then
                        log "Successfully emptied contents of $actual_path"
                    else
                        log "Errors occurred while emptying contents of $actual_path (exit code: $exit_code). Check log."
                        print "${RED}Errors occurred emptying $actual_path. See log.${NC}"
                    fi
                 fi
            fi
        done

        # Use full path for date
        END_TIME=$($_date +%s)
        DURATION=$((END_TIME - START_TIME))
        print "${GREEN}Trash emptying process completed in ${DURATION} seconds!${NC}"
        log "Trash emptying process completed in ${DURATION} seconds"
    else
        log "Operation cancelled by user"
        print "${RED}Operation cancelled${NC}"
    fi
else
    print "\n${GREEN}All trash locations analyzed are empty.${NC}"
    log "All trash locations analyzed are empty."
fi

log "Script finished"
print "\n${BLUE}Log file available at: $LOG_FILE${NC}"