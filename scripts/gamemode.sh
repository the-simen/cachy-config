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

usage() {
    echo "usage: ${0##*/} --on | --off | --toggle" >&2
}

# Пишет (или очищает) game-mode.kdl и перезагружает конфиг niri.
apply() {
    if [[ "$1" == "on" ]]; then
        cat > "$CONFIG" <<'EOF'
animations {
    off
}

window-rule {
    opacity 1.0

    background-effect {
        xray false
        blur false
        noise 0
        saturation 1
    }

    shadow {
        off
    }
}
EOF
        touch "$STATE"
    else
        : > "$CONFIG"
        rm -f "$STATE"
    fi

    if ! niri msg action load-config-file --path "$ROOT"; then
        echo "gamemode.sh: niri rejected $ROOT" >&2
        return 1
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
