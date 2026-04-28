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

# --- launch ghostty ---
if [[ -n "$CMD" ]]; then
  ghostty --title="$TITLE" -e bash -c "$CMD; exec bash" &
else
  ghostty --title="$TITLE" &
fi
