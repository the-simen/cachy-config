#!/usr/bin/env bash

# gamemode.sh — niri-часть game mode: снимает прозрачность, blur,
# тени и анимации. Всё остальное (suspend процессов, power profile)
# делает плагин noctalia.
#
#   gamemode.sh --on       включить
#   gamemode.sh --off      выключить
#   gamemode.sh --toggle   переключить (для кнопок/виджетов)
#
# Флаги обязательны: без них скрипт ничего не делает и выходит с 2.
# Состояние хранится в $XDG_RUNTIME_DIR, поэтому --toggle знает,
# что делать, а --on/--off идемпотентны.
#
# Для gamemode.ini:
#   [custom]
#   start=/home/thesimen/.config/scripts/gamemode.sh --on
#   end=/home/thesimen/.config/scripts/gamemode.sh --off
#
# Файл game-mode.kdl включён последним в niri/config.kdl, поэтому
# правила ниже перекрывают opacity/blur/shadow из cfg/rules.kdl и
# noctalia.kdl, а animations.kdl перекрывает animations { slowdown }.
#
# Конфиг перезагружается по ЯВНОМУ пути --path, а не «текущему».
# Иначе niri переключается на файл, который перед этим подсунул
# сторонний плагин (detluck/performance-plus грузит свой
# niri-perf.kdl через load-config-file --path), и после его удаления
# reload без пути читает уже несуществующий файл — niri перестаёт
# видеть конфиг целиком.
#
# Exit: 0 — ok, 1 — niri не принял конфиг, 2 — неверный вызов.

set -uo pipefail

CONFIG="$HOME/.config/niri/game-mode.kdl"
ROOT="$HOME/.config/niri/config.kdl"
STATE="${XDG_RUNTIME_DIR}/gamemode.niri"
ACTIVE_TOML="$HOME/.config/noctalia/gamemode-active.toml"
LAYOUT_FLAG="$HOME/.config/noctalia/gamemode.layout"
INPUT_FILE="$HOME/.config/niri/cfg/input.kdl"

LAYOUT_DEFAULT='grp:win_space_toggle'
LAYOUT_SWAPCAPS='ctrl:swapcaps,grp:lctrl_toggle'

# Читает текущее значение options из input.kdl.
current_layout() {
    grep -oP 'options "\K[^"]+' "$INPUT_FILE" 2>/dev/null || true
}

usage() {
    echo "usage: ${0##*/} --on | --off | --toggle" >&2
}

# Пишет (или очищает) game-mode.kdl и перезагружает конфиг niri.
# flock защищает от гонки с плагином performance-plus, который тоже
# делает load-config-file — без этого они могут перебить правила
# друг друга (блюр пропадает, но тут же возвращается).
apply() {
    local LOCKFILE="${XDG_RUNTIME_DIR}/gamemode.lock"
    exec 9>"$LOCKFILE"
    flock 9

    if [[ "$1" == "on" ]]; then
        cat > "$CONFIG" <<'EOF'
window-rule {
    opacity 1.0
    background-effect {
        blur false
    }
}

layer-rule {
  match namespace="^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$"
  background-effect {
    xray false
    blur false
  }
}
EOF
        touch "$STATE"

        # Помечаем, что game mode активен (для noctalia/ shell-анимаций).
        mkdir -p "$HOME/.config/noctalia"
        cat > "$ACTIVE_TOML" <<'EOF'
[shell.animation]
enabled = false
EOF

        # Вызываем change_layout --on только если раскладка ещё не DEFAULT.
        # Если вызывали — ставим флаг, чтобы --off знал, что откатывать.
        if [[ "$(current_layout)" != "$LAYOUT_DEFAULT" ]]; then
            "$HOME/.config/scripts/change_layout.sh" --on
            echo "1" > "$LAYOUT_FLAG"
        else
            rm -f "$LAYOUT_FLAG"
        fi
    else
        # Очищаем game-mode.kdl в любом случае при --off.
        : > "$CONFIG"
        rm -f "$STATE"

        # Удаляем toml.
        if [[ -f "$ACTIVE_TOML" ]]; then
            rm -f "$ACTIVE_TOML"
        fi

        # Вызываем change_layout --off ТОЛЬКО если мы сами его вызывали на --on
        # (флаг-файл существует). Если флага нет — пользователь сам ставил DEFAULT,
        # не трогаем его выбор.
        if [[ -f "$LAYOUT_FLAG" ]]; then
            rm -f "$LAYOUT_FLAG"
            "$HOME/.config/scripts/change_layout.sh" --off
        fi
    fi

    if ! niri msg action load-config-file --path "$ROOT"; then
        echo "gamemode.sh: niri rejected $ROOT" >&2
        return 1
    fi

    # config-reload нужен обязательно: иначе noctalia не подхватит
    # gamemode-active.toml и shell-animation останутся включёнными.
    if command -v noctalia >/dev/null 2>&1; then
        timeout 15 noctalia msg config-reload >/dev/null 2>&1 \
            || echo "gamemode.sh: noctalia config-reload failed" >&2
    fi
}

ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --on|--off|--toggle)
            [[ -n "$ACTION" ]] && { usage; exit 2; }
            ACTION="${1#--}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "${0##*/}: unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
    shift
done

case "$ACTION" in
    on)     apply on ;;
    off)    apply off ;;
    toggle) [[ -f "$STATE" ]] && apply off || apply on ;;
    *)
        usage
        exit 2
        ;;
esac
