#!/usr/bin/env bash

FILE="$HOME/.config/niri/cfg/input.kdl"

A='grp:win_space_toggle'
B='ctrl:swapcaps,grp:lctrl_toggle'

current=$(grep -oP 'options "\K[^"]+' "$FILE")

if [[ "$current" == "$A" ]]; then
    new="$B"
    notify-send -u low -t 1500 \
      "Layout" \
      "Layout switched to SWAPCAPS"
else
    new="$A"
    notify-send -u low -t 1500 \
      "Layout" \
      "Layout switched to DEFAULT"
fi

sed -i "s/options \".*\"/options \"$new\"/" "$FILE"
