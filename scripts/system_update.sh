#!/usr/bin/env bash

set -e

echo "Updating system..."
sudo -v

# pacman (Arch)
if command -v pacman &>/dev/null; then
  echo "[pacman] updating..."
  sudo pacman -Syu --noconfirm
fi

# paru (AUR helper)
if command -v paru &>/dev/null; then
  echo "[paru] updating..."
  paru -Syu --noconfirm
fi

# flatpak (only if exists)
if command -v flatpak &>/dev/null; then
  echo "[flatpak] updating..."
  flatpak update -y
fi

echo ""
echo "Done. Press any key to exit..."
read -n 1
