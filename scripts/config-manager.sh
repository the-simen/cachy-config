#!/usr/bin/env bash
# config-manager — TUI installer/updater for cachy-config (Niri + Noctalia).
#
# Launched from the app menu via open_config_manager.sh.
#   1. Ensures ~/bash-scripts exists (clones it if missing, pulls if present).
#   2. Applies the live Noctalia palette to dialog itself (DIALOGRC).
#   3. Shows repo status inside the main menu (commits, upstream, changes).
#   4. Runs cachyos/install.sh, cachyos/update.sh or applies the repo
#      Noctalia config — with live output.
#
# UI backend: dialog (mouse-clickable) -> gum -> plain bash prompts.
# All dialogs are sized from the current terminal (tput), so the UI
# reflows if the window is resized. Heights are always explicit
# (never 0/autosize) so text can never overflow into scroll-percent mode.

set -uo pipefail

# Byte-exact UTF-8 output must not depend on the caller's locale.
if [[ "${LC_ALL:-}" != *UTF-8 && "${LANG:-}" != *UTF-8 && "${LC_CTYPE:-}" != *UTF-8 ]]; then
    export LC_ALL=C.UTF-8
fi

BS_DIR="$HOME/bash-scripts"
CACHY_DIR="$BS_DIR/cachyos"
CFG_DIR="$HOME/.config"
NVIM_DIR="$HOME/.config/nvim"
BACKTITLE="cachy-config manager"

# ---------------- terminal geometry (adaptive) ----------------

# Sets _W (columns) and _H (rows). Called before every screen.
term_size() {
    _W=$(tput cols 2>/dev/null || echo 80)
    _H=$(tput lines 2>/dev/null || echo 24)
    [ "$_W" -lt 40 ] && _W=40
    [ "$_H" -lt 12 ] && _H=12
}

# Box width for dialogs: terminal width minus margin, clamped.
box_w() {
    term_size
    BW=$((_W - 6))
    [ "$BW" -gt 96 ] && BW=96
    [ "$BW" -lt 40 ] && BW=40
}

hr() { # full-width rule, $1 = char (pure bash: tr mangles multibyte under C locales)
    term_size
    local c="${1:-─}" s
    printf -v s '%*s' "$_W" ''
    echo "${s// /$c}"
}

center() { # $1 = text -> centered line
    term_size
    local text="$1" pad
    pad=$(( (_W - ${#text}) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf '%*s%s\n' "$pad" '' "$text"
}

# ---------------- UI backend ----------------

UI="plain"
DIALOG_VER=""
if [[ -t 0 && -t 2 ]] && [ -x "$CFG_DIR/scripts/hover-menu.sh" ]; then
    UI="hover"
elif command -v dialog &>/dev/null; then
    UI="dialog"
    DIALOG_VER=$(dialog --version 2>&1 | head -1)
elif command -v gum &>/dev/null; then
    UI="gum"
fi

# Theme colors for hover/gum UI (live Noctalia palette, pink fallback).
ACCENT="#ebdbb2"
H_FG="#ffffff"
if [ -f "$CFG_DIR/noctalia/colors.json" ]; then
    ACCENT=$(python3 -c "import json;print(json.load(open('$CFG_DIR/noctalia/colors.json')).get('mPrimary','#ebdbb2'))" 2>/dev/null || echo "#ebdbb2")
    H_FG=$(python3 -c "import json;print(json.load(open('$CFG_DIR/noctalia/colors.json')).get('mOnSurface','#ffffff'))" 2>/dev/null || echo "#ffffff")
fi

# dialog follows the Noctalia palette: regenerate DIALOGRC every launch,
# fall back to the tracked static default when the palette is unavailable.
if [ "$UI" = "dialog" ]; then
    if [ -x "$CFG_DIR/scripts/generate-dialogrc.py" ]; then
        "$CFG_DIR/scripts/generate-dialogrc.py" >/dev/null 2>&1 \
            || [ -f "$CFG_DIR/dialog/noctalia" ] \
            || cp -p "$CFG_DIR/dialog/noctalia-default" "$CFG_DIR/dialog/noctalia" 2>/dev/null
    fi
    [ -f "$CFG_DIR/dialog/noctalia" ] || cp -p "$CFG_DIR/dialog/noctalia-default" "$CFG_DIR/dialog/noctalia" 2>/dev/null
    [ -f "$CFG_DIR/dialog/noctalia" ] && export DIALOGRC="$CFG_DIR/dialog/noctalia"
fi

# ui_msg "title" "text" lines — heights explicit, text kept short by callers.
ui_msg() {
    case "$UI" in
        hover)
            "$CFG_DIR/scripts/hover-menu.sh" --info \
                --title "$1" --prompt "$2" \
                --fg "$H_FG" --accent "$ACCENT" || true
            ;;
        dialog)
            box_w
            local h=$(($3 + 7))
            [ "$h" -gt "$((_H - 2))" ] && h=$((_H - 2))
            dialog --backtitle "$BACKTITLE" --colors --cr-wrap \
                --title " $1 " --msgbox "$2" "$h" "$BW"
            ;;
        gum)
            term_size
            gum style --border rounded --width "$_W" --align center \
                --padding "1 2" --foreground "$ACCENT" "$1"
            echo -e "$2" | sed 's/\\Z[0-9bBuUrRn]//g'
            echo ""
            read -n 1 -s -r -p "Press any key..."
            ;;
        *)
            hr "═"; center "$1"; hr "═"
            echo -e "$2" | sed 's/\\Z[0-9bBuUrRn]//g'
            hr "─"
            read -n 1 -s -r -p "Press any key..."
            ;;
    esac
}

