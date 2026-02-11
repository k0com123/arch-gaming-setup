#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Arch Linux Gaming Setup – AMD Edition
# Fully working version
# ==========================================

# Root check
if [[ "$EUID" -eq 0 ]]; then
  echo "💀 Bro, why the hell are you running this as root?"
  echo "You are stupid. Stop it. Run as normal user with sudo, gah damn."
  exit 1
fi

echo "=== AMD GAMING SETUP FOR ARCH ==="

# Ensure pacman keyring is initialized
echo "[0/8] Initializing pacman keys..."
sudo pacman-key --init
sudo pacman-key --populate archlinux

# Update system first
echo "[1/8] Updating system..."
sudo pacman -Syu --noconfirm

# Base tools
echo "[2/8] Installing base tools..."
sudo pacman -S --noconfirm --needed \
  git curl wget unzip zip nano vim base-devel \
  htop btop fastfetch neofetch \
  python python-pip \
  ntfs-3g

# Audio (PipeWire)
echo "[3/8] Installing audio tools..."
sudo pacman -S --noconfirm --needed \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  alsa-utils pavucontrol

# Gaming core (Steam, Wine, Lutris, Heroic, AMD Vulkan)
echo "[4/8] Installing gaming core..."
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
echo "[5/8] Installing ProtonUp-Qt..."
sudo pacman -S --noconfirm --needed protonup-qt

# Useful apps
echo "[6/8] Installing useful apps..."
sudo pacman -S --noconfirm --needed \
  discord \
  obs-studio \
  vlc \
  qbittorrent \
  flameshot \
  gparted

# Fonts
echo "[7/8] Installing fonts..."
sudo pacman -S --noconfirm --needed \
  ttf-liberation \
  ttf-dejavu \
  noto-fonts \
  noto-fonts-emoji

# yay + Brave
echo "[8/8] Installing yay + Brave..."
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
