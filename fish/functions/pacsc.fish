function pacsc
    for d in /var/cache/pacman/pkg/download-*
        test -d $d; and sudo rm -rf $d
    end
    sudo pacman -Sc
end