ui_info() { # transient text
    case "$UI" in
        dialog) dialog --backtitle "$BACKTITLE" --infobox "$1" 3 50 ;;
        gum) gum style --foreground "$ACCENT" "$1" ;;
        *) echo "… $1" ;;
    esac
}

ui_yesno() { # title, text, lines -> rc 0 = yes
    case "$UI" in
        hover)
            local yn
            yn=$("$CFG_DIR/scripts/hover-menu.sh" --title "$1" --prompt "$2" \
                --fg "$H_FG" --accent "$ACCENT" --hint "hover / ↑↓jk · click / Enter = Yes" \
                yes "Yes" no "No") || return 1
            [ "$yn" = "yes" ]
            ;;
        dialog)
            box_w
            local h=$(($3 + 7))
            [ "$h" -gt "$((_H - 2))" ] && h=$((_H - 2))
            dialog --backtitle "$BACKTITLE" --colors --cr-wrap \
                --title " $1 " --yes-label "Yes" --no-label "No" \
                --yesno "$2" "$h" "$BW"
            ;;
        gum)
            gum confirm "$2"
            ;;
        *)
            echo -e "$2" | sed 's/\\Z[0-9bBuUrRn]//g'
            local a; read -rp "Yes/No? [y/N] " a
            [[ "$a" =~ ^[Yy]$ ]]
            ;;
    esac
}

