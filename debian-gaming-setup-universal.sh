#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║          DEBIAN GAMING SETUP — UNIVERSAL EDITION          ║
# ║          Modular Architecture | Containerized & Native Support         ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';        BOLD='\033[1m';  NC='\033[0m'

# ── Logging & Backups ────────────────────────────────────────────────────────
LOG_FILE="$HOME/debian-gaming-setup-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="$HOME/.local/share/debian-gaming-backups/$(date +%Y%m%d-%H%M%S)"

# ── Helpers ──────────────────────────────────────────────────────────────────
ok()    { echo -e "  ${GREEN}✓${NC}  $1"; }
info()  { echo -e "  ${CYAN}→${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "  ${RED}✗${NC}  $1"; }
step()  { echo -e "\n  ${MAGENTA}▶${NC}  ${BOLD}$1${NC}"; }

# ── Error Handling ───────────────────────────────────────────────────────────
error_handler() {
    local exit_code=$1
    local line_no=$2
    local command="$3"
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}${BOLD}  ❌ ERROR: Command failed at line $line_no${NC}"
        echo -e "  ${RED}Command: ${NC} $command"
        exit "$exit_code"
    fi
}
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
trap 'echo -e "\n${YELLOW}  ⚠ Interrupted.${NC}"; exit 1' SIGINT SIGTERM

exec > >(tee -a "$LOG_FILE") 2>&1

print_section() {
    echo -e "\n${BLUE}  ┌───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC}  ${YELLOW}${BOLD}$1${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────────────────────┘${NC}"
}

backup_file() {
    if [[ -f "$1" ]]; then
        mkdir -p "$BACKUP_DIR$(dirname "$1")"
        sudo cp "$1" "$BACKUP_DIR$1" || warn "Could not backup $1"
    fi
}

confirm() {
    echo -ne "\n  ${YELLOW}$1 ${WHITE}[y/N]${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ── Detection ────────────────────────────────────────────────────────────────
detect_system() {
    print_section "System Detection"

    if [[ ! -f /etc/os-release ]]; then fail "Cannot detect OS: /etc/os-release missing"; exit 1; fi
    source /etc/os-release
    DISTRO_NAME=$PRETTY_NAME
    ID_LOWER=${ID,,}
    ID_LIKE_LOWER=${ID_LIKE,,}
    DISTRO_BASE="debian"
    PKG_MGR="apt"

    if [[ "$ID_LOWER" == "pikaos" ]]; then DISTRO_BASE="pikaos";
    elif [[ "$ID_LOWER" == "vanilla" ]]; then DISTRO_BASE="vanillaos"; PKG_MGR="apx";
    elif [[ "$ID_LOWER" == "ubuntu" ]] || echo "$ID_LIKE_LOWER" | grep -q "ubuntu"; then DISTRO_BASE="ubuntu"; fi

    GPU_LIST=$(lspci 2>/dev/null | grep -iE "vga|3d|display")
    if echo "$GPU_LIST" | grep -qi "nvidia"; then GPU_VENDOR="nvidia";
    elif echo "$GPU_LIST" | grep -qi "amd\|radeon"; then GPU_VENDOR="amd";
    elif echo "$GPU_LIST" | grep -qi "intel.*arc"; then GPU_VENDOR="intel_arc";
    else GPU_VENDOR="intel_igp"; fi

    CPU_INFO=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    [[ "$CPU_INFO" =~ "AMD" ]] && CPU_VENDOR="amd" || CPU_VENDOR="intel"
    RAM_GB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))

    echo -e "  ${CYAN}OS      :${NC} $DISTRO_NAME"
    echo -e "  ${CYAN}GPU     :${NC} $GPU_VENDOR"
    echo -e "  ${CYAN}CPU     :${NC} $CPU_INFO"
    echo -e "  ${CYAN}RAM     :${NC} ${RAM_GB}GB"

    if [[ "$DISTRO_BASE" == "pikaos" ]]; then ok "PikaOS detected: Already optimized. Exiting."; exit 0; fi
}

# ── Phases ───────────────────────────────────────────────────────────────────
phase_system_prep() {
    print_section "System Preparation"
    backup_file "/etc/apt/sources.list"

    if [[ "$DISTRO_BASE" == "debian" ]]; then
        step "Enabling contrib/non-free..."
        sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
    fi

    sudo $PKG_MGR update -qq || fail "Update failed"
    sudo dpkg --add-architecture i386
    sudo $PKG_MGR update -qq
}

