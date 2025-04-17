#!/bin/bash

# --- Log Setup ---
LOG_DIR="/Users/atetraxx/Developer/Scripts/backup_logs"
mkdir -p "$LOG_DIR" # Ensure log directory exists
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
# Log file name specific to annual sync
LOG_FILE="$LOG_DIR/annual_sync_audio_$TIMESTAMP.log"

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
#           RCLONE SYNC SCRIPT               #
##        Backup Target: /Audio/             #
# ANNUAL SYNC: /Audio -> remote | Logs+Clnup # 
#                                            #
##############################################
EOF

# --- Script Start ---
echo "Starting ANNUAL SYNC for /Audio at $(date). Logging to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$LOG_FILE"
echo "!!! WARNING: THIS WILL DELETE FILES FROM THE DESTINATION   !!!" | tee -a "$LOG_FILE"
echo "!!! TO MAKE IT EXACTLY MATCH THE SOURCE. RUN INFREQUENTLY! !!!" | tee -a "$LOG_FILE"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" | tee -a "$LOG_FILE"
# Optional: Add a sleep/confirmation prompt here if running interactively
# echo "Press Enter to continue or Ctrl+C to abort..."
# read -p ""

# --- Rclone Sync Command ---
# Makes destination identical to source, DELETING extra files from destination!
rclone sync "/Volumes/SSD-8TRAXx/Audio" remote:/_~SSD-8TRAXx/Audio \
  --progress \
  --stats=3s \
  --log-file="$LOG_FILE" \
  --exclude "Plugins/**" \
  --exclude ".*" \
  --modify-window 2s \
  --transfers=10 \
  --checkers=32 \
  --drive-chunk-size=64M \
  --use-mmap \
  --retries 3 \
  --drive-acknowledge-abuse \
  --fast-list \
  --drive-pacer-min-sleep=10ms \
  --drive-pacer-burst=100 \
  -v

# --- Exit Code Capture ---
RCLONE_EXIT_CODE=$?

# --- Completion Log ---
echo "ANNUAL SYNC for /Audio completed at $(date) with exit code $RCLONE_EXIT_CODE" | tee -a "$LOG_FILE"

# --- Log Cleanup ---
# Cleans up logs for *this* script
find "$LOG_DIR" -type f -name "annual_sync_audio_*.log" -mtime +30 -delete
echo "Old annual sync log files deleted from backup_logs/ (if any older than 30 days)." | tee -a "$LOG_FILE"

# --- Exit ---
exit $RCLONE_EXIT_CODE

# --- End of Script ---