# ui_menu "prompt" lines default_tag tag label [tag label ...] -> prints tag
ui_menu() {
    local prompt="$1" lines="$2" _default="$3"
    shift 3
    case "$UI" in
        hover)
            local tags=() labels=() pairs=() init=0 i
            while [ $# -ge 2 ]; do
                tags+=("$1"); labels+=("$2"); pairs+=("$1" "$2"); shift 2
            done
            for i in "${!tags[@]}"; do
                [ "${tags[$i]}" = "$_default" ] && init=$i
            done
            local pick rc
            pick=$("$CFG_DIR/scripts/hover-menu.sh" --title "Config Manager" \
                --prompt "$prompt" --fg "$H_FG" --accent "$ACCENT" \
                --select "$init" "${pairs[@]}")
            rc=$?
            if [ "$rc" -eq 2 ]; then
                UI=dialog  # terminal unsuitable for hover: fall back once
                ui_menu "$prompt" "$lines" "$_default" "${pairs[@]}"
                return $?
            fi
            [ "$rc" -eq 0 ] && echo "$pick"
            return "$rc"
            ;;
        dialog)
            box_w
            local n=$(($# / 2))
            local mh=$((lines + n + 8))
            [ "$mh" -gt "$((_H - 2))" ] && mh=$((_H - 2))
            dialog --clear --backtitle "$BACKTITLE" --colors \
                --title " Config Manager " \
                --hline "↑↓/jk move · Enter/C-j select · click works too" \
                --ok-label "Select" --cancel-label "Quit" \
                --default-item "$_default" \
                --menu "$prompt" "$mh" "$BW" "$n" "$@" 3>&2 2>&1 1>&3
            ;;
        gum)
            local labels=() tags=()
            while [ $# -ge 2 ]; do tags+=("$1"); labels+=("$2"); shift 2; done
            echo "$prompt"
            local picked
            picked=$(gum choose --height 12 "${labels[@]}") || return 1
            local i
            for i in "${!labels[@]}"; do
                [ "${labels[$i]}" = "$picked" ] && { echo "${tags[$i]}"; return 0; }
            done
            return 1
            ;;
        *)
            hr "═"; center "Config Manager"; hr "═"
            echo "$prompt"
            local tags=() i=1
            while [ $# -ge 2 ]; do tags+=("$1"); echo "  $i) $2"; shift 2; i=$((i + 1)); done
            local n; read -rp "Choice [1-$((i - 1))]: " n
            [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -lt "$i" ] && echo "${tags[$((n - 1))]}"
            ;;
    esac
}

# ---------------- git helpers ----------------

repo_commit() { # dir maxlen -> "subject — body…" (one short line, no hash/date)
    local maxlen="${2:-60}" out
    out=$(git -C "$1" log -1 --format="%s%n%b" 2>/dev/null \
        | awk 'NR==1{subj=$0;next} NF{body=(body ? body" " : "")$0} END{print subj (body ? " — "body : "")}') \
        || { echo "—"; return 0; }
    [ -z "$out" ] && { echo "—"; return 0; }
    [ "${#out}" -gt "$maxlen" ] && out="${out:0:maxlen}…"
    echo "$out"
}

repo_dirty() { # dir -> number of changed files
    git -C "$1" status --porcelain 2>/dev/null | wc -l
}

repo_fetch() { # dir -> 0 if fetched, 1 if offline
    timeout 25 git -C "$1" fetch --quiet origin 2>/dev/null
}

repo_behind() { # dir (after fetch) -> "N", "?" or "offline-was"
    git -C "$1" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo "?"
}

ensure_bash_scripts() {
    if [ ! -d "$BS_DIR/.git" ]; then
        ui_info "Cloning bash-scripts..."
        if ! git clone https://github.com/the-simen/bash-scripts.git "$BS_DIR"; then
            ui_msg "Error" "\\Z1Clone failed.\\Zn\nCheck your network and restart." 3
            return 1
        fi
        chmod +x "$CACHY_DIR/install.sh" "$CACHY_DIR/update.sh"
    else
        ui_info "Pulling bash-scripts..."
        if ! timeout 60 git -C "$BS_DIR" pull --ff-only --quiet 2>/dev/null; then
            ui_msg "Warning" "\\Z3Could not update ~/bash-scripts\\Zn (offline or changes?).\nContinuing with the local copy." 3
        fi
    fi
    return 0
}

config_installed() {
    [ -d "$CFG_DIR/.git" ] && git -C "$CFG_DIR" remote get-url origin 2>/dev/null | grep -q cachy-config
}

# ---------------- status block (embedded in menu prompt) ----------------

# Sets STATUS_LINES (count) and STATUS_TEXT. One fetch per call.
build_status() {
    box_w
    # "config  " label is 8 wide + dialog prompt padding: use full width.
    local subj=$((BW - 14))
    [ "$subj" -lt 20 ] && subj=20
    [ "$subj" -gt 70 ] && subj=70

    local online=1
    repo_fetch "$CFG_DIR" || online=0

    local behind
    if [ "$online" -eq 0 ]; then
        behind="offline"
    else
        behind=$(repo_behind "$CFG_DIR")
    fi
    local behind_s dirty dirty_s
    case "$behind" in
        0)       behind_s="\\Z2● up to date\\Zn" ;;
        offline) behind_s="\\Z1● offline, local state\\Zn" ;;
        \?)      behind_s="\\Z3● upstream unknown\\Zn" ;;
        *)       behind_s="\\Z3● $behind behind upstream\\Zn" ;;
    esac
    dirty=$(repo_dirty "$CFG_DIR")
    if [ "$dirty" -eq 0 ]; then
        dirty_s="\\Z2● clean\\Zn"
    else
        dirty_s="\\Z3● $dirty changed\\Zn"
    fi

    STATUS_TEXT="\\Zb\\Z6config\\Zn  $(repo_commit "$CFG_DIR" "$subj")
