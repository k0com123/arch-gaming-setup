#!/usr/bin/env bash
set -euo pipefail

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [[ "$EUID" -eq 0 ]]; then
  echo -e "${RED}💀 Don't run as root, dumbass.${NC}"
  exit 1
fi

echo "=== AUTO-DETECT GAMING SETUP FOR ARCH ==="

# ==================== DETEKCJA VM ====================
detect_vm() {
  local vm_type=""
  
  # Sprawdź CPU flags
  if grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
    # Sprawdź czy to faktycznie VM, nie tylko wsparcie wirtualizacji
    if [[ -d /proc/xen ]] || [[ -f /proc/xen/capabilities ]]; then
      vm_type="xen"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
      vm_type="hypervisor"
    fi
  fi
  
  # Sprawdź DMI data (najbardziej niezawodne)
  if [[ -d /sys/class/dmi/id ]]; then
    local sys_vendor=""
    local product_name=""
    sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")
    product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
    
    case "$sys_vendor" in
      *"VMware"*) vm_type="vmware" ;;
      *"Microsoft Corporation"*) vm_type="hyperv" ;;
      *"innotek GmbH"*|*"Oracle"*) vm_type="virtualbox" ;;
      *"QEMU"*|*"KVM"*) vm_type="kvm/qemu" ;;
      *"Parallels"*) vm_type="parallels" ;;
      *"Xen"*) vm_type="xen" ;;
    esac
    
    # Dodatkowe sprawdzenie product name
    case "$product_name" in
      *"VirtualBox"*) vm_type="virtualbox" ;;
      *"VMware"*) vm_type="vmware" ;;
      *"KVM"*|*"QEMU"*) vm_type="kvm/qemu" ;;
    esac
  fi
  
  # Sprawdź systemd-detect-virt jeśli dostępne
  if command -v systemd-detect-virt &>/dev/null; then
    local virt_type=$(systemd-detect-virt 2>/dev/null || echo "none")
    if [[ "$virt_type" != "none" ]]; then
      vm_type="$virt_type"
    fi
  fi
  
  # Sprawdź czy dysk jest wirtualny
  if [[ -z "$vm_type" ]]; then
    local disk_model=$(cat /sys/class/block/sda/device/model 2>/dev/null || \
                       lsblk -d -o MODEL -n /dev/sda 2>/dev/null || echo "")
    if [[ "$disk_model" == *"VMware"* ]] || [[ "$disk_model" == *"VBOX"* ]] || \
       [[ "$disk_model" == *"QEMU"* ]]; then
      vm_type="vm"
    fi
  fi
  
  echo "$vm_type"
}

# ==================== DETEKCJA GPU ====================
detect_gpu() {
  local gpu_info=""
  local gpu_vendor=""
  
  # Spróbuj lspci (najbardziej niezawodne)
  if command -v lspci &>/dev/null; then
    gpu_info=$(lspci -nnk | grep -E "(VGA|3D|Display)" | head -n1)
  fi
  
  # Fallback do lshw
  if [[ -z "$gpu_info" ]] && command -v lshw &>/dev/null; then
    gpu_info=$(lshw -C display 2>/dev/null | grep "product:" | head -n1)
  fi
  
  # Sprawdź vendor ID
  if [[ -d /sys/class/drm ]]; then
    for card in /sys/class/drm/card*/device/vendor; do
      if [[ -f "$card" ]]; then
        local vendor_id=$(cat "$card" 2>/dev/null)
        case "$vendor_id" in
          "0x10de") gpu_vendor="nvidia" ;;
          "0x1002") gpu_vendor="amd" ;;
          "0x8086") gpu_vendor="intel" ;;
        esac
        [[ -n "$gpu_vendor" ]] && break
      fi
    done
  fi
  
  # Jeśli nie znalazł przez vendor ID, sprawdź nazwę
  if [[ -z "$gpu_vendor" ]]; then
    local gpu_lower=$(echo "$gpu_info" | tr '[:upper:]' '[:lower:]')
    if [[ "$gpu_lower" == *"nvidia"* ]]; then
      gpu_vendor="nvidia"
    elif [[ "$gpu_lower" == *"amd"* ]] || [[ "$gpu_lower" == *"ati"* ]] || \
         [[ "$gpu_lower" == *"radeon"* ]]; then
      gpu_vendor="amd"
    elif [[ "$gpu_lower" == *"intel"* ]]; then
      gpu_vendor="intel"
    fi
  fi
  
  echo "$gpu_vendor"
}

