#!/usr/bin/env bash

branch=$(git -C "$1" branch --show-current 2>/dev/null)

if [ -n "$branch" ]; then
    printf '%s' \
        '#[fg=#{E:@t-green},bg=#{E:@surf}]#[fg=#{E:@t-white},bg=#{E:@t-green}] 󰘬 '"$branch"' #[fg=#{E:@t-green},bg=#{E:@surf}] '
fi
