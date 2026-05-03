function hry
    set cmd (history | fzf)
    if test -n "$cmd"
        commandline --replace $cmd
    end
end
