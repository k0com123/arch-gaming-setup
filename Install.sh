#!/usr/bin/env bash

# Wyjście przy błędzie, ale bez -u żeby nie walił się na unset variables
set -eo pipefail

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Sprawdź czy nie jesteś debilem
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}💀 Bro, don't run as root. What are you, Windows user?${NC}"
    exit 1
fi

clear
echo -e "${CYAN}"
cat << "EOF"
    ___              __   _____                      __                __
   /   | __  _______/ /  / ___/____  ___  ___  _____/ /_  ____ _____  / /
  / /| |/ / / / ___/ /   \__ \/ __ \/ _ \/ _ \/ ___/ __ \/ __ `/ __ \/ / 
 / ___ / /_/ (__  ) /   ___/ / /_/ /  __/  __/ /__/ / / / /_/ / /_/ / /  
/_/  |_\__, /____/_/   /____/ .___/\___/\___/\___/_/ /_/\__,_/ .___/_/   
      /____/               /_/                              /_/          
EOF
echo -e "${NC}"
echo -e "${YELLOW}Auto-detecting your shit...${NC}"
echo ""

# ==================== DETEKCJA VM ====================
detect_vm() {
    local vm_type=""
    
    # Sprawdź DMI
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        local vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
        
        [[ "$product" == *"VirtualBox"* ]] && vm_type="virtualbox"
        [[ "$product" == *"VMware"* ]] && vm_type="vmware"
        [[ "$vendor" == *"Microsoft"* ]] && vm_type="hyperv"
        [[ "$vendor" == *"QEMU"* ]] && vm_type="kvm"
    fi
    
    # Sprawdź CPU
    if [[ -z "$vm_type" ]] && grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        vm_type="vm"
    fi
    
    # systemd-detect-virt
    if command -v systemd-detect-virt &>/dev/null; then
        local sd=$(systemd-detect-virt 2>/dev/null || echo "none")
        [[ "$sd" != "none" ]] && vm_type="$sd"
    fi
    
    echo "$vm_type"
}

# ==================== DETEKCJA GPU ====================
detect_gpu() {
    local gpu=""
    
    # lspci jest najlepszy
    if command -v lspci &>/dev/null; then
        local vga=$(lspci -nnk 2>/dev/null | grep -iE "(vga|3d|display)" | head -1 | tr '[:upper:]' '[:lower:]')
        [[ "$vga" == *"nvidia"* ]] && gpu="nvidia"
        [[ "$vga" == *"amd"* ]] || [[ "$vga" == *"radeon"* ]] || [[ "$vga" == *"ati"* ]] && gpu="amd"
        [[ "$vga" == *"intel"* ]] && gpu="intel"
    fi
    
    # Fallback na vendor ID
    if [[ -z "$gpu" ]]; then
        for f in /sys/class/drm/card*/device/vendor; do
            [[ -f "$f" ]] || continue
            local vid=$(cat "$f" 2>/dev/null)
            case "$vid" in
                "0x10de") gpu="nvidia" ;;
                "0x1002") gpu="amd" ;;
                "0x8086") gpu="intel" ;;
            esac
            [[ -n "$gpu" ]] && break
        done
    fi
    
    echo "$gpu"
}

VM=$(detect_vm)
GPU=$(detect_gpu)

# ==================== RAPORT ====================
echo -e "${BLUE}=== SYSTEM REPORT ===${NC}"

if [[ -n "$VM" ]]; then
    echo -e "${YELLOW}🖥️  VM detected: $VM${NC}"
    echo -e "${YELLOW}    Good luck gaming on that toaster.${NC}"
    IS_VM=true
else
    echo -e "${GREEN}✓ Native hardware. Someone has standards.${NC}"
    IS_VM=false
fi

case "$GPU" in
    "nvidia") 
        echo -e "${GREEN}✓ GPU: NVIDIA${NC}"
        echo -e "${YELLOW}    Hope you like proprietary blobs breaking on updates.${NC}"
        ;;
    "amd")
        echo -e "${GREEN}✓ GPU: AMD${NC}"
        echo -e "${CYAN}    Based. The way God intended.${NC}"
        ;;
    "intel")
        echo -e "${GREEN}✓ GPU: Intel${NC}"
        echo -e "${RED}    Intel GPU? Bro... you okay financially?${NC}"
        ;;
    *)
        echo -e "${YELLOW}? Unknown GPU. YOLO mode activated.${NC}"
        GPU="unknown"
        ;;
esac

echo ""
read -p "Press Enter to continue or Ctrl+C to chicken out..."

# ==================== INSTALACJA ====================

echo ""
echo -e "${CYAN}[1/7] Enabling multilib...${NC}"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "Unlocking 32-bit packages..."
    sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
    sudo pacman -Sy --noconfirm || true
else
    echo "Already enabled. Moving on."
fi

echo ""
echo -e "${CYAN}[2/7] System update (this might take a while)...${NC}"
echo -e "${YELLOW}    If this hangs, blame your internet, not me.${NC}"
sudo pacman -Syu --noconfirm --disable-download-timeout || {
    echo -e "${RED}Update failed. Check your connection or mirrors.${NC}"
    exit 1
}

echo ""
echo -e "${CYAN}[3/7] Installing base tools...${NC}"

# Lista pakietów podzielona żeby nie było za długiego wiersza
BASE_PKGS="git curl wget unzip zip nano vim base-devel htop btop fastfetch neofetch python ntfs-3g"

# Instaluj pojedynczo żeby wiedzieć co się wysypuje
for pkg in $BASE_PKGS; do
    echo -n "  -> $pkg... "
    if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}SKIPPED (already there or broken)${NC}"
    fi
done

echo ""
echo -e "${CYAN}[4/7] Audio stack...${NC}"
AUDIO_PKGS="pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol"
for pkg in $AUDIO_PKGS; do
    echo -n "  -> $pkg... "
    sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP${NC}"
done

echo ""
echo -e "${CYAN}[5/7] GPU drivers...${NC}"

DRIVERS="mesa vulkan-icd-loader"

if [[ "$IS_VM" == true ]]; then
    echo -e "${YELLOW}VM mode: Open-source only.${NC}"
    case "$VM" in
        "kvm"|"qemu") DRIVERS+=" qemu-guest-agent spice-vdagent" ;;
        "vmware") DRIVERS+=" open-vm-tools xf86-video-vmware" ;;
        "virtualbox") DRIVERS+=" virtualbox-guest-utils" ;;
    esac
elif [[ "$GPU" == "amd" ]]; then
    echo -e "${GREEN}AMD stack incoming...${NC}"
    DRIVERS+=" vulkan-radeon xf86-video-amdgpu"
elif [[ "$GPU" == "nvidia" ]]; then
    echo -e "${YELLOW}NVIDIA proprietary shit...${NC}"
    DRIVERS+=" nvidia nvidia-utils nvidia-settings"
elif [[ "$GPU" == "intel" ]]; then
    echo -e "${CYAN}Intel (it is what it is)...${NC}"
    DRIVERS+=" vulkan-intel intel-media-driver"
fi

for pkg in $DRIVERS; do
    echo -n "  -> $pkg... "
    sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP${NC}"
done

echo ""
echo -e "${CYAN}[6/7] Gaming packages...${NC}"

GAMING="steam wine winetricks lutris gamemode mangohud"

# 32-bit libs tylko dla natywnego
if [[ "$IS_VM" == false ]]; then
    GAMING+=" lib32-mesa lib32-gamemode lib32-mangohud"
    [[ "$GPU" == "amd" ]] && GAMING+=" lib32-vulkan-radeon"
    [[ "$GPU" == "nvidia" ]] && GAMING+=" lib32-nvidia-utils"
    [[ "$GPU" == "intel" ]] && GAMING+=" lib32-vulkan-intel"
fi

for pkg in $GAMING; do
    echo -n "  -> $pkg... "
    sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP${NC}"
done

echo ""
echo -e "${CYAN}[7/7] Fonts...${NC}"
sudo pacman -S --needed --noconfirm ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji &>/dev/null || true
echo -e "${GREEN}Done.${NC}"

# ==================== YAY (opcjonalnie) ====================

echo ""
if command -v yay &>/dev/null; then
    echo -e "${GREEN}yay already installed. Nice.${NC}"
else
    echo -e "${CYAN}Installing yay (AUR helper)...${NC}"
    echo -e "${YELLOW}This will compile stuff. Go make coffee.${NC}"
    
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if git clone --depth 1 https://aur.archlinux.org/yay.git 2>/dev/null; then
        cd yay
        if makepkg -si --noconfirm 2>/dev/null; then
            echo -e "${GREEN}yay installed!${NC}"
        else
            echo -e "${YELLOW}yay failed. You'll live without it.${NC}"
        fi
    else
        echo -e "${RED}Can't clone yay. Internet dead?${NC}"
    fi
    
    cd ~
    rm -rf "$temp_dir"
fi

# ==================== POST-INSTALL ====================

echo ""
echo -e "${CYAN}Setting up services...${NC}"

sudo systemctl enable --now gamemoded 2>/dev/null || true

if ! groups "$USER" | grep -q gamemode; then
    sudo usermod -aG gamemode "$USER"
    echo -e "${YELLOW}Added to 'gamemode' group. LOG OUT AND BACK IN!${NC}"
fi

# VM services
[[ "$VM" == "kvm"* ]] && sudo systemctl enable --now qemu-guest-agent 2>/dev/null || true
[[ "$VM" == "vmware" ]] && sudo systemctl enable --now vmtoolsd 2>/dev/null || true
[[ "$VM" == "virtualbox" ]] && sudo systemctl enable --now vboxservice 2>/dev/null || true

# ==================== KONIEC ====================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DONE! (somehow it worked)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [[ "$IS_VM" == true ]]; then
    echo -e "${YELLOW}=== VM MODE ===${NC}"
    echo "Don't expect miracles. Software rendering only."
    echo "Playable: RetroArch, old emulators, pixel indies"
    echo "Forget about: Cyberpunk, AAA titles, ray tracing"
else
    echo -e "${GREEN}=== NATIVE ${GPU^^} MODE ===${NC}"
    echo ""
    echo "Next steps (actually do these):"
    echo "1) Steam -> Settings -> Compatibility -> Enable for all titles"
    [[ "$GPU" == "nvidia" ]] && echo "2) Run 'nvidia-settings' to disable that stupid logo"
    [[ "$GPU" == "amd" ]] && echo "2) Optional: Install 'corectrl' from AUR for tweaking"
    echo "3) Install Proton-GE (use ProtonUp-Qt or manually)"
    echo "4) LOG OUT AND BACK IN (for gamemode group)"
    echo "5) Launch options: gamemoderun %command% mangohud %command%"
    echo ""
    echo "Troubleshooting:"
    echo "  - Game won't start? Check ProtonDB"
    echo "  - Low FPS? Disable compositor, check mangohud"
    echo "  - Still broken? Cry and dual-boot Windows"
    echo "  - At this point contact me throug github
fi

echo ""
echo -e "${CYAN}Now go install Stardew Valley and call yourself a gamer. 🎮${NC}"
echo ""
