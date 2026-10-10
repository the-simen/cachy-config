#!/usr/bin/env python3
"""Noctalia post_hook for the telegram_contrast template.

The engine renders plain-text colors into a STAGING file
(~/.cache/noctalia/telegram-contrast.rendered.tdesktop-theme).
This hook packs colors + a solid background.png into the FINAL theme zip
(~/.config/telegram-desktop/themes/noctalia-contrast.tdesktop-theme)
ONLY when the palette actually changed.

If the render is identical to the last packed one, the final file is not
touched at all (same bytes, same mtime), so Telegram never sees churn and
does not flicker on plain wallpaper switches.
"""
import hashlib
import re
import shutil
import sys
import tempfile
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

STAGING = Path.home() / ".cache/noctalia/telegram-contrast.rendered.tdesktop-theme"
FINAL = Path.home() / ".config/telegram-desktop/themes/noctalia-contrast.tdesktop-theme"
CACHE_DIR = Path.home() / ".cache/noctalia"
CACHE_COLORS = CACHE_DIR / "telegram-contrast.last-colors.tdesktop-theme"
CACHE_ZIP = CACHE_DIR / "telegram-contrast.last.tdesktop-theme"

try:
    from PIL import Image
except ImportError:
    print("telegram-pack: PIL missing, skipping zip pack", file=sys.stderr)
    sys.exit(0)


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main() -> int:
    if not STAGING.is_file():
        print(f"telegram-pack: staging {STAGING} not found", file=sys.stderr)
        return 1
    text = STAGING.read_bytes().decode()

    if CACHE_COLORS.is_file() and CACHE_ZIP.is_file() and CACHE_COLORS.read_text() == text:
        if FINAL.is_file() and sha256(FINAL) == sha256(CACHE_ZIP):
            print("telegram-pack: palette unchanged, final theme untouched")
            return 0
        shutil.copyfile(CACHE_ZIP, FINAL)
        print("telegram-pack: palette unchanged, final theme restored from cache")
        return 0

    m = re.search(r"^windowBg:\s*(#[0-9a-fA-F]{6})", text, re.M)
    if not m:
        print("telegram-pack: windowBg not found", file=sys.stderr)
        return 1
    bg = m.group(1)

    tmp = Path(tempfile.mkdtemp())
    Image.new("RGB", (512, 512), bg).save(tmp / "background.png")
    (tmp / "colors.tdesktop-theme").write_text(text)
    packed = tmp / "noctalia-contrast.tdesktop-theme"
    with ZipFile(packed, "w", ZIP_DEFLATED) as zf:
        zf.write(tmp / "colors.tdesktop-theme", "colors.tdesktop-theme")
        zf.write(tmp / "background.png", "background.png")
    shutil.move(packed, FINAL)
    shutil.rmtree(tmp, ignore_errors=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_COLORS.write_text(text)
    shutil.copyfile(FINAL, CACHE_ZIP)
    print(f"telegram-pack: palette changed, packed {FINAL} with solid background {bg}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
