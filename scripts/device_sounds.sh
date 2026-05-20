#!/usr/bin/env bash

CONNECT_SOUND="/usr/share/sounds/freedesktop/stereo/device-added.oga"
DISCONNECT_SOUND="/usr/share/sounds/freedesktop/stereo/device-removed.oga"

LOCK="/tmp/device-sound.lock"
COOLDOWN=2

play() {
    pw-play "$1" >/dev/null 2>&1 &
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
