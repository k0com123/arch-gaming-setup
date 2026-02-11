#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Arch Linux Gaming Setup – AMD Edition
# ==========================================

# Root check
if [[ "$EUID" -eq 0 ]]; then
  echo "💀 Bro, why the hell are you running this as root?"
  echo "You are stupid. Stop it. Run as normal user with sudo, gah damn."
  exit 1
fi

echo "=== AMD GAMING SETUP FOR ARCH ==="
echo "Updating system first..."
sudo pacman -Syu --noconfirm

# Base tools
echo "[1/7] Installing base tools..."
sudo pacman -S --noconfirm --needed \
  git curl wget unzip zip nano vim base-devel \
  htop btop fastfetch neofetch \
  python python-pip \
  ntfs-3g

# Audio
echo "[2/7] Installing audio (PipeWire)..."
sudo pacman -S --noconfirm --needed \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  alsa-utils pavucontrol

# Gaming core
echo "[3/7] Installing gaming core (Steam, Wine, Lutris, Heroic)..."
sudo pacman -S --noconfirm --needed \
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
echo "[4/7] Installing ProtonUp-Qt (Proton-GE)..."
sudo pacman -S --noconfirm --needed protonup-qt

# Useful apps
echo "[5/7] Installing useful apps..."
sudo pacman -S --noconfirm --needed \
  discord \
  obs-studio \
  vlc \
  qbittorrent \
  flameshot \
  gparted

# Fonts
echo "[6/7] Installing fonts (Wine-friendly)..."
sudo pacman -S --noconfirm --needed \
  ttf-liberation \
  ttf-dejavu \
  noto-fonts \
  noto-fonts-emoji

# yay + Brave
echo "[7/7] Installing yay + Brave..."
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
