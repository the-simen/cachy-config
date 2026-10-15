#!/usr/bin/env bash

set -e

TITLE=""
CMD=""

# --- args parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      TITLE="$2"
      shift 2
      ;;
    --cmd)
      CMD="$2"
      shift 2
      ;;
    --)
      shift
      CMD="$*"
      break
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
done

# fallback
if [[ -z "$TITLE" ]]; then
  TITLE="floating-term-$$"
fi

TITLE="$TITLE"

# --- launch kitty ---
if [[ -n "$CMD" ]]; then
  kitty --title="$TITLE" bash -lc "$CMD; exec bash" &
else
  kitty --title="$TITLE" &
fi
