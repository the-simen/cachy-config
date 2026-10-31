#!/usr/bin/env bash

path="$1"

# Должны быть внутри git-рабочего дерева
git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Количество несохранённых изменений
changes=$(git -C "$path" status --porcelain 2>/dev/null) || exit 0
count=$(printf '%s\n' "$changes" | grep -c '.')

# Расхождение с upstream (опережение / отставание)
ahead=0
behind=0
if git -C "$path" rev-parse --abbrev-ref --symbolic-full-name @{upstream} >/dev/null 2>&1; then
    ahead=$(git -C "$path" rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
    behind=$(git -C "$path" rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
fi

# Если нет ни изменений, ни расхождения — сегмент не рисуем
[ "$count" -eq 0 ] && [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ] && exit 0

# Собираем части сегмента
parts=""
[ "$count" -gt 0 ] && parts="${parts}  ±${count}"
[ "$ahead" -gt 0 ] && parts="${parts} ↑${ahead}"
[ "$behind" -gt 0 ] && parts="${parts} ↓${behind}"

printf '%s' \
    '#[fg=#{E:@sep-color},bg=#{E:@t-yellow}]#[fg=#{E:@surf},bg=#{E:@t-yellow}]'"${parts}"' #[fg=#{E:@sep-color},bg=#{E:@t-yellow}]'
