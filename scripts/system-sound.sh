#!/usr/bin/env bash

SOUND_DIR="/usr/share/sounds/ocean/stereo"
VOLUME="${2:-70}"

SOUND="$SOUND_DIR/$1.oga"

paplay --volume=$((65536 * VOLUME / 100)) "$SOUND" >/dev/null 2>&1 &
