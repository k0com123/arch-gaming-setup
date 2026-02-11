#!/usr/bin/env bash
set -euo pipefail

# Check root
if [[ "$EUID" -eq 0 ]]; then
  echo "💀 Stop running as root, you stupid."
  exit 1
fi

echo "=== AMD GAMING SETUP FOR ARCH ==="

# 1️⃣ Update pacman and keyring
echo "[1/8] Updating system..."
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Syu --noconfirm

# 2️⃣ Install base tools
echo "[2/8] Installing base tools..."
sudo pacman -S --needed git curl wget unzip zip nano vim base-devel \
  htop btop fastfetch neofetch python python-pip ntfs-3g

# 3️⃣ Audio
echo "[3/8] Installing audio tools..."
sudo pacman -S --needed pipewire pipewire-alsa pipewire-pulse wireplumber \
  alsa-utils pavucontrol

# 4️⃣ Gaming core (Steam, Wine, Lutris, AMD Vulkan)
echo "[4/8] Installing gaming core..."
sudo pacman -S --needed steam wine winetricks lutris gamemode mangohud lib32-mangohud \
  vulkan-tools mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon

# 5️⃣ Fonts
echo "[5/8] Installing fonts..."
sudo pacman -S --needed ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji

# 6️⃣ AUR helper yay
echo "[6/8] Installing yay (AUR helper)..."
if ! command -v yay &>/dev/null; then
  cd /tmp
  rm -rf yay
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si
fi

# 7️⃣ Install AUR packages (Brave, Heroic, ProtonUp-Qt)
echo "[7/8] Installing Brave, Heroic, ProtonUp-Qt..."
yay -S brave-bin heroic-games-launcher protonup-qt --noconfirm

# 8️⃣ Enable GameMode
echo "[8/8] Enabling GameMode..."
sudo systemctl enable --now gamemoded.service || true

echo ""
echo "✅ AMD Gaming Setup done!"
echo "Next steps:"
echo "1) Steam → Settings → Compatibility → Enable Steam Play"
echo "2) Run ProtonUp-Qt → Install Proton-GE"
echo "3) Go play some games! 💪"
