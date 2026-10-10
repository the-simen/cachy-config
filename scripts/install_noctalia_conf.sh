#!/bin/bash

CONFIG="$HOME/.local/state/noctalia/settings.toml"
EXTERNAL_CONFIG=$(realpath "$1")

rm -f "$CONFIG"

cp "$EXTERNAL_CONFIG" "$CONFIG"
