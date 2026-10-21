#!/bin/sh
set -eu

TMP_ROOT="/tmp/nono-tmp"
# Run by the trusted launcher before nono prepares capabilities.
if [ -L "$TMP_ROOT" ]; then
    echo "Refusing a symlink at $TMP_ROOT" >&2
    exit 1
fi
mkdir -p "$TMP_ROOT"
if [ "$(stat -c %u -- "$TMP_ROOT")" != "$(id -u)" ]; then
    echo "Temporary root is not owned by this user" >&2
    exit 1
fi
chmod 700 "$TMP_ROOT"
mktemp -d "$TMP_ROOT/session.XXXXXXXXXXXX"
