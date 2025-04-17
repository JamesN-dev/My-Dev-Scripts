#!/bin/bash

# --- Log Setup ---
LOG_DIR="${HOME}/Developer/Scripts/backup_logs"
mkdir -p "$LOG_DIR" # Ensure log directory exists
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
# Log file name specific to regular copy backups
LOG_FILE="$LOG_DIR/backup_audio_copy_$TIMESTAMP.log"

# --- ASCII Art Banner (Logged) ---
cat << EOF | tee -a "$LOG_FILE"
##############################################
#                                            #
#         _  _____ _____ ____ __  __         #
#        / \|_   _| ____|  _ \\ \/  /         #
#       / _ \ | | |  _| | |_) |\  /          #
#      / ___ \| | | |___|  _ < /  \          #
#     / /   \_|_| |_____|_| \_/_/\_\         #
#                   coded by - ATERX         #
#                                            #
##############################################
#                                            #
#           RCLONE COPY SCRIPT               #
##        Backup Target: /Audio/             #
# Rclone backup for /Audio w/ Logs & Cleanup # 
#                                            #
##############################################
EOF

# --- Script Start ---
echo "Starting REGULAR COPY backup for /Audio at $(date). Logging to: $LOG_FILE" | tee -a "$LOG_FILE"

# --- Rclone Copy Command ---
SOURCE="/Volumes/SSD-8TRAXx/Audio"
DESTINATION="remote:/_~SSD-8TRAXx/Audio"

if [ ! -d "$SOURCE" ]; then
  echo "Source directory not found: $SOURCE" | tee -a "$LOG_FILE"
  exit 1
fi

# Copies new/changed files, does NOT delete destination files
rclone copy "$SOURCE" "$DESTINATION" \
  --progress \
  --stats=3s \
  --log-file="$LOG_FILE" \
  --exclude "Plugins/**" \
  --exclude ".*" \
  --transfers=10 \
  --checkers=32 \
  --drive-chunk-size=64M \
  --use-mmap \
  --retries 3 \
  --drive-acknowledge-abuse \
  --fast-list \
  --drive-pacer-min-sleep=8ms \
  --drive-pacer-burst=100 \
  --modify-window 2s \
  -v

# --- Exit Code Capture ---
RCLONE_EXIT_CODE=$?

# --- Completion Log ---
echo "REGULAR COPY backup for /Audio completed at $(date) with exit code $RCLONE_EXIT_CODE" | tee -a "$LOG_FILE"

# --- Log Cleanup ---
# Cleans up logs for *this* script
find "${HOME}/Developer/Scripts/backup_logs" -type f -name "backup_audio_copy_*.log" -mtime +30 -delete
echo "Old regular copy log files deleted from backup_logs/ (if any older than 30 days)." | tee -a "$LOG_FILE"

# --- Exit ---
exit $RCLONE_EXIT_CODE

# --- End of Script ---