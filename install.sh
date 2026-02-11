#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Arch Linux Gaming Setup – AMD Edition
# Working version – fixed base tools + install
# ==========================================

# Root check
if [[ "$EUID" -eq 0 ]]; then
  echo "💀 Bro, why are you running this as root?"
  echo "You are stupid. Stop it. Run as normal user with sudo, gah damn."
  exit 1
fi

echo "=== AMD GAMING SETUP FOR ARCH ==="

# Ensure pacman keyring is initialized
sudo pacman-key --init
sudo pacman-key --populate archlinux

# Update system first
echo "[1/7] Updating system..."
sudo pacman -Syu --noconfirm

# Force install base tools
echo "[2/7] Installing base tools..."
sudo pacman -S --needed --noconfirm \
  git curl wget unzip zip nano vim base-devel \
  htop btop fastfetch neofetch python python-pip ntfs-3g

# Audio tools
echo "[3/7] Installing PipeWire audio..."
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  alsa-utils pavucontrol

# Gaming core (Steam, Wine, Lutris, Heroic, AMD Vulkan)
echo "[4/7] Installing gaming core..."
sudo pacman -S --needed --noconfirm \
  steam \
  wine winetricks \
  lutris \
  heroic-games-launcher \
  gamemode \
  mangohud lib32-mangohud \
  vulkan-tools \
  mesa lib32-mesa \
  vulkan-radeon lib32-vulkan-radeon

# ProtonUp-Qt
echo "[5/7] Installing ProtonUp-Qt..."
sudo pacman -S --needed --noconfirm protonup-qt

# Useful apps
echo "[6/7] Installing useful apps..."
sudo pacman -S --needed --noconfirm \
  discord \
  obs-studio \
  vlc \
  qbittorrent \
  flameshot \
  gparted

# Fonts
echo "[7/7] Installing fonts..."
sudo pacman -S --needed --noconfirm \
  ttf-liberation \
  ttf-dejavu \
  noto-fonts \
  noto-fonts-emoji

# yay + Brave
echo "[8/7] Installing yay + Brave..."
if ! command -v yay &>/dev/null; then
  echo "yay not found. Installing yay..."
  cd /tmp
  rm -rf yay || true
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
fi

yay -S --noconfirm brave-bin

# Enable GameMode
sudo systemctl enable --now gamemoded.service || true

echo ""
echo "=========================================="
echo "DONE. AMD Gaming Setup is ready!"
echo "Next steps:"
echo "1) Open Steam → Settings → Compatibility → Enable Steam Play for all titles"
echo "2) Run ProtonUp-Qt and install Proton-GE"
echo "Go crush some games, bro. 💪"
echo "=========================================="
