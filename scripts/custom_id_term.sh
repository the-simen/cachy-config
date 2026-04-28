#!/usr/bin/env bash

set -e

APP_ID=""
CMD=""

# --- args parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id)
      APP_ID="$2"
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
if [[ -z "$APP_ID" ]]; then
  APP_ID="floating-term-$$"
fi

TITLE="$APP_ID"

# --- launch ghostty ---
if [[ -n "$CMD" ]]; then
  ghostty --title="$TITLE" -e bash -c "$CMD; exec bash" &
else
  ghostty --title="$TITLE" &
fi

# --- wait for window (robust) ---
FOUND=0
for i in {1..60}; do
  sleep 0.05
  if niri msg windows | grep -q "$TITLE"; then
    FOUND=1
    break
  fi
done

if [[ "$FOUND" -ne 1 ]]; then
  echo "Error: window not detected"
  exit 1
fi
