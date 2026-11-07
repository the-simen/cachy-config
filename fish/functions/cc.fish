function cc
    set -l std c11
    set -l opt -O0
    set -l args

    for arg in $argv
        switch $arg
            case '-std=*'
                set std (string replace -- '-std=' '' $arg)
            case '-O*'
                set opt $arg
            case '*'
                set -a args $arg
        end
    end

    gcc -std=$std $opt -Wall -Wextra -Wpedantic $args -o (path change-extension "" $args[1])
end
