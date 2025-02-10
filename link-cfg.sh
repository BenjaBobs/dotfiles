#!/usr/bin/env bash

# Check for the -f (force) flag.
force=false
if [ "$1" = "-f" ]; then
    force=true
    shift  # Remove the flag so that $1 and $2 become source and destination.
fi

# Require exactly two arguments: the source and destination paths.
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [-f] <source_path> <destination_path>"
    exit 1
fi

source_path="$1"
dest="$2"

# Check if the source path exists (either a file, directory, or symlink).
if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
    echo "Error: Source path '$source_path' does not exist."
    exit 1
fi

# Ensure the parent directory of the destination exists.
dest_dir=$(dirname "$dest")
mkdir -p "$dest_dir"

# Check if the destination already exists.
if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$force" = true ]; then
        # Force mode: remove without prompting.
        rm -rf "$dest"
    else
        # Prompt the user before overwriting.
        echo "Destination '$dest' already exists. Overwrite? [y/N]"
        read -r answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "Aborted."
            exit 1
        fi
        rm -rf "$dest"
    fi
fi

# Create the symbolic link.
ln -s "$source_path" "$dest"

echo "Symlink created: $source_path -> $dest"
