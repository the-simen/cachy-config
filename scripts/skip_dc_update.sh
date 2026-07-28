#!/usr/bin/env bash

set -euo pipefail

SETTINGS="$HOME/.config/discord/settings.json"

mkdir -p "$(dirname "$SETTINGS")"

if [[ ! -f "$SETTINGS" ]]; then
    echo '{}' > "$SETTINGS"
fi

tmp="$(mktemp)"

jq '.SKIP_HOST_UPDATE = true' "$SETTINGS" > "$tmp"

mv "$tmp" "$SETTINGS"

echo "SKIP_HOST_UPDATE = true"