\\Zb\\Z6nvim\\Zn    $(repo_commit "$NVIM_DIR" "$subj")
\\Zb\\Z6scripts\\Zn $(repo_commit "$BS_DIR" "$subj")

$behind_s   $dirty_s"
    STATUS_LINES=5
}

# ---------------- task runner ----------------

run_task() { # title, cmd...
    local title="$1"
    shift
    clear
    hr "═"; center "◆ $title ◆"; hr "═"
    echo "  started: $(date '+%Y-%m-%d %H:%M:%S')"
    hr "─"
    echo ""
    "$@"
    local rc=$?
    echo ""
    hr "─"
    if [ "$rc" -eq 0 ]; then
        ui_msg "Done ✓" "\\Z2$title finished successfully.\\Zn\n\nIf drivers, shell or services changed, reboot." 4
    else
        ui_msg "Failed ✗" "\\Z1$title exited with code $rc.\\Zn\n\nScroll up to see the error,\nfix it and run again." 5
    fi
    return "$rc"
}

apply_noctalia() {
    if ! ui_yesno "Apply Noctalia config" "Replace the live Noctalia settings\nwith noctalia/config.toml.full?\n\nThe current live file is backed up\nnext to it (*.backup_*).\nThen \\Zbrestart the Noctalia shell\\Zn." 7; then
        return 0
    fi
    clear
    hr "═"; center "◆ Apply Noctalia config ◆"; hr "═"
    "$CFG_DIR/scripts/install_noctalia_conf.sh" "$CFG_DIR/noctalia/config.toml.full"
    local rc=$?
    echo ""
    hr "─"
    if [ "$rc" -eq 0 ]; then
        ui_msg "Done ✓" "\\Z2Live Noctalia config replaced.\\Zn\n\nRestart the Noctalia shell to apply it.\nTheme assets re-render on the next\ntheme switch." 6
    else
        ui_msg "Failed ✗" "install_noctalia_conf.sh failed (code $rc)." 2
    fi
}

# ---------------- commit viewer ----------------

# Submenu first (which repo?), then one scrollable window with full
# subjects + bodies (last 5). dialog has no collapsible tree; this is
# the honest equivalent: one-line summary in the main menu, full text
# here, repo by repo.
show_one_commits() { # dir, label
    local d="$1" label="$2" logfile
    logfile=$(mktemp)
    if [ -d "$d/.git" ]; then
        git -C "$d" log -5 --format="● %h %ad%n  %s%n%b%n" --date=short > "$logfile" 2>/dev/null
    else
        echo "(not a git repo)" > "$logfile"
    fi
    case "$UI" in
        dialog)
            box_w
            local h=$((_H - 4))
            [ "$h" -lt 10 ] && h=10
            dialog --backtitle "$BACKTITLE" --colors \
                --title " Commits: $label " \
                --ok-label "Back" --no-cancel \
                --textbox "$logfile" "$h" "$BW"
            ;;
        *)
            term_size
            echo "━━━ $label ━━━"
            if command -v less &>/dev/null; then
                less -R -S "$logfile"
            else
                cat "$logfile"
                read -n 1 -s -r -p "Press any key..."
            fi
            ;;
    esac
    rm -f "$logfile"
}

show_commits() {
    while true; do
        local pick
        pick=$(ui_menu "Whose commits?" 1 "config" \
            "config"  "cachy-config" \
            "nvim"    "nvim" \
            "scripts" "bash-scripts" \
            "back"    "Back") || return 0
        case "$pick" in
            config)  show_one_commits "$CFG_DIR" "cachy-config" ;;
            nvim)    show_one_commits "$NVIM_DIR" "nvim" ;;
            scripts) show_one_commits "$BS_DIR" "bash-scripts" ;;
            *)       clear; return 0 ;;
        esac
    done
}

