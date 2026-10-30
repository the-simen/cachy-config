
#!/usr/bin/env bash

# Usage: ssh-title.sh PANE_PID

root_pid="$1"

declare -A visited
queue=("$root_pid")
ssh_pid=""

# Breadth-first search: prefer the outermost SSH process.
while ((${#queue[@]})); do
    pid="${queue[0]}"
    queue=("${queue[@]:1}")

    [[ -n "${visited[$pid]:-}" ]] && continue
    visited[$pid]=1

    [[ -r "/proc/$pid/comm" ]] || continue

    comm=$(<"/proc/$pid/comm")

    if [[ "$comm" == ssh ]]; then
        ssh_pid="$pid"
        break
    fi

    for child in $(pgrep -P "$pid" 2>/dev/null); do
        queue+=("$child")
    done
done

# No SSH process: let tmux display the normal window name.
[[ -n "$ssh_pid" ]] || exit 0

# Read the actual argument vector without losing spaces.
mapfile -d '' -t argv < "/proc/$ssh_pid/cmdline"

((${#argv[@]})) || exit 0

ssh_args=()
destination=""

# Parse OpenSSH arguments up to the destination.
i=1
while ((i < ${#argv[@]})); do
    arg="${argv[$i]}"

    if [[ "$arg" == "--" ]]; then
        ((i++))
        destination="${argv[$i]:-}"
        break
    fi

    if [[ "$arg" == -* ]]; then
        case "$arg" in
            -4|-6|-A|-a|-C|-f|-G|-g|-K|-k|-M|-N|-n|-q|-s|-T|-t|-V|-v|-X|-Y)
                ssh_args+=("$arg")
                ;;
            -B|-b|-c|-D|-E|-e|-F|-I|-i|-J|-L|-l|-m|-O|-o|-P|-p|-Q|-R|-S|-W|-w)
                ssh_args+=("$arg")
                ((i++))
                [[ $i -lt ${#argv[@]} ]] && ssh_args+=("${argv[$i]}")
                ;;
            -*[!a-zA-Z0-9]*)
                # Unknown option: don't guess its argument structure.
                exit 0
                ;;
            *)
                # Combined or attached options are preserved.
                ssh_args+=("$arg")
                ;;
        esac
    else
        destination="$arg"
        break
    fi

    ((i++))
done

[[ -n "$destination" ]] || exit 0

# Resolve SSH aliases, configured usernames and actual hostnames.
config=$(ssh -G "${ssh_args[@]}" "$destination" 2>/dev/null) || exit 0

remote_host=$(awk '$1 == "hostname" {print $2; exit}' <<< "$config")
remote_user=$(awk '$1 == "user" {print $2; exit}' <<< "$config")

[[ -n "$remote_host" && -n "$remote_user" ]] || exit 0

printf '%s@%s' "$remote_user" "$remote_host"
