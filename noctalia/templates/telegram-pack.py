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
import struct
import sys
import tempfile
import zlib
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

STAGING = Path.home() / ".cache/noctalia/telegram-contrast.rendered.tdesktop-theme"
FINAL = Path.home() / ".config/telegram-desktop/themes/noctalia-contrast.tdesktop-theme"
CACHE_DIR = Path.home() / ".cache/noctalia"
CACHE_COLORS = CACHE_DIR / "telegram-contrast.last-colors.tdesktop-theme"
CACHE_ZIP = CACHE_DIR / "telegram-contrast.last.tdesktop-theme"

try:
    from PIL import Image

    _HAS_PIL = True
except ImportError:
    Image = None  # type: ignore
    _HAS_PIL = False


def _write_solid_png(path: Path, hex_color: str, size: int = 512) -> None:
    """Stdlib fallback: write a solid-color RGB PNG without Pillow."""
    hex_color = hex_color.strip().lstrip("#")
    r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
    row = b"\x00" + bytes((r, g, b)) * size
    raw = row * size

    def chunk(ctype: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + ctype
            + data
            + struct.pack(">I", zlib.crc32(ctype + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def _write_background(path: Path, hex_color: str) -> None:
    if _HAS_PIL:
        Image.new("RGB", (512, 512), hex_color).save(path / "background.png")
    else:
        _write_solid_png(path / "background.png", hex_color)
        print("telegram-pack: PIL not found, used stdlib PNG writer", file=sys.stderr)


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
        FINAL.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(CACHE_ZIP, FINAL)
        print("telegram-pack: palette unchanged, final theme restored from cache")
        return 0

    m = re.search(r"^windowBg:\s*(#[0-9a-fA-F]{6})", text, re.M)
    if not m:
        print("telegram-pack: windowBg not found", file=sys.stderr)
        return 1
    bg = m.group(1)

    tmp = Path(tempfile.mkdtemp())
    _write_background(tmp, bg)
    (tmp / "colors.tdesktop-theme").write_text(text)
    packed = tmp / "noctalia-contrast.tdesktop-theme"
    with ZipFile(packed, "w", ZIP_DEFLATED) as zf:
        zf.write(tmp / "colors.tdesktop-theme", "colors.tdesktop-theme")
        zf.write(tmp / "background.png", "background.png")
    FINAL.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(packed, FINAL)
    shutil.rmtree(tmp, ignore_errors=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_COLORS.write_text(text)
    shutil.copyfile(FINAL, CACHE_ZIP)
    print(f"telegram-pack: palette changed, packed {FINAL} with solid background {bg}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
