#!/usr/bin/env bash
set -e

PLUGIN_DIR="$HOME/.tmux/plugins/tmux-powerkit"
TARGET="$PLUGIN_DIR/src/themes"
SOURCE="$HOME/.config/tmux/themes"

# если уже правильный симлинк — ничего не делаем
if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
  exit 0
fi

# если что-то есть (папка/битый линк) — удаляем
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  rm -rf "$TARGET"
fi

# создаём симлинк
ln -s "$SOURCE" "$TARGET"
