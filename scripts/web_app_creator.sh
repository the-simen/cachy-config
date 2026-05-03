#!/usr/bin/env bash
set -e

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/webapps"

mkdir -p "$APP_DIR"
mkdir -p "$ICON_DIR"

# ---------------- ENV ----------------

use_tui=true
command -v gum >/dev/null || use_tui=false

# ---------------- CLEAN EXIT ----------------

cleanup() {
  exit 0
}

trap cleanup EXIT INT TERM

pause() {
  read -n 1 -s -r -p "Press any key to close..."
  kill -9 $PPID
  echo
  cleanup
}

# ---------------- UI ----------------

header() {
  if $use_tui; then
    local width
    width=$(tput cols)

    # компенсируем border + padding
    local inner_width=$((width - 2))

    gum style \
      --border rounded \
      --width "$inner_width" \
      --align center \
      --padding "1 2" \
      --foreground 212 \
"WEB APP CREATOR"
  else
    echo "=== Web App Creator ==="
  fi
}

die() {
  local msg="$1"

  if $use_tui; then
    gum style \
      --border double \
      --foreground 1 \
      --padding "1 2" \
"ERROR: $msg"
  else
    echo "ERROR: $msg"
  fi

  echo ""
  pause
}

input() {
  local prompt="$1"

  if $use_tui; then
    gum input --placeholder "$prompt"
  else
    read -rp "$prompt: " value
    echo "$value"
  fi
}

choose() {
  local prompt="$1"
  shift
  local options=("$@")

  if $use_tui; then
    gum choose "${options[@]}"
  else
    echo "$prompt"
    select opt in "${options[@]}"; do
      echo "$opt"
      break
    done
  fi
}

msg() {
  if $use_tui; then
    gum style --foreground 212 "$1"
  else
    echo "$1"
  fi
}

# ---------------- START ----------------

clear
header

# ---------------- INPUT ----------------

NAME=$(input "App name")
URL=$(input "URL")
ICON_INPUT=$(input "Icon (name or URL)")

BROWSER=$(choose "Browser" chromium brave zen firefox)

FILE_NAME=$(echo "$NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

# ---------------- VALIDATION ----------------

msg "Validating URL..."

if ! curl -s --head --fail "$URL" >/dev/null; then
  die "URL is not reachable"
fi

# ---------------- ICON ----------------

if [[ "$ICON_INPUT" =~ ^https?:// ]]; then
  ICON_PATH="$ICON_DIR/${FILE_NAME}.png"

  CONTENT_TYPE=$(curl -sI "$ICON_INPUT" | grep -i content-type | awk '{print $2}' | tr -d '\r')

  if [[ "$CONTENT_TYPE" != image/* ]]; then
    ICON="web-browser"
  else
    msg "Downloading icon..."
    if curl -L --fail "$ICON_INPUT" -o "$ICON_PATH"; then
      ICON="$ICON_PATH"
    else
      ICON="web-browser"
    fi
  fi
else
  ICON="$ICON_INPUT"
fi

# ---------------- BROWSER ----------------

case "$BROWSER" in
  chromium)
    EXEC="chromium --app=$URL"
    ;;
  brave)
    EXEC="brave-browser --app=$URL"
    ;;
  zen)
    EXEC="zen --new-window $URL"
    ;;
  firefox)
    EXEC="firefox --new-window $URL"
    ;;
  *)
    EXEC="chromium --app=$URL"
    ;;
esac

# ---------------- CREATE DESKTOP FILE ----------------

DESKTOP_FILE="$APP_DIR/${FILE_NAME}.desktop"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=$NAME
Exec=$EXEC
Icon=$ICON
Type=Application
Categories=Network;
StartupNotify=true
EOF

# ---------------- DONE ----------------

if $use_tui; then
  gum style \
    --border normal \
    --padding "1 2" \
    --foreground 2 \
"✔ Created:
$DESKTOP_FILE"

  pause
else
  echo "Created: $DESKTOP_FILE"
fi
