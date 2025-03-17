#!/usr/bin/env bash

# Optionally accept a -f flag to force overwrite.
force_flag=""
if [ "$1" = "-f" ]; then
    force_flag="-f"
fi

# Use readlink to get the absolute path of this script
SCRIPT_PATH="$(dirname $(readlink -f "$0"))"

# Define the source configuration
SOURCE_CONFIG="$SCRIPT_PATH/tmux.conf"

# Define the destination for the Neovim configuration symlink.
DEST_CONFIG="$HOME/.config/tmux/tmux.conf"

# Call the link-cfg.sh script (located at the repository root) with the appropriate arguments.
"$SCRIPT_PATH/../link-cfg.sh" $force_flag "$SOURCE_CONFIG" "$DEST_CONFIG"

