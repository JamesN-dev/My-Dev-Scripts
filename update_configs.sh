#!/usr/bin/env zsh

echo "Starting configuration update..."

# --- Configuration ---
# Git command for the public dotfiles repository (using full path for script reliability)
GIT_CMD="/usr/bin/git --git-dir=$HOME/.public-dotfiles/ --work-tree=$HOME"

# Source paths (Live configuration files)
VS_CODE_SETTINGS_SOURCE="$HOME/Library/Application Support/Code/User/settings.json"

VS_CODE_KEYBINDINGS_SOURCE="$HOME/Library/Application Support/Code/User/keybindings.json"
ALIASES_SOURCE="$HOME/.oh-my-zsh/custom/aliases.zsh"
MACOS_SOURCE="$HOME/.oh-my-zsh/custom/macos.zsh"

# Destination directory (Where files are tracked in the Git repo structure)
CONFIG_FILES_STAGING_DIR="$HOME/Developer/.config-files"
VSCODE_DEST_DIR="$CONFIG_FILES_STAGING_DIR/vscode"
OH_MY_ZSH_DEST_DIR="$CONFIG_FILES_STAGING_DIR/oh-my-zsh"

# --- Ensure Destination Directories Exist ---
# Use -p to avoid errors if they already exist and create parent dirs if needed
mkdir -p "$VSCODE_DEST_DIR"
echo "Ensured directory exists: $VSCODE_DEST_DIR"
mkdir -p "$OH_MY_ZSH_DEST_DIR"
echo "Ensured directory exists: $OH_MY_ZSH_DEST_DIR"

# --- Copy Files (with checks) ---

echo "Copying VS Code settings..."
if [ -f "$VS_CODE_SETTINGS_SOURCE" ]; then
    cp "$VS_CODE_SETTINGS_SOURCE" "$VSCODE_DEST_DIR/settings.json"
    echo " -> Copied settings.json"
else
    echo " -> WARNING: Source file not found: $VS_CODE_SETTINGS_SOURCE"
fi

echo "Copying VS Code keybindings..."
if [ -f "$VS_CODE_KEYBINDINGS_SOURCE" ]; then
    cp "$VS_CODE_KEYBINDINGS_SOURCE" "$VSCODE_DEST_DIR/keybindings.json"
    echo " -> Copied keybindings.json"
else
    echo " -> WARNING: Source file not found: $VS_CODE_KEYBINDINGS_SOURCE"
fi

echo "Copying Oh My Zsh aliases..."
if [ -f "$ALIASES_SOURCE" ]; then
    # *** This cp command was missing ***
    cp "$ALIASES_SOURCE" "$OH_MY_ZSH_DEST_DIR/aliases.zsh"
    echo " -> Copied aliases.zsh"
else
    echo " -> WARNING: Source file not found: $ALIASES_SOURCE"
fi

echo "Copying Oh My Zsh macos settings..."
if [ -f "$MACOS_SOURCE" ]; then
    # *** This cp command was missing ***
    cp "$MACOS_SOURCE" "$OH_MY_ZSH_DEST_DIR/macos.zsh"
    echo " -> Copied macos.zsh"
else
    # This is fine if you don't use this file, but we check anyway
    echo " -> INFO: Source file not found (optional): $MACOS_SOURCE"
fi

# --- Git Operations ---

echo "Adding files to git stage..."
# Add files, using the paths within the staging directory
$GIT_CMD add "$VSCODE_DEST_DIR/settings.json"
$GIT_CMD add "$VSCODE_DEST_DIR/keybindings.json"
$GIT_CMD add "$OH_MY_ZSH_DEST_DIR/aliases.zsh"
$GIT_CMD add "$OH_MY_ZSH_DEST_DIR/macos.zsh"

# Check if there are any staged changes before committing
if $GIT_CMD diff --staged --quiet; then
    echo "No changes detected in tracked config files to commit."
else
    echo "Committing staged changes..."
    # Use a consistent commit message (can be changed if desired)
    $GIT_CMD commit -m "Update config files (VSCode, Zsh Custom)"

    echo "Pushing changes to remote..."
    # Push the commit to the 'main' branch on 'origin'
    $GIT_CMD push -u origin main
fi

echo "Configuration update process finished."