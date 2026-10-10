#!/usr/bin/env bash

CONNECT_SOUND="device-added"
DISCONNECT_SOUND="device-removed"

LOCK="/tmp/device-sound.lock"
COOLDOWN=2

play() {
    $HOME/.config/scripts/system-sound.sh "$1"
}

trigger() {
    now=$(date +%s)

    # если lock свежий — игнор
    if [[ -f "$LOCK" ]]; then
        last=$(cat "$LOCK")
        diff=$((now - last))

        if (( diff < COOLDOWN )); then
            return
        fi
    fi

    echo "$now" > "$LOCK"

    if [[ "$1" == "add" ]]; then
        play "$CONNECT_SOUND"
    else
        play "$DISCONNECT_SOUND"
    fi
}

udevadm monitor --udev --subsystem-match=input --subsystem-match=usb | while read -r line; do

    if [[ "$line" == *"add"* ]]; then
        trigger "add"
    elif [[ "$line" == *"remove"* ]]; then
        trigger "remove"
    fi

done
