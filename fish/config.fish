set -gx PATH /usr/bin $PATH

function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

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

function fish_prompt
  set_color cyan; echo (pwd)
  set_color green; echo '> '
end


starship init fish | source
enable_transience
