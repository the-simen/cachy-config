set -gx PATH /usr/bin $PATH

if status is-interactive; and not set -q NVIM
    if set -q TMUX
        fastfetch --config ~/.config/fastfetch/tmux.jsonc
    else
        fastfetch
    end
end

if status is-interactive
    set fish_greeting

    if set -q TMUX
        # Используем tmux-окружение как флаг
        if not tmux show-environment -g TMUX_CONF_LOADED >/dev/null 2>&1
            tmux source-file ~/.tmux.conf
            tmux set-environment -g TMUX_CONF_LOADED 1
        end
    end
end

if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
end
