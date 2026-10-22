#!/usr/bin/env bash

set -uo pipefail

FILE="$HOME/.config/niri/cfg/input.kdl"

A='grp:win_space_toggle'
B='ctrl:swapcaps,grp:lctrl_toggle'

current=$(grep -oP 'options "\K[^"]+' "$FILE")

# --on / --off принудительно задают раскладку,
# без аргументов скрипт переключает её (старое поведение).
ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --on)
            ACTION="on"
            ;;
        --off)
            ACTION="off"
            ;;
        -h|--help)
            echo "usage: ${0##*/} [--on | --off]" >&2
            exit 0
            ;;
        *)
            echo "${0##*/}: unknown argument: $1" >&2
            echo "usage: ${0##*/} [--on | --off]" >&2
            exit 2
            ;;
    esac
    shift
done

set_layout() {
    local new="$1"
    local label="$2"
    sed -i "s/options \".*\"/options \"$new\"/" "$FILE"
    notify-send -u low -t 1500 "Layout" "$label"
}

case "$ACTION" in
    on)
        set_layout "$A" "Layout switched to DEFAULT"
        ;;
    off)
        set_layout "$B" "Layout switched to SWAPCAPS"
        ;;
    *)
        if [[ "$current" == "$A" ]]; then
            set_layout "$B" "Layout switched to SWAPCAPS"
        else
            set_layout "$A" "Layout switched to DEFAULT"
        fi
        ;;
esac
