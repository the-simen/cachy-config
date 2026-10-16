#!/bin/bash
# Applies a repo Noctalia config onto the live one, keeping the active theme.
#
# Reliable path (running shell): Noctalia's own IPC.
#   1. `noctalia config validate` the repo file (never trash working live).
#   2. Remember palette (`color-scheme-get`) and mode (`theme-mode-get`).
#   3. Copy the repo file over live, `config-reload` the shell.
#   4. Restore palette/mode via `color-scheme-set` / `theme-mode-set` —
#      Noctalia itself writes settings.toml (correct schema) and re-renders.
# Fallback (shell not running / no IPC): plain copy + TOML-level restore of
# the live [theme] scalars; template wiring always comes from the repo file.

set -u

CONFIG="$HOME/.local/state/noctalia/settings.toml"
EXTERNAL_CONFIG=$(realpath "${1:?usage: install_noctalia_conf.sh <repo-config>}")
[ -f "$EXTERNAL_CONFIG" ] || { echo "source not found: $EXTERNAL_CONFIG" >&2; exit 1; }

msg() { timeout 15 noctalia msg "$@" 2>/dev/null; }

HAVE_IPC=0
if command -v noctalia &>/dev/null && msg color-scheme-get >/dev/null; then
    HAVE_IPC=1
fi

SCHEME_SRC=""
SCHEME_NAME=""
THEME_MODE=""
if [ "$HAVE_IPC" -eq 1 ]; then
    if ! timeout 15 noctalia config validate "$EXTERNAL_CONFIG" >/dev/null; then
        echo "repo config failed validation, live config left untouched" >&2
        exit 1
    fi
    read -r SCHEME_SRC SCHEME_NAME <<<"$(msg color-scheme-get)"
    case "$SCHEME_SRC" in builtin|wallpaper|community|custom) ;; *) SCHEME_SRC="" ;; esac
    [ -z "${SCHEME_NAME:-}" ] && SCHEME_SRC=""
    THEME_MODE=$(msg theme-mode-get || true)
    case "$THEME_MODE" in dark|light) ;; *) THEME_MODE="" ;; esac
fi

THEME_BACKUP=""
if [ -f "$CONFIG" ]; then
    BACKUP="$CONFIG.backup_$(date +%Y-%m-%d_%H-%M-%S)"
    cp -p "$CONFIG" "$BACKUP"
    echo "Previous live config backed up to: $BACKUP"
    if [ "$HAVE_IPC" -eq 0 ] && command -v python3 &>/dev/null; then
        THEME_BACKUP=$(mktemp)
        python3 - "$CONFIG" "$THEME_BACKUP" <<'PYEOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
cur = None
scalars = []
with open(src, encoding='utf-8') as f:
    for line in f:
        m = re.match(r'\s*\[(.+?)\]\s*(?:#.*)?$', line)
        if m:
            cur = m.group(1).strip()
            continue
        if cur == 'theme' and re.match(r'\s*[A-Za-z0-9_]+\s*=', line):
            scalars.append(line)
with open(dst, 'w', encoding='utf-8') as f:
    f.writelines(scalars)
PYEOF
    fi
fi

rm -f "$CONFIG"
cp "$EXTERNAL_CONFIG" "$CONFIG"

if [ "$HAVE_IPC" -eq 1 ]; then
    msg config-reload >/dev/null \
        || echo "note: config-reload failed, restart the Noctalia shell manually"
    if [ -n "$SCHEME_SRC" ]; then
        if msg color-scheme-set "$SCHEME_SRC" "$SCHEME_NAME" >/dev/null; then
            echo "Active theme kept: $SCHEME_SRC $SCHEME_NAME."
        else
            echo "WARNING: could not restore theme ($SCHEME_SRC $SCHEME_NAME)," \
                "re-apply it in Noctalia Settings." >&2
        fi
    fi
    [ -n "$THEME_MODE" ] && msg theme-mode-set "$THEME_MODE" >/dev/null
    msg templates-apply >/dev/null || true
    # The repo's telegram-contrast user template renders async — give the
    # engine a moment, then make sure its outputs actually landed.
    TG_STAGE="$HOME/.cache/noctalia/telegram-contrast.rendered.tdesktop-theme"
    TG_FINAL="$HOME/.config/telegram-desktop/themes/noctalia-contrast.tdesktop-theme"
    for _w in $(seq 1 10); do
        [ -f "$TG_STAGE" ] && break
        sleep 2
    done
    if [ ! -f "$TG_STAGE" ]; then
        echo "WARNING: telegram staging missing ($TG_STAGE)." \
            "Is the telegram_contrast template enabled? See journalctl --user -u noctalia." >&2
    elif [ -d "$HOME/.config/telegram-desktop" ] && [ ! -f "$TG_FINAL" ]; then
        echo "WARNING: telegram theme not packed ($TG_FINAL missing)." \
            "See journalctl --user -u noctalia." >&2
    else
        echo "Telegram theme outputs present."
    fi
elif [ -n "$THEME_BACKUP" ] && [ -s "$THEME_BACKUP" ]; then
    python3 - "$CONFIG" "$THEME_BACKUP" <<'PYEOF'
import re, sys
cfg, keep = sys.argv[1], sys.argv[2]
with open(keep, encoding='utf-8') as f:
    kept = [(re.match(r'\s*([A-Za-z0-9_]+)\s*=', l).group(1), l) for l in f]
keepmap = dict(kept)
with open(cfg, encoding='utf-8') as f:
    lines = f.readlines()
out, cur, done = [], None, set()
def flush():
    for k, kl in kept:
        if k not in done:
            out.append(kl)
            done.add(k)
for line in lines:
    m = re.match(r'\s*\[(.+?)\]\s*(?:#.*)?$', line)
    if m:
        if cur == 'theme':
            flush()  # keys the repo section lacks go right before next header
        cur = m.group(1).strip()
        out.append(line)
        continue
    if cur == 'theme':
        m = re.match(r'\s*([A-Za-z0-9_]+)\s*=', line)
        if m and m.group(1) in keepmap:
            out.append(keepmap[m.group(1)])  # live value at repo position
            done.add(m.group(1))
            continue
    out.append(line)
if cur == 'theme':
    flush()
with open(cfg, 'w', encoding='utf-8') as f:
    f.writelines(out)
print('Active theme kept from the previous live config.')
PYEOF
fi
rm -f ${THEME_BACKUP:-/nonexistent}