# ==================== GŁÓWNA LOGIKA ====================

VM_TYPE=$(detect_vm)
GPU_VENDOR=$(detect_gpu)

echo ""
echo -e "${BLUE}=== SYSTEM DETECTION ===${NC}"

if [[ -n "$VM_TYPE" ]]; then
  echo -e "${YELLOW}⚠️  Virtual Machine detected: $VM_TYPE${NC}"
  echo -e "${YELLOW}   -> Will use open-source drivers only${NC}"
  USE_OPENSOURCE=true
else
  echo -e "${GREEN}✓ Native hardware detected${NC}"
  USE_OPENSOURCE=false
fi

if [[ -n "$GPU_VENDOR" ]]; then
  echo -e "${GREEN}✓ GPU detected: ${GPU_VENDOR^^}${NC}"
else
  echo -e "${YELLOW}⚠️  Could not detect GPU, will install all open-source drivers${NC}"
  GPU_VENDOR="unknown"
fi

echo ""

# ==================== INSTALACJA ====================

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
  htop btop fastfetch neofetch python python-pip ntfs-3g lshw pciutils

echo "[4/9] Installing audio..."
sudo pacman -S --needed --noconfirm pipewire pipewire-alsa pipewire-pulse \
  wireplumber alsa-utils pavucontrol

# ==================== STEROWNIKI GPU ====================
echo "[5/9] Installing GPU drivers..."

# Pakiety bazowe dla wszystkich
GPU_PACKAGES="mesa lib32-mesa vulkan-tools"

if [[ "$USE_OPENSOURCE" == true ]] || [[ "$GPU_VENDOR" == "unknown" ]]; then
  # VM lub nieznany GPU = tylko open-source
  echo -e "${YELLOW}Installing open-source drivers (LLVMpipe/VirtIO/Standard)...${NC}"
  
  case "$VM_TYPE" in
    "kvm"|"qemu"|"kvm/qemu")
      GPU_PACKAGES+=" qemu-guest-agent spice-vdagent xf86-video-qxl"
      ;;
    "vmware")
      GPU_PACKAGES+=" open-vm-tools xf86-video-vmware"
      ;;
    "virtualbox")
      GPU_PACKAGES+=" virtualbox-guest-utils"
      ;;
    "hyperv")
      GPU_PACKAGES+=" hyperv"
      ;;
  esac
  
  # Dodaj wszystkie open-source sterowniki jako fallback
  GPU_PACKAGES+=" xf86-video-vesa xf86-video-fbdev"
  
elif [[ "$GPU_VENDOR" == "amd" ]]; then
  echo -e "${GREEN}Installing AMD drivers...${NC}"
  GPU_PACKAGES+=" vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu xf86-video-ati"
  
elif [[ "$GPU_VENDOR" == "nvidia" ]]; then
  echo -e "${GREEN}Installing NVIDIA drivers...${NC}"
  # Sprawdź czy to nowsza karta (Turing+) dla open kernel module
  GPU_PACKAGES+=" nvidia nvidia-utils lib32-nvidia-utils nvidia-settings"
  
  # Dla starszych kart dodaj legacy, ale to wymaga ręcznego wyboru
  echo -e "${YELLOW}Note: If you have older GPU (Kepler/Maxwell), install 'nvidia-470xx-dkms' from AUR${NC}"
  
elif [[ "$GPU_VENDOR" == "intel" ]]; then
  echo -e "${GREEN}Installing Intel drivers...${NC}"
  GPU_PACKAGES+=" vulkan-intel lib32-vulkan-intel xf86-video-intel intel-media-driver"
fi

sudo pacman -S --needed --noconfirm $GPU_PACKAGES || {
  echo -e "${RED}Failed to install some GPU packages, continuing with base...${NC}"
}

