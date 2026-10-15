#!/usr/bin/env bash
# Opens Config Manager in kitty. The window closes on clean quit;
# on script failure it stays open with a shell for inspection.

set -e

kitty --title 'Config Manager' bash -lc \
  '$HOME/.config/scripts/config-manager.sh; rc=$?; [ "$rc" -ne 0 ] && exec bash' &
