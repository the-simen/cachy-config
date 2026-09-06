#!/usr/bin/env bash

created="$1"
now=$(date +%s)

# session_created приходит в формате epoch
seconds=$((now - created))

days=$((seconds / 86400))
hours=$(((seconds % 86400) / 3600))
minutes=$(((seconds % 3600) / 60))

if (( days > 0 )); then
    printf '%dd %02dh' "$days" "$hours"
elif (( hours > 0 )); then
    printf '%dh %02dm' "$hours" "$minutes"
else
    printf '%dm' "$minutes"
fi
