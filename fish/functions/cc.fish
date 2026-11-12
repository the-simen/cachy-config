function cc
    set -l std c11
    set -l opt -O0
    set -l args

    for arg in $argv
        switch $arg
            case '-h' '--help'
                echo 'Usage: cc [options] <file.c>'
                echo ''
                echo 'Options:'
                echo '  -std=<standard>  C standard (default: c11)'
                echo '  -O<level>        Optimization level (default: -O0)'
                echo '  -h, --help       Show this help message'
                echo ''
                echo 'Compiles a C source file with gcc.'
                return 0
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
