#!/usr/bin/env bash

CONFIG="$HOME/.config/niri/game-mode.kdl"
NOCTALIA_GM_ACTIVE="$HOME/.config/noctalia/gamemode.toml"
NOCTALIA_GM_DISABLED="$HOME/.config/noctalia/gamemode.toml.disabled"
STATE="${XDG_RUNTIME_DIR}/game-mode"

if [[ -f "$STATE" && -f "$NOCTALIA_GM_ACTIVE" ]]; then
    cat > "$CONFIG" <<'EOF'
EOF

    mv "$NOCTALIA_GM_ACTIVE" "$NOCTALIA_GM_DISABLED"

    noctalia msg desktop-widgets-show
    rm -f "$STATE"
    notify-send "Game Mode" "OFF"
else
    cat > "$CONFIG" <<'EOF'
window-rule {
    opacity 1.0
    background-effect {
        blur false
    }
}
EOF

    mv "$NOCTALIA_GM_DISABLED" "$NOCTALIA_GM_ACTIVE"

    noctalia msg desktop-widgets-hide
    touch "$STATE"
    notify-send "Game Mode" "ON"
fi

noctalia msg config-reload
niri msg action reload-config
