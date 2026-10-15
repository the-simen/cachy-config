#!/usr/bin/env bash
# hover-menu.sh — mouse-hover + keyboard picker for ghostty/xterm terminals.
#
#   hover-menu.sh --title T [--prompt P] [--fg HEX] [--accent HEX] [--hint H] \
#       [--select N] \
#       tag1 "label 1" [tag2 "label 2" ...]
#     prints the chosen tag to stdout (exit 0); ESC/q exits 1.
#   hover-menu.sh --info --title T --prompt P [--fg HEX] [--accent HEX]
#     shows a rounded box, waits for any key/click (exit 0).
#
# Mouse: SGR extended mode (1006) + any-event tracking (1003): motion
# highlights, left release confirms — instant, no click-delay. Keyboard:
# arrows/j/k move, Enter/C-j confirm, wheel scrolls.
# Draws to stderr (stdout stays clean for $()), reads keys from /dev/tty.
# Exit 2 = terminal unsuitable (caller should fall back to dialog).

set -uo pipefail

TITLE=""
PROMPT=""
FG="#ffffff"
ACCENT="#ebdbb2"
HINT="hover / ↑↓jk · click / Enter to confirm"
INFO=0
INIT=0
TAGS=()
LABELS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --title) TITLE="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --fg) FG="$2"; shift 2 ;;
        --accent) ACCENT="$2"; shift 2 ;;
        --hint) HINT="$2"; shift 2 ;;
        --select) INIT="$2"; shift 2 ;;
        --info) INFO=1; shift ;;
        --) shift; break ;;
        -*) echo "hover-menu: unknown flag $1" >&2; exit 2 ;;
        *) TAGS+=("$1"); LABELS+=("${2:-$1}"); shift 2 ;;
    esac
done

# dialog-style \Z sequences (passed through from config-manager) -> ANSI.
z2ansi() {
    sed -e 's/\\Z0/\x1b[30m/g' -e 's/\\Z1/\x1b[31m/g' \
        -e 's/\\Z2/\x1b[32m/g' -e 's/\\Z3/\x1b[33m/g' \
        -e 's/\\Z4/\x1b[34m/g' -e 's/\\Z5/\x1b[35m/g' \
        -e 's/\\Z6/\x1b[36m/g' -e 's/\\Z7/\x1b[37m/g' \
        -e 's/\\Zb/\x1b[1m/g' -e 's/\\ZB/\x1b[1m/g' \
        -e 's/\\Zn/\x1b[0m/g' -e 's/\\Z[BRUbru]//g'
}
TITLE=$(z2ansi <<<"$TITLE")
PROMPT=$(z2ansi <<<"$PROMPT")
HINT=$(z2ansi <<<"$HINT")
for _i in "${!LABELS[@]}"; do LABELS[$_i]=$(z2ansi <<<"${LABELS[$_i]}"); done

