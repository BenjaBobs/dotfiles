#!/usr/bin/env bash

# Check for the -f (force) flag
force=false
if [ "$1" = "-f" ]; then
    force=true
fi

dest="$HOME/.config/nvim"

# Ensure ~/.config directory exists
mkdir -p "$HOME/.config"

# Check if destination already exists
if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$force" = true ]; then
        # Force mode: remove without prompting
        rm -rf "$dest"
    else
        # Prompt the user before overwriting
        echo "$dest already exists. Overwrite? [y/N]"
        read -r answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "Aborted."
            exit 1
        fi
        rm -rf "$dest"
    fi
fi

# Create the symlink
ln -s "$(pwd)/config" "$dest"

echo "Symlink created: $dest -> $(pwd)/config"

