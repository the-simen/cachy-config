function wait-noctalia
    set service quickshell.service
    set delay 0

    # если последний аргумент число — считаем его delay
    if test (count $argv) -gt 0
        set last $argv[-1]

        if string match -qr '^[0-9]+(\.[0-9]+)?$' $last
            set delay $last
            set argv $argv[1..-2]
        end
    end

    while not systemctl --user is-active $service >/dev/null
        sleep 0.2
    end

    if test $delay -gt 0
        sleep $delay
    end

    command $argv
end
