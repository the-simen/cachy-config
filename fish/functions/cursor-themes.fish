function cursor-themes
    find ~/.icons /usr/share/icons -type d -name cursors 2>/dev/null \
    | sed 's|/cursors||' \
    | xargs -n1 basename \
    | sort -u
end
