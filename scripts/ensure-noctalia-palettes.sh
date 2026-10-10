#!/usr/bin/env bash
# Восстанавливает генерируемые Noctalia-палитры из tracked *-default снапшотов,
# если сгенерированных файлов нет (свежий клон, до первого `templates-apply`).
# Сами сгенерированные файлы в гите не отслеживаются (см. .gitignore),
# поэтому смена темы больше не пачкает `git status`.
#
# Использование:
#   ./scripts/ensure-noctalia-palettes.sh
set -u

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

# пары "default(трекается) сгенерированный(игнорируется)"
pairs=(
  "ghostty/themes/noctalia-default ghostty/themes/noctalia"
  "kitty/themes/noctalia-default.conf kitty/themes/noctalia.conf"
  "tmux/themes/noctalia-default.conf tmux/themes/noctalia-palette.conf"
  "superfile/theme/noctalia-default.toml superfile/theme/noctalia.toml"
  "mpv/script-opts/modernz-default.conf mpv/script-opts/modernz.conf"
  "niri/noctalia-default.kdl niri/noctalia.kdl"
  "btop/themes/noctalia-default.theme btop/themes/noctalia.theme"
  "umbriel/noctalia-default.toml umbriel/noctalia.toml"
)

restored=0
for pair in "${pairs[@]}"; do
  src="$cfg/${pair%% *}"
  dst="$cfg/${pair##* }"
  if [ ! -e "$dst" ] && [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    echo "restored: $dst (from $src)"
    restored=$((restored + 1))
  fi
done

echo "done, restored: $restored"
