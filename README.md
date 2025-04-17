# 🛠️ Developer Scripts

A small toolbox of useful shell scripts for managing backups, cleaning up junk, and handling media files.  
**Note:** These scripts are written for my specific file paths and setups.  
🧠 **Before using, make sure to check and adjust any file paths to match your environment.**

---

### 🔊 `backup_audio_copy.sh`
Copies audio project folders from multiple source directories to  to my Google Drive backup location. Great for archiving raw sessions and stems.

### 🔁 `backup_audio_sync.sh`
Rsyncs audio project folders (including my Bitwig and Ableton projects) from working drives to my Google Drive backup location. Avoids redundant copies.

### 🏗️ `backup_production.sh`
Specifically backups my audio production projects  to my Google Drive backup location. Used for when I dont want to do a full Audio/ backup.

### 🗑️ `empty_trash.sh`
Force-empties all macOS user and system trash bins, including external volumes. Also logs results and optionally lists deleted file names.

### 🧹 `nukefinder.sh`
Searches for (and optionally nukes) macOS metadata files. Specifically `.DS_Store`, `Icon^M`, and `._AppleDouble` files.  
Defaults to listing the files. Use the `--nuke` flag to actually delete instead of list files.

### 🔧 `fix_wav.sh`
Removes metadata from WAV files in-place using `sox`, optionally converts to 44.1kHz if needed. Helps with Recycle compatibility.

### ⚙️ `update_configs.sh`
Syncs configuration files between local dotfiles and other systems. Optionally commits to git and logs changes.

---

### ⚠️ Use at your own risk  
These scripts are powerful, and some will delete files. Always dry-run or inspect before using in a production environment.