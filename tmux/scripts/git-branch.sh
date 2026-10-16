#!/usr/bin/env bash

branch=$(git -C "$1" branch --show-current 2>/dev/null)

if [ -n "$branch" ]; then
    printf '%s' \
        '#[fg=#{E:@sep-color},bg=#{E:@t-green}]#[fg=#{E:@surf},bg=#{E:@t-green}] 󰘬 '"$branch"' #[fg=#{E:@sep-color},bg=#{E:@t-green}]'
fi