# ---------------- export live config to repo ----------------

# Snapshot ~/.local/state/noctalia/settings.toml into the tracked
# noctalia/config.toml.full (the reverse of apply_noctalia).
# Does not commit: review with git diff / Config Manager Commits, then
# commit and push yourself.
export_noctalia() {
    local live="$HOME/.local/state/noctalia/settings.toml"
    local repo="$CFG_DIR/noctalia/config.toml.full"
    if [ ! -f "$live" ]; then
        ui_msg "Note" "Live Noctalia settings not found:\n$live" 3
        return 0
    fi
    if ! ui_yesno "Export Noctalia config" "Copy the LIVE Noctalia settings\ninto the repo snapshot?\n\nlive:  ~/.local/state/noctalia/settings.toml\nrepo:  noctalia/config.toml.full\n\nReview the result with git diff\nbefore committing." 8; then
        return 0
    fi
    clear
    hr "═"; center "◆ Export Noctalia config ◆"; hr "═"
    cp -p "$live" "$repo" || {
        ui_msg "Failed ✗" "Could not copy live settings to repo." 2
        return 1
    }
    if ! python3 -c "import tomllib; tomllib.load(open('$repo','rb'))" 2>/dev/null; then
        ui_msg "Failed ✗" "Exported file is not valid TOML.\nLive settings left untouched." 3
        return 1
    fi
    local stat
    stat=$(git -C "$CFG_DIR" diff --stat -- noctalia/config.toml.full 2>/dev/null | tail -2)
    echo ""
    hr "─"
    ui_msg "Done ✓" "\\Z2Repo snapshot updated from live settings.\\Zn\n\n$stat\n\nReview, commit and push when ready." 7
}

# ---------------- main loop ----------------

ensure_bash_scripts || exit 1

# Double-framed banner, adaptive width, centered. $1..$n = lines.
dbox() {
    term_size
    local w=$((_W - 12))
    [ "$w" -gt 58 ] && w=58
    [ "$w" -lt 28 ] && w=28
    local left=$(( (_W - w - 2) / 2 ))
    [ "$left" -lt 0 ] && left=0
    local pad=""
    printf -v pad '%*s' "$left" ''
    local rule=""
    printf -v rule '%*s' "$w" ''
    rule=${rule// /═}
    echo "${pad}╔${rule}╗"
    local line l g
    for line in "$@"; do
        l=${#line}
        g=$((w - l - 2))
        [ "$g" -lt 0 ] && g=0
        printf '%s║ %s%*s ║\n' "$pad" "$line" "$g" ''
    done
    echo "${pad}╚${rule}╝"
}

while true; do
    clear
    dbox "Config Manager  ·  Niri + Noctalia" \
         "ui: $UI${DIALOG_VER:+ ($DIALOG_VER)}  ·  ${_W:-?}x${_H:-?}" \
         "" \
         "… Checking upstream..."
    build_status

    default_item="update"
    config_installed || default_item="install"
    choice=$(ui_menu "$STATUS_TEXT" "$STATUS_LINES" "$default_item" \
        "install"  "Full install — setup from scratch" \
        "update"   "Update all — repos + missing packages" \
        "noctalia" "Apply repo Noctalia config" \
        "export"   "Export live Noctalia config to repo" \
        "commits"  "Recent commits — subjects + bodies" \
        "quit"     "Quit") || { clear; exit 0; }

    case "$choice" in
        install)
            run_task "Full install" "$CACHY_DIR/install.sh"
            ;;
        update)
            if ! config_installed; then
                ui_msg "Note" "No cachy-config install in ~/.config.\nRun \\ZbFull install\\Zn first." 3
                continue
            fi
            run_task "Update all" "$CACHY_DIR/update.sh"
            ;;
        noctalia)
            apply_noctalia
            ;;
        export)
            export_noctalia
            ;;
        commits)
            show_commits
            ;;
        quit | *)
            clear
            exit 0
            ;;
    esac
done