echo "[6/9] Installing gaming packages..."
# Pakiety gamingowe
GAMING_PACKAGES="steam wine winetricks lutris gamemode lib32-gamemode mangohud lib32-mangohud"

# Dodaj 32-bitowe vulkan dla wykrytego GPU (jeśli nie VM)
if [[ "$USE_OPENSOURCE" == false ]]; then
  case "$GPU_VENDOR" in
    "amd") GAMING_PACKAGES+=" vulkan-radeon lib32-vulkan-radeon" ;;
    "nvidia") GAMING_PACKAGES+=" nvidia-utils lib32-nvidia-utils" ;;
    "intel") GAMING_PACKAGES+=" vulkan-intel lib32-vulkan-intel" ;;
  esac
fi

sudo pacman -S --needed --noconfirm $GAMING_PACKAGES || true

echo "[7/9] Installing fonts..."
sudo pacman -S --needed --noconfirm ttf-liberation ttf-dejavu noto-fonts \
  noto-fonts-emoji ttf-ms-fonts 2>/dev/null || true

echo "[8/9] Installing yay..."
if ! command -v yay &>/dev/null; then
  pushd "$(mktemp -d)" > /dev/null
  git clone https://aur.archlinux.org/yay.git
  cd yay
  echo -e "${YELLOW}⚠️  If this stops, type 'y' to confirm dependencies${NC}"
  makepkg -si --noconfirm || true
  popd > /dev/null
fi

echo "[9/9] Installing AUR packages..."
# Zainstaluj tylko to co działa w danym środowisku
AUR_PACKAGES="brave-bin heroic-games-launcher-bin"

# ProtonUp-Qt może nie działać w VM bez GPU
if [[ "$USE_OPENSOURCE" == false ]]; then
  AUR_PACKAGES+=" protonup-qt"
else
  echo -e "${YELLOW}Skipping ProtonUp-Qt in VM (install manually if needed)${NC}"
fi

yay -S --needed --noconfirm $AUR_PACKAGES || true

# ==================== POST-INSTALL ====================

echo "[*] Setting up services..."

# Gamemode
sudo systemctl enable --now gamemoded.service 2>/dev/null || true
if ! groups "$USER" | grep -q gamemode; then
  sudo usermod -aG gamemode "$USER"
  echo -e "${YELLOW}⚠️  Logout and login again for gamemode group to take effect.${NC}"
fi

# VM-specific services
case "$VM_TYPE" in
  "kvm"|"qemu"|"kvm/qemu")
    sudo systemctl enable --now qemu-guest-agent 2>/dev/null || true
    ;;
  "vmware")
    sudo systemctl enable --now vmtoolsd 2>/dev/null || true
    ;;
  "virtualbox")
    sudo systemctl enable --now vboxservice 2>/dev/null || true
    ;;
esac

# ==================== PODSUMOWANIE ====================

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""

if [[ -n "$VM_TYPE" ]]; then
  echo -e "${YELLOW}=== VM MODE ACTIVE ===${NC}"
  echo "GPU Acceleration: Software rendering (LLVMpipe)"
  echo "Gaming performance will be limited."
  echo ""
  echo "For better performance in VM:"
  echo "1. Enable GPU passthrough (PCIe) if host supports it"
  echo "2. Use SPICE for remote display"
  echo "3. Increase video memory in VM settings"
else
  echo -e "${GREEN}=== NATIVE MODE ===${NC}"
  echo "GPU: ${GPU_VENDOR^^}"
  echo ""
  echo "Next steps:"
  echo "1) Steam -> Settings -> Compatibility -> Enable Steam Play"
  [[ "$GPU_VENDOR" == "nvidia" ]] && echo "2) Run 'nvidia-settings' to configure your GPU"
  [[ "$GPU_VENDOR" == "amd" ]] && echo "2) Consider installing 'corectrl' from AUR for GPU tuning"
  echo "3) Open ProtonUp-Qt -> Install Proton-GE"
  echo "4) Logout and login again"
  echo "5) Use 'gamemoderun %command%' in Steam launch options"
fi

echo ""
echo -e "${BLUE}Now go touch grass or whatever. 🎮${NC}"
