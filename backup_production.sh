#!/bin/bash

# --- Log Setup ---
# Define log directory and timestamped log file name FIRST
LOG_DIR="$(dirname "$0")/backup_logs"
mkdir -p "$LOG_DIR" # Ensure log directory exists
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
# Use a distinct name for this script's logs
LOG_FILE="$LOG_DIR/backup_production_$TIMESTAMP.log"

# --- ASCII Art Banner (Logged) ---
# Now $LOG_FILE is defined, we can log the banner to it
cat << EOF | tee -a "$LOG_FILE"
##############################################
#                                            #
#         _  _____ _____ ____ __  __         #
#        / \|_   _| ____|  _ \\ \/ /         #
#       / _ \ | | |  _| | |_) |\  /          #
#      / ___ \| | | |___|  _ < /  \          #
#     / /   \_|_| |_____|_| \_/_/\_\         #
#                                            #
#                                            #
##############################################
#     Backup Target: /Audio/Production       # 
##############################################
EOF

# --- Script Start ---
echo "Starting Production backup at $(date +"%Y-%m-%d %H:%M:%S"). Logging to: $LOG_FILE" | tee -a "$LOG_FILE"

# --- Rclone Command for /Audio/Production ---
# Note: Removed manual rotation logic from original script
rclone copy "/Volumes/SSD-8TRAXx/Audio/Production" remote:/_~SSD-8TRAXx/Audio/Production \
  --progress \
  --stats=3s \
  --log-file="$LOG_FILE" \  # Use timestamped log file
  --log-file-max-size 5M \  # Enable log file size-based rotation
  --ignore-existing \
  --exclude "Plugins/**" \
  --exclude ".*" \
  --transfers=30 \
  --checkers=64 \
  --drive-chunk-size=64M \
  --tpslimit 95 \
  --use-mmap \
  --retries 3 \
  --drive-acknowledge-abuse \
  --fast-list \
  --drive-pacer-min-sleep=1ms \
  --drive-pacer-burst=1000 \
  -vv # Very verbose

# --- Capture and Check Exit Code ---
RCLONE_EXIT_CODE=$? # Capture rclone's exit status IMMEDIATELY

# --- Script End ---
echo "Production backup completed at $(date +"%Y-%m-%d %H:%M:%S") with exit code $RCLONE_EXIT_CODE" | tee -a "$LOG_FILE"

# --- Log Cleanup ---
# Find and delete logs matching this script's pattern older than 30 days
find "$LOG_DIR" -type f -name "backup_production_*.log" -mtime +30 -delete
echo "Old production backup log files deleted (if any older than 30 days)." | tee -a "$LOG_FILE"

# --- Exit with the same code as rclone ---
exit $RCLONE_EXIT_CODE

# --- End of Script Comments ---
# This script backs up the /Audio/Production directory using rclone.
# Features: Timestamped logs, banner, exit code handling, rclone size-based log rotation, cleanup of logs older than 30 days.