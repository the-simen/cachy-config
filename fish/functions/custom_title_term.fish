function custom_title_term
    argparse 't/title=' 'c/cmd=' -- $argv
    or return 1

    if not set -q _flag_title
        echo "Missing --title"
        return 1
    end

    if not set -q _flag_cmd
        echo "Missing --cmd"
        return 1
    end

    ~/.config/scripts/custom_title_term.sh \
        --title "$_flag_title" \
        --cmd "$_flag_cmd"
end
