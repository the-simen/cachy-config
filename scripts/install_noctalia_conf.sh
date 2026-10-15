#!/bin/bash
# Copies a repo Noctalia config over the live one.
# The previous live config is kept as a timestamped backup next to it.

CONFIG="$HOME/.local/state/noctalia/settings.toml"
EXTERNAL_CONFIG=$(realpath "$1")

if [ -f "$CONFIG" ]; then
    BACKUP="$CONFIG.backup_$(date +%Y-%m-%d_%H-%M-%S)"
    cp -p "$CONFIG" "$BACKUP"
    echo "Previous live config backed up to: $BACKUP"
fi

rm -f "$CONFIG"

cp "$EXTERNAL_CONFIG" "$CONFIG"
