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

# Kill the tty echo for the whole session: between key reads the echo is
# on, and a mouse-motion flood would print its escape bytes as garbage
# on screen. Also disable XON/XOFF so Ctrl-S can't freeze output.
# Restored in cleanup (Ctrl-C still works: ISIG stays on).
STTY_SAVE=$(stty -g </dev/tty 2>/dev/null) || exit 2
stty -echo -ixon </dev/tty 2>/dev/null

cols() { tput cols 2>/dev/null || echo 80; }
rows() { tput lines 2>/dev/null || echo 24; }

hex2rgb() { # #rrggbb -> "r;g;b"
    local h="${1#\#}"
    printf '%d;%d;%d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

FG_RGB=$(hex2rgb "$FG")
AC_RGB=$(hex2rgb "$ACCENT")

cleanup() {
    [ -n "${STTY_SAVE:-}" ] && stty "$STTY_SAVE" </dev/tty 2>/dev/null
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?25h' > "$OUT" 2>/dev/null
    exec {IN}>&- 2>/dev/null
}
trap cleanup EXIT INT TERM

printf '\e[?25l' > "$OUT"
holog "start term=$TERM lang=${LANG:-} lc_all=${LC_ALL:-} cols=$(cols) rows=$(rows)"
# SGR extended mouse (1006) + full tracking (1000/1002/1003: press, drag,
# motion, wheel) for every mode: requesting only 1003 leaves terminals
# that implement a subset silent. Without 1006 they fall back to legacy.
printf '\e[?1000h\e[?1002h\e[?1003h\e[?1006h' > "$OUT"

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
# so mouse motion floods redraw in pure bash with zero forks of python.
L_W=0 L_H=0 L_BOXW=0 L_INNER=0 L_TOP=0 L_LEFT=0 L_ITEMR=0
L_RULE=""
L_TFILL=0
L_PPADS=()
L_LPADS=()
L_HPAD=0
L_HIDEHINT=0
# Batch-measured widths (one python call): prompt lines, label widths, hint.
_PWL=()
_LWLABS=()
_HW=0

layout() {
    local W H
    W=$(cols); H=$(rows)
    [ "$W" -lt 30 ] && W=30
    L_W=$W; L_H=$H

    # All visible widths in ONE python call (per-line spawns made
    # the viewer open seconds late). Order: title, prompt lines,
    # labels, hint. _PWL keeps prompt widths for the info pager.
    local -a _WL=()
    if command -v python3 &>/dev/null; then
        local IFS=$'\n'
        mapfile -t _WL < <(python3 - "$TITLE" "$PROMPT" "$HINT" "${LABELS[@]}" <<'PYEOF'
import sys, re, unicodedata as u
def w(s):
    s = re.sub(r'\x1b\[[0-9;]*m', '', s)
    return sum(2 if u.east_asian_width(c) in 'WF' else 1 for c in s)
t, p, h, labs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
print(w(t))
for line in (p.split('\n') if p else []):
    print(w(line))
for a in labs:
    print(w(a))
print(w(h))
PYEOF
        )
    fi
    # Fallback without python: byte/char lengths (no CJK compensation).
    local _pyok=1
    [ "${#_WL[@]}" -eq 0 ] && _pyok=0

    local i maxw=0 l ni=0
    _PWL=()
    if [ "$_pyok" -eq 1 ]; then
        maxw=${_WL[0]}; ni=1
        if [ -n "$PROMPT" ]; then
            while IFS= read -r line; do
                _PWL+=("${_WL[$ni]}"); ni=$((ni + 1))
            done <<<"$(printf '%s\n' "$PROMPT")"
        fi
        for i in "${!LABELS[@]}"; do _LWLABS[$i]=${_WL[$ni]}; ni=$((ni + 1)); done
        _HW=${_WL[$ni]}
        for l in "${_WL[@]}"; do [ "$l" -gt "$maxw" ] && maxw=$l; done
    else
        [ -n "$TITLE" ] && maxw=$(vlen "$TITLE")
        while IFS= read -r line; do
            l=$(vlen "$line")
            _PWL+=("$l")
            [ "$l" -gt "$maxw" ] && maxw=$l
        done <<<"$(printf '%s\n' "$PROMPT")"
        for i in "${!LABELS[@]}"; do
            l=$(vlen "${LABELS[$i]}")
            _LWLABS[$i]=$l
            [ "$l" -gt "$maxw" ] && maxw=$l
        done
        _HW=$(vlen "$HINT")
        [ "$_HW" -gt "$maxw" ] && maxw=$_HW
    fi

    L_BOXW=$((maxw + 8))
    [ "$L_BOXW" -gt "$((W - 4))" ] && L_BOXW=$((W - 4))
    L_INNER=$((L_BOXW - 4))
    L_RULE=$(rule "$L_INNER")
    if [ -n "$TITLE" ]; then
        if [ "$_pyok" -eq 1 ]; then
            L_TFILL=$((L_INNER - ${_WL[0]} - 4))
        else
            L_TFILL=$((L_INNER - $(vlen "$TITLE") - 4))
        fi
    else
        L_TFILL=$L_INNER
    fi
    [ "$L_TFILL" -lt 0 ] && L_TFILL=0

    L_PPADS=()
    if [ -n "$PROMPT" ]; then
        if [ "$_pyok" -eq 1 ]; then
            for l in "${_PWL[@]}"; do
                l=$((L_INNER - l - 2))
                [ "$l" -lt 0 ] && l=0
                L_PPADS+=("$l")
            done
        else
            while IFS= read -r line; do
                l=$((L_INNER - $(vlen "$line") - 2))
                [ "$l" -lt 0 ] && l=0
                L_PPADS+=("$l")
            done <<<"$(printf '%s\n' "$PROMPT")"
        fi
    fi
    L_LPADS=()
    for i in "${!LABELS[@]}"; do
        if [ "$_pyok" -eq 1 ]; then
            l=$((L_INNER - ${_LWLABS[$i]} - 4))
        else
            l=$((L_INNER - $(vlen "${LABELS[$i]}") - 4))
        fi
        [ "$l" -lt 0 ] && l=0
        L_LPADS+=("$l")
    done
    if [ "$_pyok" -eq 1 ]; then
        L_HPAD=$((L_INNER - _HW - 2))
    else
        L_HPAD=$((L_INNER - $(vlen "$HINT") - 2))
    fi
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

# ---------------- drawing ----------------
# Colors resolved once (globals); rows rendered incrementally:
# full draw() only on start/resize, move_to() repaints just the two
# rows that change — no clear, no flicker under motion floods.
C_B="" C_T="" C_I="" C_SF="30" C_SB="" C_RST="0"

row_str() { # i -> positioned row escape string on stdout
    local i=$1 esc=$'\e'
    local r=$((L_ITEMR + i)) left=$L_LEFT
    if [ "$i" -eq "$SEL" ]; then
        printf '%s' "${esc}[${r};$((left + 1))H${esc}[${C_B}m│${esc}[${C_SF};${C_SB}m ➤ ${LABELS[$i]}$(spaces "${L_LPADS[$i]}") ${esc}[${C_RST}m${esc}[${C_B}m│${esc}[${C_RST}m"
    else
        printf '%s' "${esc}[${r};$((left + 1))H${esc}[${C_B}m│${esc}[${C_I}m   ${LABELS[$i]}$(spaces "${L_LPADS[$i]}") ${esc}[${C_RST}m${esc}[${C_B}m│${esc}[${C_RST}m"
    fi
}

# move_to n: switch highlight with two row repaints (no full redraw).
move_to() {
    local n=$1 o=$SEL
    [ "$n" = "$o" ] && return 0
    SEL=$n
    printf '%b' "$(row_str "$o")$(row_str "$n")" > "$OUT"
}

draw() {
    [ "$LAYOUT_OK" = "1" ] || { layout; LAYOUT_OK=1; }
    local esc=$'\e'
    C_B="38;2;$AC_RGB"      # border/accent
    C_T="38;2;$AC_RGB"      # title
    C_I="38;2;$FG_RGB"      # item text
    C_SB="48;2;$AC_RGB"     # selected fill (accent)
    local left=$L_LEFT r=$L_TOP i

    local out=""
    out+="\e[2J\e[H"               # clear + home (stable coords)
    out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m╭"
    if [ -n "$TITLE" ]; then
        out+="─ ${esc}[1;${C_T}m${TITLE}${esc}[${C_B}m ─"
    fi
    out+="$(rule "$L_TFILL")╮${esc}[${C_RST}m"
    r=$((r + 1))

    if [ -n "$PROMPT" ]; then
        i=0
        while IFS= read -r line; do
            out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│ ${esc}[${C_RST}m${line}$(spaces "${L_PPADS[$i]}") ${esc}[${C_B}m│${esc}[${C_RST}m"
            r=$((r + 1)); i=$((i + 1))
        done <<<"$(printf '%s\n' "$PROMPT")"
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m├${L_RULE}┤${esc}[${C_RST}m"
        r=$((r + 1))
    fi

    for i in "${!LABELS[@]}"; do
        out+=$(row_str "$i")
        r=$((r + 1))
    done

    if [ "$INFO" -eq 0 ] && [ "$L_HIDEHINT" -eq 0 ]; then
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m├${L_RULE}┤${esc}[${C_RST}m"
        r=$((r + 1))
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│ ${esc}[2m${HINT}$(spaces "$L_HPAD") ${esc}[${C_RST}m${esc}[${C_B}m│${esc}[${C_RST}m"
        r=$((r + 1))
    fi
    out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m╰${L_RULE}╯${esc}[${C_RST}m"
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
            elif [ "$seq" = "5~" ]; then KEY=PGUP
            elif [ "$seq" = "6~" ]; then KEY=PGDN
            elif [ "$seq" = "H" ]; then KEY=HOME
            elif [ "$seq" = "F" ]; then KEY=END
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
    case "$KEY" in
        "MOUSE 35 "*) ;; # motion flood: stay silent
        *) holog "key=[$KEY]" ;;
    esac
}

row_to_item() { # y -> index or -1
    local y=$1 n=${#LABELS[@]}
    if [ "$y" -ge "$ITEM_R" ] && [ "$y" -lt "$((ITEM_R + n))" ]; then
        echo $((y - ITEM_R))
    else
        echo -1
    fi
}

# Draws the startup banner (title/meta/status) in the same visual language
# as the rest of the UI: rounded truecolor box, black text on accent fill.
# Uses the same layout cache (L_*) so there are no extra forks of python.
banner() {
    [ "$LAYOUT_OK" = "1" ] || { layout; LAYOUT_OK=1; }
    local esc=$'\e'
    local C_B="38;2;$AC_RGB" C_T="38;2;$AC_RGB" C_RST="0"
    local left=$L_LEFT i
    # Widths of the ad-hoc banner lines in the same single python call.
    local -a _BL=()
    if command -v python3 &>/dev/null; then
        local IFS=$'\n'
        mapfile -t _BL < <(python3 "${@}" <<'PYEOF'
import sys, re, unicodedata as u
def w(s):
    s = re.sub(r'\x1b\[[0-9;]*m', '', s)
    return sum(2 if u.east_asian_width(c) in 'WF' else 1 for c in s)
for a in sys.argv[1:]:
    print(w(a))
PYEOF
        )
    fi

    local nlines=$# nrows=$((1 + nlines + 2))
    L_TOP=$(( (L_H - nrows) / 2 ))
    [ "$L_TOP" -lt 1 ] && L_TOP=1
    local r=$L_TOP
    local out=""
    out+="\e[2J\e[H"
    out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m╭"
    if [ -n "$TITLE" ]; then
        out+="─ ${esc}[1;${C_T}m${TITLE}${esc}[${C_B}m ─"
    fi
    out+="$(rule "$L_TFILL")╮${esc}[${C_RST}m"
    r=$((r + 1))
    out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│${esc}[${C_RST}m"
    r=$((r + 1))
    local bi=0
    for i in "$@"; do
        local l=$((L_INNER - ${_BL[$bi]} - 2))
        [ "$l" -lt 0 ] && l=0
        if [ -z "$i" ]; then
            out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│$(spaces "$l") ${esc}[${C_B}m│${esc}[${C_RST}m"
        else
            out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│ ${esc}[${C_RST}m${i}$(spaces "$l") ${esc}[${C_B}m│${esc}[${C_RST}m"
        fi
        r=$((r + 1)); bi=$((bi + 1))
    done
    out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│${esc}[${C_RST}m"
    r=$((r + 1))
    out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m╰${L_RULE}╯${esc}[${C_RST}m"
    printf '%b' "$out" > "$OUT"
}

# ---------------- info mode (scrollable viewer) ----------------
# Paged viewer: wheel/arrows/PgUp/PgDn/Space/Home/End scroll,
# click / Enter / Esc / q goes back. No less, mouse everywhere.

if [ "$INFO" -eq 1 ]; then
    mapfile -t IL_LINES < <(printf '%s\n' "$PROMPT")
    [ "${IL_LINES[-1]:-x}" = "" ] && unset 'IL_LINES[-1]'
    IL_OFF=0
    IL_HL=-1
    IL_BTNHL=0

    # Batched width measurement for pager lines (one python call).
    _ILWL=()
    if command -v python3 &>/dev/null; then
        IFS=$'\n'
        mapfile -t _ILWL < <(python3 - "${IL_LINES[@]}" <<'PYEOF'
import sys, re, unicodedata as u
def w(s):
    s = re.sub(r'\x1b\[[0-9;]*m', '', s)
    return sum(2 if u.east_asian_width(c) in 'WF' else 1 for c in s)
for a in sys.argv[1:]:
    print(w(a))
PYEOF
        )
    fi
    # Fallback: byte length (no CJK compensation without python).
    if [ "${#_ILWL[@]}" -ne "${#IL_LINES[@]}" ]; then
        _ILWL=()
        for _li in "${IL_LINES[@]}"; do _ILWL+=("${#_li}"); done
    fi

    info_layout() {
        layout
        # Recompute inner width from pager lines too — layout() only sees
        # the raw PROMPT blob, so maxw must include IL_LINES here.
        local i maxw=0 l
        if [ -n "$TITLE" ]; then maxw=$(vlen "$TITLE"); fi
        l=$(vlen "$HINT")
        [ "$l" -gt "$maxw" ] && maxw=$l
        for i in "${!_ILWL[@]}"; do
            l=${_ILWL[$i]}
            [ "$l" -gt "$maxw" ] && maxw=$l
        done
        L_BOXW=$((maxw + 8))
        [ "$L_BOXW" -gt "$((L_W - 4))" ] && L_BOXW=$((L_W - 4))
        L_INNER=$((L_BOXW - 4))
        L_RULE=$(rule "$L_INNER")
        if [ -n "$TITLE" ]; then
            L_TFILL=$((L_INNER - $(vlen "$TITLE") - 4))
        else
            L_TFILL=$L_INNER
        fi
        [ "$L_TFILL" -lt 0 ] && L_TFILL=0
        local H=$L_H
        IL_PAGE=$((H - 6))
        [ "$IL_PAGE" -lt 3 ] && IL_PAGE=3
        IL_TOP=$(( (H - (IL_PAGE + 4)) / 2 ))
        [ "$IL_TOP" -lt 1 ] && IL_TOP=1
    }

    # Geometry must exist before the first draw/hit-test.
    info_layout
    LAYOUT_OK=1

    # Back button geometry (used by draw + hover hit-test).
    # Must match the actual draw_info output:
    #   row: IL_TOP + 1 (title) + IL_PAGE (content) + 1 (separator) = IL_TOP + IL_PAGE + 2
    #   col: left+1 (CUP) + 2 ("│ ") + (L_INNER - BTN_W - 2) (pad) = left + L_INNER - BTN_W + 1
    BTN_LABEL="[ ← Back ]"
    BTN_W=11
    BTN_ROW=$((IL_TOP + IL_PAGE + 2))
    BTN_C0=$((L_LEFT + L_INNER - BTN_W + 1))
    BTN_C1=$((BTN_C0 + BTN_W - 1))

    draw_info() {
        [ "$LAYOUT_OK" = "1" ] || { info_layout; LAYOUT_OK=1; }
        if [ -z "$C_B" ]; then
            C_B="38;2;$AC_RGB"; C_T="38;2;$AC_RGB"; C_I="38;2;$FG_RGB"
            C_SF="30"; C_SB="48;2;$AC_RGB"; C_RST="0"
        fi
        local esc=$'\e' left=$L_LEFT r=$IL_TOP i n=${#IL_LINES[@]}
        local out=""
        out+="\e[2J\e[H"
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m╭"
        if [ -n "$TITLE" ]; then
            out+="─ ${esc}[1;${C_T}m${TITLE}${esc}[${C_B}m ─"
        fi
        out+="$(rule "$L_TFILL")╮${esc}[${C_RST}m"
        r=$((r + 1))
        local end=$((IL_OFF + IL_PAGE))
        for ((i = IL_OFF; i < end && i < n; i++)); do
            local l=$((L_INNER - ${_ILWL[$i]} - 2))
            [ "$l" -lt 0 ] && l=0
            out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│ ${esc}[${C_I}m${IL_LINES[$i]}$(spaces "$l") ${esc}[${C_B}m│${esc}[${C_RST}m"
            r=$((r + 1))
        done
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m├${L_RULE}┤${esc}[${C_RST}m"
        r=$((r + 1))
        local fill="48;2;${AC_RGB}" txt="30"
        [ "$IL_BTNHL" = "1" ] || { fill="0"; txt="${C_I}"; }
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m│ ${esc}[${C_RST}m$(spaces $((L_INNER - BTN_W - 2)))${esc}[${txt};${fill}m ${BTN_LABEL} ${esc}[${C_RST}m${esc}[${C_B}m│${esc}[${C_RST}m"
        r=$((r + 1))
        out+="${esc}[${r};$((left + 1))H${esc}[${C_B}m╰${L_RULE}╯${esc}[${C_RST}m"
        printf '%b' "$out" > "$OUT"
        # Scrollbar on the right border
        local track0=$((IL_TOP + 1))
        local max=$((n - IL_PAGE)); [ "$max" -lt 0 ] && max=0
        local pos=0
        [ "$max" -gt 0 ] && pos=$((IL_OFF * 100 / max))
        local thumb=$((IL_PAGE * IL_PAGE / (n > 0 ? n : 1)))
        [ "$thumb" -lt 1 ] && thumb=1
        local t0=$((track0 + pos * (IL_PAGE - thumb) / 100))
        for ((i = 0; i < IL_PAGE; i++)); do
            local c=2
            if [ $((t0 + thumb)) -gt $i ] && [ "$i" -ge "$t0" ]; then c=1; fi
            printf '%s' "${esc}[$((track0 + i));$((left + L_INNER + 3))H${esc}[${c}m▏${esc}[${C_RST}m" > "$OUT"
        done
    }

    info_scroll() { # delta (may be negative) or ABS:n
        local n=${#IL_LINES[@]} max
        max=$((n - IL_PAGE))
        [ "$max" -lt 0 ] && max=0
        if [[ "$1" == ABS:* ]]; then
            IL_OFF=${1#ABS:}
        else
            IL_OFF=$((IL_OFF + $1))
        fi
        [ "$IL_OFF" -lt 0 ] && IL_OFF=0
        [ "$IL_OFF" -gt "$max" ] && IL_OFF=$max
        draw_info
    }

    printf '\e[2J\e[H' > "$OUT"
    draw_info
    while true; do
        read_key
        case "$KEY" in
            UP) info_scroll -1 ;;
            DOWN) info_scroll 1 ;;
            PGUP) info_scroll -$IL_PAGE ;;
            PGDN) info_scroll $IL_PAGE ;;
            HOME) info_scroll ABS:0 ;;
            END) info_scroll ABS:999999 ;;
            "CHAR  ") info_scroll $IL_PAGE ;;
            ENTER|ESC|Q) exit 0 ;;
            MOUSE*)
                _mb=$(echo "$KEY" | awk '{print $2}')
                _mx=$(echo "$KEY" | awk '{print $3}')
                _my=$(echo "$KEY" | awk '{print $4}')
                _mfin=$(echo "$KEY" | awk '{print $5}')
                [ -z "$_mb" ] && continue
                if [ "$_mb" = "64" ]; then info_scroll -3
                elif [ "$_mb" = "65" ]; then info_scroll 3
                elif [ "$_mfin" = "M" ]; then
                    # Hover on Back button: arm for click, highlight
                    if [ "$_my" = "$BTN_ROW" ] && [ "$_mx" -ge "$BTN_C0" ] && [ "$_mx" -le "$BTN_C1" ]; then
                        [ "$IL_BTNHL" = "0" ] && { IL_BTNHL=1; draw_info; }
                        ARMED=1
                    else
                        [ "$IL_BTNHL" = "1" ] && { IL_BTNHL=0; draw_info; }
                        ARMED=0
                    fi
                elif [ "$_mfin" = "m" ]; then
                    # Release on Back button: exit
                    if [ "$ARMED" = "1" ] && [ "$_my" = "$BTN_ROW" ] && [ "$_mx" -ge "$BTN_C0" ] && [ "$_mx" -le "$BTN_C1" ]; then
                        exit 0
                    fi
                    ARMED=0; IL_BTNHL=0
                fi
                ;;
        esac
    done
fi

# ---------------- menu loop ----------------

draw
while true; do
    read_key
    case "$KEY" in
        UP) move_to $(( (SEL - 1 + ${#LABELS[@]}) % ${#LABELS[@]} )) ;;
        DOWN) move_to $(( (SEL + 1) % ${#LABELS[@]} )) ;;
        ENTER) echo "${TAGS[$SEL]}"; exit 0 ;;
        ESC|Q) exit 1 ;;
        MOUSE*)
            set -- $KEY  # MOUSE b x y fin (no `local`: top-level loop)
            _mb=$2; _mx=$3; _my=$4; _mfin=$5
            if [ "$_mb" = "64" ]; then move_to $(( (SEL - 1 + ${#LABELS[@]}) % ${#LABELS[@]} ))
            elif [ "$_mb" = "65" ]; then move_to $(( (SEL + 1) % ${#LABELS[@]} ))
            elif [ "$_mfin" = "M" ]; then
                if [ "$_mb" = "35" ] || [ "$((_mb & 3))" = "0" ]; then
                    # motion (35) never arms: 35 & 3 == 3; drags/presses do.
                    [ "$((_mb & 3))" = "0" ] && ARMED=1
                    _midx=$(row_to_item "$_my")
                    [ "$_midx" -ge 0 ] && move_to "$_midx"
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
