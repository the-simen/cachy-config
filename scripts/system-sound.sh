#!/usr/bin/env bash

SOUND_DIR="/usr/share/sounds/ocean/stereo"
VOLUME=70
WAIT=false

[[ "$2" =~ ^[0-9]+$ ]] && VOLUME="$2"
[[ "$2" == "--wait" || "$3" == "--wait" ]] && WAIT=true

SOUND="$SOUND_DIR/$1.oga"

if $WAIT; then
    paplay --volume=$((65536 * VOLUME / 100)) "$SOUND" >/dev/null 2>&1
else
    paplay --volume=$((65536 * VOLUME / 100)) "$SOUND" >/dev/null 2>&1 &
fi