[ ${#LABELS[@]} -eq 0 ] && [ "$INFO" -eq 0 ] && { echo "hover-menu: no items" >&2; exit 2; }
[ -t 2 ] || exit 2
[ -e /dev/tty ] || exit 2

# ---------------- terminal setup ----------------

# Byte-exact UTF-8 output must not depend on the caller's locale
# (e.g. tr(1) mangles multibyte fills under LC_ALL=C), so enforce UTF-8
# and never use locale-sensitive tools for drawing.
if [[ "${LC_ALL:-}" != *UTF-8 && "${LANG:-}" != *UTF-8 && "${LC_CTYPE:-}" != *UTF-8 ]]; then
    export LC_ALL=C.UTF-8
fi

# Optional debug: HO_DEBUG=1 logs input bytes and errors here.
HO_LOG="${HO_DEBUG:+/tmp/hover-menu.log}"
holog() { [ -n "${HO_LOG:-}" ] && printf '%s\n' "$*" >>"$HO_LOG"; }

exec {IN}</dev/tty || exit 2
OUT=/dev/stderr

cols() { tput cols 2>/dev/null || echo 80; }
rows() { tput lines 2>/dev/null || echo 24; }

hex2rgb() { # #rrggbb -> "r;g;b"
    local h="${1#\#}"
    printf '%d;%d;%d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

FG_RGB=$(hex2rgb "$FG")
AC_RGB=$(hex2rgb "$ACCENT")

cleanup() {
    printf '\e[?1003l\e[?1006l\e[?25h' > "$OUT" 2>/dev/null
    exec {IN}>&- 2>/dev/null
}
trap cleanup EXIT INT TERM

printf '\e[?25l' > "$OUT"
holog "start term=$TERM lang=${LANG:-} lc_all=${LC_ALL:-} cols=$(cols) rows=$(rows)"
if [ "$INFO" -eq 0 ]; then
    printf '\e[?1003h\e[?1006h' > "$OUT"
fi

LAYOUT_OK=0
trap 'LAYOUT_OK=0' WINCH

# Strip ANSI for width measuring.
visible() { sed 's/\x1b\[[0-9;]*m//g' <<<"$1"; }
# Locale-independent horizontal ruling of $1 cells (pure bash: tr(1)
# splits multibyte chars under non-UTF-8 locales, producing '?' glyphs).
rule() { local n=$1 s; printf -v s '%*s' "$n" ''; echo "${s// /─}"; }
# Visible cell width via wcwidth (emoji/CJK = 2 cells). Pure-bash
# counting mismeasures multibyte under non-UTF-8 locales.
vlen() {
    local s
    s=$(visible "$1")
    if command -v python3 &>/dev/null; then
        python3 -c 'import sys,unicodedata as u
s=sys.stdin.read().rstrip("\n")
print(sum(2 if u.east_asian_width(c) in "WF" else 1 for c in s))' <<<"$s"
    else
        echo "${#s}"
    fi
}

# ---------------- drawing ----------------

SEL=0
# Click-through guard: a release confirms only if its press started
# inside this menu. A release without a preceding press (e.g. from the
# launcher click that opened this window) is ignored.
ARMED=0
if [[ "$INIT" =~ ^[0-9]+$ ]] && [ "${#LABELS[@]}" -gt 0 ] && [ "$INIT" -lt "${#LABELS[@]}" ]; then
    SEL=$INIT
fi
BOX_W=0
BOX_R=0   # first row (1-based) of the box top border
ITEM_R=0  # row of item 0

# ---------------- layout (slow: python per line) ----------------
# Computed once per geometry/content; render() below uses only the cache,
# so Rosa motion floods redraw in pure bash with zero forks of python.
L_W=0 L_H=0 L_BOXW=0 L_INNER=0 L_TOP=0 L_LEFT=0 L_ITEMR=0
L_RULE=""
L_TFILL=0
L_PPADS=()
L_LPADS=()
L_HPAD=0
L_HIDEHINT=0

layout() {
    local W H
    W=$(cols); H=$(rows)
    [ "$W" -lt 30 ] && W=30
    L_W=$W; L_H=$H

    local i maxw=0 l
    if [ -n "$TITLE" ]; then maxw=$(vlen "$TITLE"); fi
    while IFS= read -r line; do
        l=$(vlen "$line")
        [ "$l" -gt "$maxw" ] && maxw=$l
    done <<<"$(printf '%s\n' "$PROMPT")"
    for i in "${!LABELS[@]}"; do
        l=$(vlen "${LABELS[$i]}")
        [ "$l" -gt "$maxw" ] && maxw=$l
    done
    l=$(vlen "$HINT")
    [ "$l" -gt "$maxw" ] && maxw=$l

    L_BOXW=$((maxw + 8))
    [ "$L_BOXW" -gt "$((W - 4))" ] && L_BOXW=$((W - 4))
    L_INNER=$((L_BOXW - 4))
    L_RULE=$(rule "$L_INNER")
    L_TFILL=$((L_INNER - maxw - 0))
    if [ -n "$TITLE" ]; then
        L_TFILL=$((L_INNER - $(vlen "$TITLE") - 4))
    else
        L_TFILL=$L_INNER
    fi
    [ "$L_TFILL" -lt 0 ] && L_TFILL=0

    L_PPADS=()
    while IFS= read -r line; do
        l=$((L_INNER - $(vlen "$line") - 2))
        [ "$l" -lt 0 ] && l=0
        L_PPADS+=("$l")
    done <<<"$(printf '%s\n' "$PROMPT")"
    L_LPADS=()
    for i in "${!LABELS[@]}"; do
        l=$((L_INNER - $(vlen "${LABELS[$i]}") - 4))
        [ "$l" -lt 0 ] && l=0
        L_LPADS+=("$l")
    done
    L_HPAD=$((L_INNER - $(vlen "$HINT") - 2))
    [ "$L_HPAD" -lt 0 ] && L_HPAD=0

    # Content rows: title + prompt + sep + items + hint-sep + hint + bottom.
    local nrows=$((1 + ${#L_PPADS[@]} + 1 + ${#LABELS[@]} + 2 + 1))
    [ -n "$PROMPT" ] || nrows=$((nrows - ${#L_PPADS[@]} - 1))
    L_HIDEHINT=0
    if [ "$((1 + nrows))" -gt "$H" ] && [ "$INFO" -eq 0 ]; then
        L_HIDEHINT=1
        nrows=$((nrows - 2))
    fi
    L_TOP=$(( (H - nrows) / 2 ))
    [ "$L_TOP" -lt 1 ] && L_TOP=1
    L_LEFT=$(( (W - L_BOXW) / 2 ))
    [ "$L_LEFT" -lt 0 ] && L_LEFT=0

    # First item row: top + title + prompt + prompt-sep.
    L_ITEMR=$((L_TOP + 1))
    [ -n "$PROMPT" ] && L_ITEMR=$((L_ITEMR + ${#L_PPADS[@]} + 1))
    ITEM_R=$L_ITEMR
    BOX_W=$L_BOXW
    BOX_R=$L_TOP
}

# ---------------- drawing (fast: cache only, no slow calls) ----------------

draw() {
    [ "$LAYOUT_OK" = "1" ] || { layout; LAYOUT_OK=1; }
    local esc=$'\e'
    local B_FG="38;2;$AC_RGB"      # border/accent
    local T_FG="38;2;$AC_RGB"      # title
    local I_FG="38;2;$FG_RGB"      # item text
    local S_FG="30"                # selected text (black)
    local S_BG="48;2;$AC_RGB"      # selected fill (accent)
    local RST="0"
    local left=$L_LEFT r=$L_TOP i

    local out=""
    out+="\e[2J\e[H"               # clear + home (stable coords)
    out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m╭"
    if [ -n "$TITLE" ]; then
        out+="─ ${esc}[1;${T_FG}m${TITLE}${esc}[${B_FG}m ─"
    fi
    out+="$(rule "$L_TFILL")╮${esc}[${RST}m"
    r=$((r + 1))

    if [ -n "$PROMPT" ]; then
        i=0
        while IFS= read -r line; do
            out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m│ ${esc}[${RST}m${line}$(spaces "${L_PPADS[$i]}") ${esc}[${B_FG}m│${esc}[${RST}m"
            r=$((r + 1)); i=$((i + 1))
        done <<<"$(printf '%s\n' "$PROMPT")"
        out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m├${L_RULE}┤${esc}[${RST}m"
        r=$((r + 1))
    fi

    for i in "${!LABELS[@]}"; do
        if [ "$i" -eq "$SEL" ]; then
            out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m│${esc}[${S_FG};${S_BG}m ➤ ${LABELS[$i]}$(spaces "${L_LPADS[$i]}") ${esc}[${RST}m${esc}[${B_FG}m│${esc}[${RST}m"
        else
            out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m│${esc}[${I_FG}m   ${LABELS[$i]}$(spaces "${L_LPADS[$i]}") ${esc}[${RST}m${esc}[${B_FG}m│${esc}[${RST}m"
        fi
        r=$((r + 1))
    done

    if [ "$INFO" -eq 0 ] && [ "$L_HIDEHINT" -eq 0 ]; then
        out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m├${L_RULE}┤${esc}[${RST}m"
        r=$((r + 1))
        out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m│ ${esc}[2m${HINT}$(spaces "$L_HPAD") ${esc}[${RST}m${esc}[${B_FG}m│${esc}[${RST}m"
        r=$((r + 1))
    fi
    out+="${esc}[${r};$((left + 1))H${esc}[${B_FG}m╰${L_RULE}╯${esc}[${RST}m"
    printf '%b' "$out" > "$OUT"
}

# Print $1 spaces (pure bash, no fork).
spaces() { local n=$1 s; printf -v s '%*s' "$n" ''; echo -n "$s"; }

# ---------------- input ----------------

# Reads one logical key. Sets KEY to: UP/DOWN/ENTER/ESC/Q/CHAR c/CLICK i/IGNORE.
read_key() {
    local c
    IFS= read -rsN1 -u "$IN" c || { KEY=EXIT; return; }
    if [ "$c" = $'\e' ]; then
        local c2
        if ! IFS= read -rsN1 -t 0.08 -u "$IN" c2; then KEY=ESC; return; fi
        if [ "$c2" = "[" ]; then
            local seq=""
            while IFS= read -rsN1 -u "$IN" c; do
                seq+="$c"
                case "$c" in
                    [a-zA-Z~]) break ;;
                esac
            done
            if [[ "$seq" == \<* ]]; then
                # SGR mouse: <Cb;Cx;Cy + M/m
                local fin="${seq: -1}"
                local nums="${seq:1:-1}"
                local b x y
                IFS=';' read -r b x y <<<"$nums"
                KEY="MOUSE $b $x $y $fin"
            elif [ "$seq" = "A" ]; then KEY=UP
            elif [ "$seq" = "B" ]; then KEY=DOWN
            else KEY=IGNORE
            fi
        elif [ "$c2" = "M" ]; then
            # Legacy X10 mouse: ESC M Cb Cx Cy (each +32, no release events;
            # button code 3 means release). Fallback for terminals that
            # ignore SGR 1006.
            local b x y
            IFS= read -rsN1 -u "$IN" b || { KEY=EXIT; return; }
            IFS= read -rsN1 -u "$IN" x || { KEY=EXIT; return; }
            IFS= read -rsN1 -u "$IN" y || { KEY=EXIT; return; }
            b=$(printf '%d' "'$b"); x=$(printf '%d' "'$x"); y=$(printf '%d' "'$y")
            b=$((b - 32)); x=$((x - 32)); y=$((y - 32))
            if [ "$b" = "3" ]; then
                KEY="MOUSE $b $x $y m"
            else
                KEY="MOUSE $b $x $y M"
            fi
            holog "x10: $KEY"
        else
            holog "lone-esc-or-alt"
            KEY=ESC
        fi
    elif [ "$c" = $'\r' ] || [ "$c" = $'\n' ]; then KEY=ENTER
    elif [ "$c" = "q" ] || [ "$c" = "Q" ]; then KEY=Q
    elif [ "$c" = "j" ]; then KEY=DOWN
    elif [ "$c" = "k" ]; then KEY=UP
    else KEY="CHAR $c"
    fi
}

row_to_item() { # y -> index or -1
    local y=$1 n=${#LABELS[@]}
    if [ "$y" -ge "$ITEM_R" ] && [ "$y" -lt "$((ITEM_R + n))" ]; then
        echo $((y - ITEM_R))
    else
        echo -1
    fi
}

# ---------------- info mode ----------------

if [ "$INFO" -eq 1 ]; then
    PROMPT="$TITLE
$PROMPT"
    TITLE=""
    LABELS=()
    HINT="click / any key to continue"
    draw
    while true; do
        read_key
        case "$KEY" in
            MOUSE*) set -- $KEY; [ "$5" = "m" ] || [ "$2" = 0 ] && exit 0 ;;
            *) exit 0 ;;
        esac
    done
fi

# ---------------- menu loop ----------------

draw
while true; do
    read_key
    case "$KEY" in
        UP) SEL=$(( (SEL - 1 + ${#LABELS[@]}) % ${#LABELS[@]} )); draw ;;
        DOWN) SEL=$(( (SEL + 1) % ${#LABELS[@]} )); draw ;;
        ENTER) echo "${TAGS[$SEL]}"; exit 0 ;;
        ESC|Q) exit 1 ;;
        MOUSE*)
            set -- $KEY  # MOUSE b x y fin (no `local`: top-level loop)
            _mb=$2; _mx=$3; _my=$4; _mfin=$5
            if [ "$_mb" = "64" ]; then SEL=$(( (SEL - 1 + ${#LABELS[@]}) % ${#LABELS[@]} )); draw
            elif [ "$_mb" = "65" ]; then SEL=$(( (SEL + 1) % ${#LABELS[@]} )); draw
            elif [ "$_mfin" = "M" ]; then
                if [ "$_mb" = "35" ] || [ "$((_mb & 3))" = "0" ]; then
                    # motion (35) never arms: 35 & 3 == 3; drags/presses do.
                    [ "$((_mb & 3))" = "0" ] && ARMED=1
                    _midx=$(row_to_item "$_my")
                    if [ "$_midx" -ge 0 ] && [ "$_midx" != "$SEL" ]; then SEL=$_midx; draw; fi
                fi
            elif [ "$_mfin" = "m" ]; then
                if [ "$ARMED" = "1" ]; then
                    ARMED=0
                    _midx=$(row_to_item "$_my")
                    if [ "$_midx" -ge 0 ]; then echo "${TAGS[$_midx]}"; exit 0; fi
                fi
            fi
            ;;
    esac
done
