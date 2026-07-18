#!/usr/bin/env bash

set -euo pipefail

SETTINGS="$HOME/.config/discord/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
    echo "Файл не найден: $SETTINGS"
    exit 1
fi

tmp="$(mktemp)"

jq '.SKIP_HOST_UPDATE = true' "$SETTINGS" > "$tmp"

mv "$tmp" "$SETTINGS"

echo "SKIP_HOST_UPDATE = true"
