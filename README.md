# 🛠️ Developer Scripts

A small toolbox of useful shell scripts for managing backups, cleaning up junk, and handling media files. Note: These scripts are written for my specific file paths and setups. Before using, make sure to check and adjust any file paths to match your environment.

---

### Script Descriptions

🧹 **nukefinder.sh**

* **Purpose:** Extremely fast at finding and optionally deletesing common macOS metadata junk files.
* **Targets:** `.DS_Store`, `Icon^M` (custom folder icons), and `._*` (AppleDouble files).
* **Engine:** Uses the fast `fd` command if installed, otherwise falls back to the standard `find` command.
* **Exclusions:** By default, automatically skips searching inside `.git`, `.svn`, `.venv`, and `node_modules` directories for speed and safety.
* **Usage:**
    * Run `./nukefinder.sh [target_dir]` for a dry run (lists files found). Defaults to the current directory if none is specified.
    * Add the `--nuke` flag to actually delete the found files.
    * Add the `--venv` flag to *include* `.venv` directories in the scan.
    * Use `-d`, `-i`, or `-a` to search *only* for specific file types (e.g., `./nukefinder.sh -i` only finds `Icon^M` files).

🔊 **backup_audio_copy.sh**

* Copies audio project folders from multiple source directories to my Google Drive backup location. Great for archiving raw sessions and stems.

🔁 **backup_audio_sync.sh**

* Rsyncs audio project folders (including my Bitwig and Ableton projects) from working drives to my Google Drive backup location. Avoids redundant copies.

🏗️ **backup_production.sh**

* Specifically backups my audio production projects to my Google Drive backup location. Used for when I don't want to do a full Audio/ backup.

🗑️ **empty_trash.sh**

* Force-empties all macOS user and system trash bins, including external volumes. Also logs results and optionally lists deleted file names.

🔧 **fix_wav.sh**

* Removes metadata from WAV files in-place using `sox`, optionally converts to 44.1kHz if needed. Helps with Recycle compatibility.

⚙️ **update_configs.sh**

* This script syncs key config files (VS Code settings, keybindings, and custom Oh My Zsh configs) into a local staging folder and commits them to my public dotfiles repository. It uses a custom Git command (`--git-dir` and `--work-tree`) to operate on that repo cleanly without affecting the rest of my system. You probably shouldn't use this one as it's highly specific to my convoluted .dotfiles configurations.

---

⚠️ **Use at your own risk**
These scripts are powerful, and some will delete files. Always dry-run or inspect before using in a production environment.