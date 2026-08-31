function ssh --wraps ssh --description "kitty-aware ssh"
    # Работаем только внутри kitty, иначе обычный ssh
    if set -q KITTY_WINDOW_ID; or test "$TERM" = "xterm-kitty"
        kitty +kitten ssh $argv
    else
        command ssh $argv
    end
end