phase_drivers() {
    print_section "Hardware Drivers"
    case "$GPU_VENDOR" in
        amd) sudo $PKG_MGR install -y mesa-vulkan-drivers libvulkan1 linux-firmware ;;
        nvidia)
            sudo $PKG_MGR install -y nvidia-driver nvidia-settings libvulkan1
            sudo systemctl enable nvidia-persistenced --now 2>/dev/null || true
            ;;
        intel_arc) sudo $PKG_MGR install -y intel-media-va-driver-non-free mesa-vulkan-drivers libvulkan1 ;;
    esac
}

phase_tweaks() {
    print_section "Performance Tweaks"
    
    sudo $PKG_MGR install -y zram-config || warn "ZRAM install failed"

    local SYS_FILE="/etc/sysctl.d/99-gaming.conf"
    backup_file "$SYS_FILE"
    sudo tee "$SYS_FILE" > /dev/null << EOF
vm.swappiness=10
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
kernel.perf_event_paranoid=-1
EOF
    sudo sysctl -p "$SYS_FILE" > /dev/null 2>&1 || warn "Could not apply sysctl"

    if [[ "$ADVANCED_MODE" == "true" ]]; then
        step "Installing Liquorix Kernel..."
        curl -s 'https://liquorix.net/install-liquorix.sh' | sudo bash || fail "Liquorix install failed"
        
        backup_file "/etc/default/grub"
        sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off nowatchdog"/' /etc/default/grub
        sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || warn "GRUB update failed"
    fi
}

phase_gamemode() {
    print_section "GameMode Configuration"
    sudo $PKG_MGR install -y gamemode || return 1
    sudo usermod -aG gamemode "$USER"
    
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/gamemode.ini" << EOF
[general]
reaper=yes
softrealtime=auto
renice=10
[cpu]
governor=performance
EOF
}

phase_gaming_container() {
    print_section "Gaming Stack (Distrobox Arch)"
    sudo $PKG_MGR install -y distrobox podman || { fail "Container tools failed"; return 1; }
    
    local C_NAME="gaming-arch"
    local C_HOME="$HOME/.local/share/distrobox/gaming-home"
    mkdir -p "$C_HOME"
    
    distrobox create --name "$C_NAME" --image archlinux:latest --home "$C_HOME" --yes || return 1
    distrobox enter "$C_NAME" -- sudo pacman -Syu --noconfirm || return 1
    distrobox enter "$C_NAME" -- sudo pacman -S --noconfirm steam mangohud gamemode lib32-mangohud lib32-gamemode || return 1
    distrobox enter "$C_NAME" -- sudo usermod -aG gamemode "$USER" 2>/dev/null || true
    distrobox enter "$C_NAME" -- distrobox-export --app steam || warn "Export failed"
}

# ── Main ─────────────────────────────────────────────────────────────────────
detect_system
if [[ $EUID -eq 0 ]]; then fail "Run as user, not root"; exit 1; fi

echo -e "\n  1) CONTAINERIZED (Distrobox Arch)  2) NATIVE (APT)"
read -p "  Choice [1]: " g_choice
[[ "$g_choice" == "2" ]] && G_MODE="native" || G_MODE="container"

echo -e "\n  1) SAFE  2) ADVANCED (Liquorix)"
read -p "  Choice [1]: " m_choice
[[ "$m_choice" == "2" ]] && ADVANCED_MODE=true || ADVANCED_MODE=false

if ! confirm "Start setup?"; then exit 0; fi

phase_system_prep
phase_drivers
phase_tweaks
phase_gamemode

if [[ "$G_MODE" == "container" ]]; then
    phase_gaming_container
else
    # Native Stack with Heroic Fallback
    sudo apt install -y steam mangohud lutris gamemode
    if ! sudo apt install -y heroic-games-launcher-bin 2>/dev/null; then
        info "Heroic not found in APT. Trying Flatpak..."
        if ! command -v flatpak &>/dev/null; then sudo apt install -y flatpak; fi
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        sudo flatpak install -y flathub com.heroicgameslauncher.hgl
    fi
fi

print_section "Complete"
ok "Debian ready for gaming. Reboot required."
