#!/usr/bin/env bash

FILE="$HOME/.config/niri/cfg/input.kdl"

A='grp:win_space_toggle'
B='ctrl:swapcaps,grp:lctrl_toggle'

current=$(grep -oP 'options "\K[^"]+' "$FILE")

if [[ "$current" == "$A" ]]; then
    new="$B"
    notify-send -u low -t 1500 \
      "Layout" \
      "<b>Layout switched:</b> <span foreground='#FF9800'>SWAPCAPS</span>"
else
    new="$A"
    notify-send -u low -t 1500 \
      "Layout" \
      "<b>Layout switched:</b> <span foreground='#4CAF50'>DEFAULT</span>"
fi

sed -i "s/options \".*\"/options \"$new\"/" "$FILE"
