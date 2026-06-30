#!/usr/bin/env bash

set -e

DIR="$HOME/.local/share/tmux/resurrect"

mkdir -p "$DIR"

while true; do
  FILE=$(ls -t "$DIR"/*.txt 2>/dev/null | \
    fzf --prompt="resurrect > " \
        --header="Select session to reload")

  [ -z "$FILE" ] && exit 0

  ACTION=$(printf "restore\ndelete\nrename\nback" | \
    fzf --prompt="action > ")

  case "$ACTION" in

    restore)
      ln -sf "$FILE" "$DIR/last"
      ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh
      break
      ;;

    delete)
      rm -f "$FILE"
      ;;

    rename)
      echo "Enter new name:"
      read -r NAME
      NEW="$DIR/${NAME}.txt"
      mv "$FILE" "$NEW"
      ;;

    back)
      continue
      ;;

    *)
      exit 0
      ;;
  esac
done
