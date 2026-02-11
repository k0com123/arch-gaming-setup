#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
  echo "💀 Don't run as root, dumbass."
  exit 1
fi

echo "=== AMD GAMING SETUP FOR ARCH ==="

echo "[1/9] Enabling multilib..."
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
  sudo pacman -Sy --noconfirm
fi

echo "[2/9] Updating system..."
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Syu --noconfirm

echo "[3/9] Installing base tools..."
sudo pacman -S --needed --noconfirm git curl wget unzip zip nano vim base-devel \
  htop btop fastfetch neofetch python python-pip ntfs-3g

echo "[4/9] Installing audio..."
sudo pacman -S --needed --noconfirm pipewire pipewire-alsa pipewire-pulse \
  wireplumber alsa-utils pavucontrol

echo "[5/9] Installing gaming shit..."
sudo pacman -S --needed --noconfirm steam wine winetricks lutris gamemode \
  mangohud lib32-mangohud vulkan-tools mesa lib32-mesa vulkan-radeon \
  lib32-vulkan-radeon

echo "[6/9] Installing fonts..."
sudo pacman -S --needed --noconfirm ttf-liberation ttf-dejavu noto-fonts \
  noto-fonts-emoji

echo "[7/9] Installing yay..."
if ! command -v yay &>/dev/null; then
  pushd "$(mktemp -d)" > /dev/null
  git clone https://aur.archlinux.org/yay.git
  cd yay
  echo "⚠️  If this stops, type 'y' to confirm dependencies"
  makepkg -si --noconfirm || true
  popd > /dev/null
fi

echo "[8/9] Installing AUR shit..."
yay -S brave-bin heroic-games-launcher protonup-qt

echo "[9/9] Setting up gamemode..."
sudo systemctl enable --now gamemoded.service 2>/dev/null || true
if ! groups "$USER" | grep -q gamemode; then
  sudo usermod -aG gamemode "$USER"
  echo "⚠️  Logout and login again for gamemode to work."
fi

echo ""
echo "✅ Done, you're ready to waste time."
echo ""
echo "Next:"
echo "1) Steam -> Settings -> Compatibility -> Enable Steam Play"
echo "2) Open ProtonUp-Qt -> Install Proton-GE"
echo "3) Logout and login again"
echo "4) GameMode? Use 'gamemoderun %command%' in Steam launch options"
echo ""
echo "Now go touch grass or whatever. 🎮"
