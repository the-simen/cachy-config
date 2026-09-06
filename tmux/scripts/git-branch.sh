#!/usr/bin/env bash

branch=$(git -C "$1" branch --show-current 2>/dev/null)

if [ -n "$branch" ]; then
    printf '%s' \
        '#[fg=#{E:@surf-br},bg=#{E:@t-green}]#[fg=black,bg=#{E:@t-green}] 󰘬 '"$branch"' #[fg=#{E:@surf-br},bg=#{E:@t-green}]#{E:@segment-separator}'
fi
