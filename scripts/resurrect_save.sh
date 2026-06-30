#!/usr/bin/env bash

DIR="$HOME/.local/share/tmux/resurrect"

mkdir -p "$DIR"

# 1. спрашиваем имя
NAME="$(fzf --prompt="snapshot name > " --print-query | sed -n '1p')" || exit 0

# если пусто — fallback
[ -z "$NAME" ] && NAME="manual"

# sanitize
NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

# 2. сохраняем через resurrect
~/.tmux/plugins/tmux-resurrect/scripts/save.sh

# 3. берём последний файл
LATEST=$(ls -t "$DIR"/tmux_resurrect_*.txt | head -n 1)

# 4. переименовываем
mv "$LATEST" "$DIR/${NAME}.txt"

echo "Saved as ${NAME}.txt"
