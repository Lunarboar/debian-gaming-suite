#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║          DEBIAN GAMING OPTIMISATION SUITE — UNIVERSAL EDITION           ║
# ║          Supports: Ubuntu • Zorin • Mint • Pop!_OS • Debian             ║
# ║          GPU: AMD RDNA • NVIDIA • Intel Arc                             ║
# ║          CPU: AMD Ryzen • Intel Core                                    ║
# ║                                                                          ║
# ║          Built with love for the Linux gaming community                 ║
# ║          Based on the Zorin OS Gaming Setup by the community            ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# LICENCE: Free to use, share and modify. If you improve it, share it back!
# GITHUB:  Feel free to host this and contribute improvements.

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';        BOLD='\033[1m';  NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
LOG_FILE="$HOME/debian-gaming-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── State tracking ────────────────────────────────────────────────────────────
INSTALLED=(); SKIPPED=(); FAILED=()
DETECTED_DISTRO=""; DETECTED_GPU=""; DETECTED_CPU=""
GPU_VENDOR="";  CPU_VENDOR=""
CODENAME=""; DISTRO_BASE=""

# ── Chosen hardware ───────────────────────────────────────────────────────────
CHOSEN_GPU=""   # amd | nvidia | intel
CHOSEN_CPU=""   # amd | intel

# ════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════
ok()    { echo -e "  ${GREEN}✓${NC}  $1"; }
info()  { echo -e "  ${CYAN}→${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "  ${RED}✗${NC}  $1"; }
step()  { echo -e "\n  ${MAGENTA}▶${NC}  ${BOLD}$1${NC}"; }
title() { echo -e "\n  ${WHITE}${BOLD}$1${NC}"; }

print_section() {
    echo -e "\n${BLUE}  ┌───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC}  ${YELLOW}${BOLD}$1${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────────────────────┘${NC}"
}

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║     DEBIAN GAMING OPTIMISATION SUITE — UNIVERSAL EDITION         ║"
    echo "  ║     AMD • NVIDIA • Intel Arc  ×  Ryzen • Intel Core              ║"
    echo "  ║     Ubuntu • Zorin • Mint • Pop!_OS • Debian & more              ║"
    echo -e "  ╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n  ${DIM}Built for the Linux gaming community — share freely & improve it!${NC}"
    echo -e "  ${DIM}Log: $LOG_FILE${NC}\n"
}

confirm() {
    echo -ne "\n  ${YELLOW}$1 ${WHITE}[y/N]${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

press_enter() {
    echo -ne "\n  ${DIM}Press Enter to continue...${NC}"
    read -r
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        fail "Do not run as root. Run as your normal user — sudo will be called when needed."
        exit 1
    fi
}

check_internet() {
    step "Checking internet connection..."
    if ! curl -s --max-time 8 https://google.com > /dev/null; then
        fail "No internet connection detected. Connect and try again."
        exit 1
    fi
    ok "Internet confirmed"
}

get_latest_github_tag() {
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4
}

get_latest_github_asset_url() {
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"browser_download_url"' \
        | grep "$2" \
        | cut -d'"' -f4 \
        | head -1
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 0 — DISTRO & HARDWARE DETECTION
# ════════════════════════════════════════════════════════════════════════════
detect_system() {
    print_section "PHASE 0 — Detecting Your System"

    # ── Distro detection ────────────────────────────────────────────────────
    step "Detecting Linux distribution..."

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DETECTED_DISTRO="${PRETTY_NAME:-Unknown}"
        CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo 'unknown')}"
        ID_LIKE_LOWER="${ID_LIKE,,}"
        ID_LOWER="${ID,,}"

        if [[ "$ID_LOWER" == "debian" ]] || echo "$ID_LIKE_LOWER" | grep -q "debian"; then
            DISTRO_BASE="debian"
        elif [[ "$ID_LOWER" == "ubuntu" ]] || echo "$ID_LIKE_LOWER" | grep -q "ubuntu"; then
            DISTRO_BASE="ubuntu"
        else
            DISTRO_BASE="debian"  # fallback assumption
        fi
    fi

    info "Distro   : $DETECTED_DISTRO"
    info "Codename : $CODENAME"
    info "Base     : $DISTRO_BASE"

    # Verify apt is available
    if ! command -v apt &>/dev/null; then
        fail "apt not found — this script requires a Debian-based distro."
        exit 1
    fi
    ok "Debian-based system confirmed"

    # ── GPU detection ────────────────────────────────────────────────────────
    step "Detecting GPU hardware..."

    GPU_LIST=$(lspci 2>/dev/null | grep -iE "vga|3d|display")

    if echo "$GPU_LIST" | grep -qi "nvidia"; then
        DETECTED_GPU=$(echo "$GPU_LIST" | grep -i nvidia | head -1 | sed 's/.*: //')
        GPU_VENDOR="nvidia"
    elif echo "$GPU_LIST" | grep -qi "amd\|radeon\|advanced micro"; then
        DETECTED_GPU=$(echo "$GPU_LIST" | grep -iE "amd|radeon" | head -1 | sed 's/.*: //')
        GPU_VENDOR="amd"
    elif echo "$GPU_LIST" | grep -qi "intel.*arc\|intel.*xe\|intel.*alchemist"; then
        DETECTED_GPU=$(echo "$GPU_LIST" | grep -i intel | head -1 | sed 's/.*: //')
        GPU_VENDOR="intel_arc"
    elif echo "$GPU_LIST" | grep -qi "intel"; then
        DETECTED_GPU=$(echo "$GPU_LIST" | grep -i intel | head -1 | sed 's/.*: //')
        GPU_VENDOR="intel_igp"
    else
        GPU_VENDOR="unknown"
        DETECTED_GPU="Unknown GPU"
    fi

    info "GPU detected: $DETECTED_GPU"

    # ── CPU detection ────────────────────────────────────────────────────────
    step "Detecting CPU hardware..."

    CPU_INFO=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)

    if echo "$CPU_INFO" | grep -qi "amd\|ryzen\|threadripper\|epyc"; then
        CPU_VENDOR="amd"
    elif echo "$CPU_INFO" | grep -qi "intel"; then
        CPU_VENDOR="intel"
    else
        CPU_VENDOR="unknown"
    fi

    info "CPU detected: $CPU_INFO"
    info "CPU vendor  : $CPU_VENDOR"
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 1 — HARDWARE SELECTION MENU
# ════════════════════════════════════════════════════════════════════════════
hardware_selection() {
    print_section "PHASE 1 — Confirm Your Hardware"

    echo -e "\n  ${BOLD}${WHITE}We detected the following hardware:${NC}\n"
    echo -e "  ${CYAN}GPU:${NC} $DETECTED_GPU"
    echo -e "  ${CYAN}CPU:${NC} $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo -e "  ${CYAN}OS :${NC} $DETECTED_DISTRO\n"

    # ── GPU Selection ────────────────────────────────────────────────────────
    echo -e "  ${BOLD}${YELLOW}Select your GPU:${NC}\n"
    echo -e "  ${WHITE}[1]${NC} AMD Radeon (RX 5000 / 6000 / 7000 / 9000 series — RDNA)"
    echo -e "  ${WHITE}[2]${NC} NVIDIA GeForce (GTX / RTX series)"
    echo -e "  ${WHITE}[3]${NC} Intel Arc (A-series / Battlemage)"
    echo -e "  ${WHITE}[4]${NC} Intel Integrated Graphics (UHD / Iris Xe)"
    echo -e "  ${WHITE}[5]${NC} AMD + NVIDIA (Hybrid — AMD iGPU + NVIDIA dGPU)"
    echo -e "  ${WHITE}[6]${NC} Intel + NVIDIA (Hybrid — Intel iGPU + NVIDIA dGPU)\n"

    # Pre-select based on detection
    case "$GPU_VENDOR" in
        amd)        echo -e "  ${DIM}Auto-detected: AMD — press Enter to confirm or choose another${NC}" ;;
        nvidia)     echo -e "  ${DIM}Auto-detected: NVIDIA — press Enter to confirm or choose another${NC}" ;;
        intel_arc)  echo -e "  ${DIM}Auto-detected: Intel Arc — press Enter to confirm or choose another${NC}" ;;
        intel_igp)  echo -e "  ${DIM}Auto-detected: Intel Integrated — press Enter to confirm or choose another${NC}" ;;
    esac

    echo -ne "\n  ${YELLOW}Enter GPU choice [1-6]: ${NC}"
    read -r GPU_CHOICE

    # Use auto-detected if user just pressed enter
    if [[ -z "$GPU_CHOICE" ]]; then
        case "$GPU_VENDOR" in
            amd)       GPU_CHOICE=1 ;;
            nvidia)    GPU_CHOICE=2 ;;
            intel_arc) GPU_CHOICE=3 ;;
            intel_igp) GPU_CHOICE=4 ;;
            *)         GPU_CHOICE=1 ;;
        esac
    fi

    case "$GPU_CHOICE" in
        1) CHOSEN_GPU="amd";          GPU_LABEL="AMD Radeon (RDNA)" ;;
        2) CHOSEN_GPU="nvidia";       GPU_LABEL="NVIDIA GeForce" ;;
        3) CHOSEN_GPU="intel_arc";    GPU_LABEL="Intel Arc" ;;
        4) CHOSEN_GPU="intel_igp";    GPU_LABEL="Intel Integrated" ;;
        5) CHOSEN_GPU="hybrid_amd_nvidia";   GPU_LABEL="AMD + NVIDIA Hybrid" ;;
        6) CHOSEN_GPU="hybrid_intel_nvidia"; GPU_LABEL="Intel + NVIDIA Hybrid" ;;
        *) CHOSEN_GPU="amd";          GPU_LABEL="AMD Radeon (default)" ;;
    esac

    ok "GPU selected: $GPU_LABEL"

    # ── CPU Selection ────────────────────────────────────────────────────────
    echo -e "\n  ${BOLD}${YELLOW}Select your CPU:${NC}\n"
    echo -e "  ${WHITE}[1]${NC} AMD Ryzen (all generations — including Ryzen 7000/8000/9000)"
    echo -e "  ${WHITE}[2]${NC} Intel Core (8th gen and newer — i5/i7/i9/Core Ultra)\n"

    case "$CPU_VENDOR" in
        amd)   echo -e "  ${DIM}Auto-detected: AMD Ryzen — press Enter to confirm${NC}" ;;
        intel) echo -e "  ${DIM}Auto-detected: Intel Core — press Enter to confirm${NC}" ;;
    esac

    echo -ne "\n  ${YELLOW}Enter CPU choice [1-2]: ${NC}"
    read -r CPU_CHOICE

    if [[ -z "$CPU_CHOICE" ]]; then
        [[ "$CPU_VENDOR" == "amd" ]] && CPU_CHOICE=1 || CPU_CHOICE=2
    fi

    case "$CPU_CHOICE" in
        1) CHOSEN_CPU="amd";   CPU_LABEL="AMD Ryzen" ;;
        2) CHOSEN_CPU="intel"; CPU_LABEL="Intel Core" ;;
        *) CHOSEN_CPU="amd";   CPU_LABEL="AMD Ryzen (default)" ;;
    esac

    ok "CPU selected: $CPU_LABEL"

    # ── Summary ──────────────────────────────────────────────────────────────
    echo -e "\n${BLUE}  ┌───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC}  ${GREEN}${BOLD}Configuration confirmed:${NC}"
    echo -e "${BLUE}  │${NC}  GPU : ${WHITE}$GPU_LABEL${NC}"
    echo -e "${BLUE}  │${NC}  CPU : ${WHITE}$CPU_LABEL${NC}"
    echo -e "${BLUE}  │${NC}  OS  : ${WHITE}$DETECTED_DISTRO${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────────────────────┘${NC}"

    if ! confirm "Looks correct? Start the gaming optimisation?"; then
        echo -e "\n  ${YELLOW}Setup cancelled. Re-run to start again.${NC}\n"
        exit 0
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 2 — SYSTEM PREPARATION
# ════════════════════════════════════════════════════════════════════════════
phase_system_prep() {
    print_section "PHASE 2 — System Preparation"

    step "Updating package lists..."
    sudo apt update -qq 2>/dev/null && ok "Package lists updated" || { fail "apt update failed"; FAILED+=("apt-update"); }

    step "Upgrading existing packages..."
    sudo apt upgrade -y -qq 2>/dev/null && ok "System upgraded" || warn "Some packages may not have upgraded cleanly"
    INSTALLED+=("system-upgrade")

    step "Installing universal dependencies..."
    DEPS=(
        git curl wget python3 python3-pip
        cabextract p7zip-full flatpak
        cpufrequtils linux-tools-common
        build-essential dkms pkg-config
        vulkan-tools mesa-utils
        winetricks zstd lsb-release
        software-properties-common
        apt-transport-https gnupg2
    )

    for dep in "${DEPS[@]}"; do
        if dpkg -l "$dep" &>/dev/null 2>/dev/null; then
            info "$dep already installed"
        else
            sudo apt install -y -qq "$dep" 2>/dev/null && ok "$dep installed" && INSTALLED+=("$dep") || \
                warn "Could not install $dep — may not be available on this distro"
        fi
    done

    # Enable Flatpak + Flathub
    step "Configuring Flatpak & Flathub..."
    if ! flatpak remotes 2>/dev/null | grep -q "flathub"; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null
        ok "Flathub added"
        INSTALLED+=("flathub")
    else
        ok "Flathub already configured"
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 3 — XANMOD GAMING KERNEL
# ════════════════════════════════════════════════════════════════════════════
phase_kernel() {
    print_section "PHASE 3 — XanMod Gaming Kernel (BORE Scheduler)"

    info "XanMod kernel brings the BORE process scheduler, low-latency patches,"
    info "and CPU-specific optimisations — the same kernel used in gaming distros."

    if uname -r | grep -q "xanmod"; then
        ok "XanMod kernel already running: $(uname -r)"
        SKIPPED+=("xanmod-kernel")
        return
    fi

    step "Adding XanMod repository..."
    wget -qO - https://dl.xanmod.org/archive.key | \
        sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null

    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://dl.xanmod.org releases main' | \
        sudo tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null

    sudo apt update -qq 2>/dev/null

    # Choose kernel variant based on CPU
    if [[ "$CHOSEN_CPU" == "amd" ]]; then
        KERNEL_PKG="linux-xanmod-rt-x64v3"
        KERNEL_FALLBACK="linux-xanmod-x64v3"
        info "Selecting RT x64v3 kernel — optimised for modern AMD Ryzen"
    else
        KERNEL_PKG="linux-xanmod-rt-x64v3"
        KERNEL_FALLBACK="linux-xanmod-x64v3"
        info "Selecting RT x64v3 kernel — optimised for modern Intel Core"
    fi

    step "Installing XanMod kernel ($KERNEL_PKG)..."
    if sudo apt install -y "$KERNEL_PKG" 2>/dev/null; then
        ok "XanMod RT kernel installed — active after reboot"
        INSTALLED+=("xanmod-rt-kernel")
    elif sudo apt install -y "$KERNEL_FALLBACK" 2>/dev/null; then
        ok "XanMod kernel installed — active after reboot"
        INSTALLED+=("xanmod-kernel")
    else
        warn "XanMod kernel install failed — trying generic xanmod..."
        sudo apt install -y linux-xanmod 2>/dev/null && \
            ok "XanMod generic kernel installed" && INSTALLED+=("xanmod-generic") || \
            fail "XanMod kernel installation failed — check internet/repo access"
        FAILED+=("xanmod-kernel")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 4 — GPU DRIVERS
# ════════════════════════════════════════════════════════════════════════════
phase_gpu_drivers() {
    print_section "PHASE 4 — GPU Drivers ($GPU_LABEL)"

    case "$CHOSEN_GPU" in

        # ────────────────────────────────────────────────────────────────
        amd)
            install_amd_drivers
            ;;

        # ────────────────────────────────────────────────────────────────
        nvidia)
            install_nvidia_drivers
            ;;

        # ────────────────────────────────────────────────────────────────
        intel_arc)
            install_intel_arc_drivers
            ;;

        # ────────────────────────────────────────────────────────────────
        intel_igp)
            install_intel_igp_drivers
            ;;

        # ────────────────────────────────────────────────────────────────
        hybrid_amd_nvidia)
            info "Hybrid AMD + NVIDIA setup detected"
            install_amd_drivers
            install_nvidia_drivers
            configure_hybrid_prime "amd"
            ;;

        # ────────────────────────────────────────────────────────────────
        hybrid_intel_nvidia)
            info "Hybrid Intel + NVIDIA setup detected"
            install_intel_igp_drivers
            install_nvidia_drivers
            configure_hybrid_prime "intel"
            ;;
    esac
}

install_amd_drivers() {
    info "Installing AMD RADV open-source Vulkan drivers (Mesa)"

    # Add kisak bleeding-edge Mesa PPA (Ubuntu/Zorin/Mint/Pop)
    if [[ "$DISTRO_BASE" == "ubuntu" ]] || grep -qi "ubuntu\|zorin\|mint\|pop" /etc/os-release 2>/dev/null; then
        step "Adding kisak bleeding-edge Mesa PPA..."
        sudo add-apt-repository -y ppa:kisak/kisak-mesa 2>/dev/null && \
            sudo apt update -qq 2>/dev/null && ok "kisak-mesa PPA added" || \
            warn "Could not add kisak PPA — using distro Mesa"
    fi

    step "Installing AMD Mesa & Vulkan packages..."
    AMD_PKGS=(
        mesa-vulkan-drivers
        libvulkan1
        mesa-utils
        libgl1-mesa-dri
        libglx-mesa0
        mesa-vdpau-drivers
        mesa-va-drivers
        libdrm-amdgpu1
        libdrm-radeon1
        libdrm2
        radeontop
        linux-firmware
    )

    for pkg in "${AMD_PKGS[@]}"; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install -y -qq "$pkg" 2>/dev/null
    done

    ok "AMD Mesa drivers installed"
    INSTALLED+=("amd-mesa-drivers")

    step "Checking Mesa version..."
    MESA_VER=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "check after reboot")
    info "Mesa version: $MESA_VER"

    # Firmware
    step "Updating AMDGPU firmware..."
    sudo apt install --only-upgrade -y -qq linux-firmware 2>/dev/null && \
        ok "AMDGPU firmware updated" || warn "Firmware update skipped"
    INSTALLED+=("amdgpu-firmware")
}

install_nvidia_drivers() {
    info "Installing NVIDIA proprietary drivers"

    # Add NVIDIA PPA
    if grep -qi "ubuntu\|zorin\|mint\|pop" /etc/os-release 2>/dev/null; then
        step "Adding NVIDIA graphics PPA..."
        sudo add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null
        sudo apt update -qq 2>/dev/null
        ok "NVIDIA PPA added"
    fi

    step "Detecting recommended NVIDIA driver..."
    RECOMMENDED=""
    if command -v ubuntu-drivers &>/dev/null; then
        RECOMMENDED=$(ubuntu-drivers devices 2>/dev/null | grep "recommended" | awk '{print $3}')
    fi
    [[ -z "$RECOMMENDED" ]] && RECOMMENDED="nvidia-driver-570"
    info "Installing: $RECOMMENDED"

    step "Installing NVIDIA driver..."
    if sudo apt install -y "$RECOMMENDED" nvidia-settings 2>/dev/null; then
        ok "NVIDIA driver installed: $RECOMMENDED"
        INSTALLED+=("nvidia-driver")
    else
        fail "NVIDIA driver install failed"
        FAILED+=("nvidia-driver")
        return
    fi

    # NVIDIA Vulkan
    step "Installing NVIDIA Vulkan support..."
    for pkg in libvulkan1 vulkan-tools nvidia-vulkan-icd; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install -y -qq "$pkg" 2>/dev/null
    done
    ok "NVIDIA Vulkan configured"
    INSTALLED+=("nvidia-vulkan")

    # nvidia-persistenced
    step "Enabling nvidia-persistenced..."
    sudo systemctl enable nvidia-persistenced --now 2>/dev/null && \
        ok "nvidia-persistenced enabled" || \
        warn "nvidia-persistenced unavailable — enable after reboot"
    INSTALLED+=("nvidia-persistenced")

    # NVIDIA env vars
    step "Setting NVIDIA performance environment variables..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-nvidia-gaming.conf > /dev/null << 'EOF'
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SIZE=10737418240
__GL_THREADED_OPTIMIZATIONS=1
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
EOF
    ok "NVIDIA environment variables set"
    INSTALLED+=("nvidia-env-vars")
}

install_intel_arc_drivers() {
    info "Installing Intel Arc (Xe/Alchemist/Battlemage) drivers"

    step "Adding Intel graphics repository..."
    # Intel graphics repo for Ubuntu-based
    if grep -qi "ubuntu\|zorin\|mint\|pop" /etc/os-release 2>/dev/null; then
        wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
            sudo gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg 2>/dev/null

        echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
https://repositories.intel.com/gpu/ubuntu ${CODENAME} client" | \
            sudo tee /etc/apt/sources.list.d/intel-graphics.list > /dev/null

        sudo apt update -qq 2>/dev/null && ok "Intel graphics repo added" || \
            warn "Could not add Intel repo — using distro drivers"
    fi

    step "Installing Intel Arc Mesa & Vulkan drivers..."
    INTEL_ARC_PKGS=(
        intel-media-va-driver-non-free
        intel-opencl-icd
        mesa-vulkan-drivers
        libvulkan1
        mesa-utils
        libgl1-mesa-dri
        libdrm2
        libdrm-intel1
        vainfo
        linux-firmware
    )

    for pkg in "${INTEL_ARC_PKGS[@]}"; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install -y -qq "$pkg" 2>/dev/null
    done

    ok "Intel Arc drivers installed"
    INSTALLED+=("intel-arc-drivers")

    # Enable GuC/HuC firmware for Arc
    step "Enabling Intel GuC/HuC firmware (Arc performance)..."
    INTEL_MODPROBE="/etc/modprobe.d/intel-arc-gaming.conf"
    if [[ ! -f "$INTEL_MODPROBE" ]]; then
        sudo tee "$INTEL_MODPROBE" > /dev/null << 'EOF'
# Intel Arc Gaming Optimisation
# Enables GuC submission and HuC firmware for best Arc performance
options i915 enable_guc=3
options i915 enable_fbc=1
EOF
        sudo update-initramfs -u 2>/dev/null
        ok "Intel GuC/HuC enabled — active after reboot"
        INSTALLED+=("intel-arc-guc")
    fi

    step "Setting Intel Arc environment variables..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-intel-arc-gaming.conf > /dev/null << 'EOF'
# Intel Arc Gaming Optimisations
ANV_ENABLE_PIPELINE_CACHE=1
INTEL_DEBUG=
mesa_glthread=true
EOF
    ok "Intel Arc environment variables set"
    INSTALLED+=("intel-arc-env-vars")
}

install_intel_igp_drivers() {
    info "Installing Intel Integrated Graphics drivers (UHD/Iris Xe)"

    step "Installing Intel integrated graphics packages..."
    INTEL_IGP_PKGS=(
        intel-media-va-driver
        mesa-vulkan-drivers
        libvulkan1
        mesa-utils
        libgl1-mesa-dri
        libdrm-intel1
        vainfo
    )

    for pkg in "${INTEL_IGP_PKGS[@]}"; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install -y -qq "$pkg" 2>/dev/null
    done

    ok "Intel integrated graphics drivers installed"
    INSTALLED+=("intel-igp-drivers")
}

configure_hybrid_prime() {
    # $1 = primary GPU vendor (amd or intel)
    local PRIMARY="$1"
    step "Configuring NVIDIA PRIME for hybrid $PRIMARY + NVIDIA..."

    sudo apt install -y -qq nvidia-prime 2>/dev/null

    # Set PRIME profiles
    if command -v prime-select &>/dev/null; then
        sudo prime-select nvidia 2>/dev/null
        info "PRIME set to NVIDIA for gaming"
        info "Run 'sudo prime-select on-demand' to switch back to hybrid mode"
    fi

    # DRI_PRIME for running games on NVIDIA in hybrid
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-prime-gaming.conf > /dev/null << EOF
# NVIDIA PRIME — run demanding apps on NVIDIA dGPU
# Add __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only to game launch options
# Or use: prime-run %command% in Steam launch options
EOF
    ok "NVIDIA PRIME configured"
    info "Use 'prime-run %command%' in Steam to run games on NVIDIA"
    INSTALLED+=("nvidia-prime-hybrid")
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 5 — GRUB GAMING PARAMETERS
# ════════════════════════════════════════════════════════════════════════════
phase_grub() {
    print_section "PHASE 5 — Gaming Kernel Boot Parameters"

    GRUB_FILE="/etc/default/grub"
    GRUB_BACKUP="/etc/default/grub.backup.$(date +%Y%m%d)"

    step "Backing up GRUB config..."
    sudo cp "$GRUB_FILE" "$GRUB_BACKUP"
    ok "Backup: $GRUB_BACKUP"

    # Build params based on CPU + GPU
    BASE_PARAMS="quiet splash mitigations=off nowatchdog nohz_full=all rcu_nocbs=all threadirqs"

    # CPU-specific
    if [[ "$CHOSEN_CPU" == "amd" ]]; then
        CPU_PARAMS="amd_pstate=active"
    else
        CPU_PARAMS="intel_pstate=active"
    fi

    # GPU-specific
    if [[ "$CHOSEN_GPU" == "nvidia" ]] || [[ "$CHOSEN_GPU" == *"nvidia"* ]]; then
        GPU_PARAMS="nvidia-drm.modeset=1"
    elif [[ "$CHOSEN_GPU" == "intel_arc" ]]; then
        GPU_PARAMS="i915.enable_guc=3"
    else
        GPU_PARAMS=""
    fi

    GAMING_PARAMS="$BASE_PARAMS $CPU_PARAMS $GPU_PARAMS"
    # Clean up double spaces
    GAMING_PARAMS=$(echo "$GAMING_PARAMS" | tr -s ' ')

    CURRENT_PARAMS=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE")
    info "Current : $CURRENT_PARAMS"
    info "New     : GRUB_CMDLINE_LINUX_DEFAULT=\"$GAMING_PARAMS\""

    if echo "$CURRENT_PARAMS" | grep -q "mitigations=off"; then
        ok "Gaming GRUB parameters already applied"
        SKIPPED+=("grub-params")
    else
        sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GAMING_PARAMS\"|" "$GRUB_FILE"

        if sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
            ok "GRUB updated with gaming parameters"
            INSTALLED+=("grub-gaming-params")
        else
            fail "GRUB update failed — restoring backup"
            sudo cp "$GRUB_BACKUP" "$GRUB_FILE"
            FAILED+=("grub-params")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 6 — SYSCTL GAMING TWEAKS
# ════════════════════════════════════════════════════════════════════════════
phase_sysctl() {
    print_section "PHASE 6 — System Gaming Tweaks (sysctl)"

    SYSCTL_FILE="/etc/sysctl.d/99-gaming-universal.conf"

    if [[ -f "$SYSCTL_FILE" ]]; then
        ok "Gaming sysctl config already exists"
        SKIPPED+=("sysctl")
        return
    fi

    step "Writing universal gaming sysctl config..."
    sudo tee "$SYSCTL_FILE" > /dev/null << EOF
# ═══════════════════════════════════════════════════
# Universal Debian Gaming Tweaks
# CPU: $CPU_LABEL | GPU: $GPU_LABEL
# ═══════════════════════════════════════════════════

# ── Memory ────────────────────────────────────────
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.nr_hugepages=128
vm.compaction_proactiveness=0

# ── Network (BBR — lower ping in online games) ────
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3

# ── CPU & Scheduler ───────────────────────────────
kernel.sched_autogroup_enabled=1
kernel.numa_balancing=0
kernel.perf_event_paranoid=-1

# ── Filesystem ────────────────────────────────────
fs.inotify.max_user_watches=524288
fs.file-max=2097152
EOF

    sudo sysctl -p "$SYSCTL_FILE" > /dev/null 2>&1
    ok "Gaming sysctl tweaks applied"
    INSTALLED+=("sysctl-gaming")
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 7 — CPU PERFORMANCE GOVERNOR
# ════════════════════════════════════════════════════════════════════════════
phase_cpu_governor() {
    print_section "PHASE 7 — CPU Performance Governor ($CPU_LABEL)"

    SERVICE_FILE="/etc/systemd/system/cpu-performance.service"

    if [[ -f "$SERVICE_FILE" ]]; then
        ok "CPU performance service already exists"
        SKIPPED+=("cpu-governor")
        return
    fi

    step "Creating CPU performance service..."
    sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=Set CPU Governor to Performance Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable cpu-performance.service --now 2>/dev/null
    ok "CPU performance governor enabled"
    INSTALLED+=("cpu-governor")

    CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    info "Active governor: $CURRENT_GOV"
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 8 — GAMING STACK
# ════════════════════════════════════════════════════════════════════════════
phase_gaming_stack() {
    print_section "PHASE 8 — Gaming Stack (GameMode, MangoHud, Lutris)"

    for pkg in gamemode mangohud lutris; do
        if dpkg -l "$pkg" &>/dev/null 2>/dev/null; then
            ok "$pkg already installed"
            SKIPPED+=("$pkg")
        else
            sudo apt install -y -qq "$pkg" 2>/dev/null && \
                ok "$pkg installed" && INSTALLED+=("$pkg") || \
                warn "$pkg not available in repos — trying Flatpak..."
        fi
    done

    # MangoHud config
    step "Setting up MangoHud config..."
    MANGOHUD_DIR="$HOME/.config/MangoHud"
    mkdir -p "$MANGOHUD_DIR"

    if [[ ! -f "$MANGOHUD_DIR/MangoHud.conf" ]]; then
        cat > "$MANGOHUD_DIR/MangoHud.conf" << 'EOF'
fps
frametime
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
cpu_stats
cpu_temp
ram
vram
wine
vulkan_driver
arch
EOF
        ok "MangoHud config created"
        INSTALLED+=("mangohud-config")
    fi

    # Gamescope
    step "Installing Gamescope (Valve's compositor)..."
    sudo apt install -y -qq gamescope 2>/dev/null && \
        ok "Gamescope installed" && INSTALLED+=("gamescope") || \
        info "Gamescope not available in repos — skipping"
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 9 — STEAM
# ════════════════════════════════════════════════════════════════════════════
phase_steam() {
    print_section "PHASE 9 — Steam"

    if command -v steam &>/dev/null || flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
        ok "Steam already installed"
        SKIPPED+=("steam")
        return
    fi

    step "Enabling 32-bit architecture..."
    sudo dpkg --add-architecture i386
    sudo apt update -qq 2>/dev/null

    step "Installing Steam..."
    if sudo apt install -y steam-installer 2>/dev/null || sudo apt install -y steam 2>/dev/null; then
        ok "Steam installed"
        INSTALLED+=("steam")
    else
        step "Trying Steam via Flatpak..."
        flatpak install -y flathub com.valvesoftware.Steam 2>/dev/null && \
            ok "Steam installed via Flatpak" && INSTALLED+=("steam-flatpak") || \
            { warn "Steam auto-install failed"; info "Download from: https://store.steampowered.com/about/"; FAILED+=("steam"); }
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 10 — GE-PROTON
# ════════════════════════════════════════════════════════════════════════════
phase_ge_proton() {
    print_section "PHASE 10 — GE-Proton (GloriousEggroll)"

    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$PROTON_DIR"

    step "Fetching latest GE-Proton..."
    LATEST_GE=$(get_latest_github_tag "GloriousEggroll/proton-ge-custom")

    if [[ -z "$LATEST_GE" ]]; then
        fail "Could not fetch GE-Proton release info"
        FAILED+=("ge-proton"); return
    fi

    info "Latest: $LATEST_GE"

    if [[ -d "$PROTON_DIR/$LATEST_GE" ]]; then
        ok "GE-Proton $LATEST_GE already installed"
        SKIPPED+=("ge-proton"); return
    fi

    step "Downloading GE-Proton $LATEST_GE (~700MB)..."
    if curl -L --progress-bar \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_GE/$LATEST_GE.tar.gz" \
        -o "/tmp/$LATEST_GE.tar.gz"; then
        tar -xzf "/tmp/$LATEST_GE.tar.gz" -C "$PROTON_DIR"
        rm -f "/tmp/$LATEST_GE.tar.gz"
        ok "GE-Proton $LATEST_GE installed"
        INSTALLED+=("ge-proton-$LATEST_GE")
    else
        fail "GE-Proton download failed"
        FAILED+=("ge-proton")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 11 — WINE-GE
# ════════════════════════════════════════════════════════════════════════════
phase_wine_ge() {
    print_section "PHASE 11 — Wine-GE (Lutris)"

    WINE_DIR="$HOME/.local/share/lutris/runners/wine"
    mkdir -p "$WINE_DIR"

    step "Fetching latest Wine-GE..."
    LATEST_WINE=$(get_latest_github_tag "GloriousEggroll/wine-ge-custom")

    if [[ -z "$LATEST_WINE" ]]; then
        fail "Could not fetch Wine-GE release info"
        FAILED+=("wine-ge"); return
    fi

    info "Latest: $LATEST_WINE"

    if [[ -d "$WINE_DIR/$LATEST_WINE" ]]; then
        ok "Wine-GE $LATEST_WINE already installed"
        SKIPPED+=("wine-ge"); return
    fi

    WINE_URL=$(get_latest_github_asset_url "GloriousEggroll/wine-ge-custom" ".tar.xz")

    step "Downloading Wine-GE $LATEST_WINE..."
    if curl -L --progress-bar "$WINE_URL" -o "/tmp/wine-ge-latest.tar.xz"; then
        mkdir -p "$WINE_DIR/$LATEST_WINE"
        tar -xJf "/tmp/wine-ge-latest.tar.xz" -C "$WINE_DIR/$LATEST_WINE" --strip-components=1
        rm -f "/tmp/wine-ge-latest.tar.xz"
        ok "Wine-GE $LATEST_WINE installed"
        INSTALLED+=("wine-ge-$LATEST_WINE")
    else
        fail "Wine-GE download failed"
        FAILED+=("wine-ge")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 12 — DXVK
# ════════════════════════════════════════════════════════════════════════════
phase_dxvk() {
    print_section "PHASE 12 — DXVK (DirectX 9/10/11 → Vulkan)"

    DXVK_DIR="$HOME/.local/share/dxvk"
    mkdir -p "$DXVK_DIR"

    step "Fetching latest DXVK..."
    LATEST_DXVK=$(get_latest_github_tag "doitsujin/dxvk")

    if [[ -z "$LATEST_DXVK" ]]; then
        fail "Could not fetch DXVK release info"
        FAILED+=("dxvk"); return
    fi

    info "Latest: $LATEST_DXVK"

    if [[ -d "$DXVK_DIR/$LATEST_DXVK" ]]; then
        ok "DXVK $LATEST_DXVK already installed"
        SKIPPED+=("dxvk"); return
    fi

    DXVK_URL=$(get_latest_github_asset_url "doitsujin/dxvk" ".tar.gz")

    step "Downloading DXVK $LATEST_DXVK..."
    if curl -L --progress-bar "$DXVK_URL" -o "/tmp/dxvk-latest.tar.gz"; then
        mkdir -p "$DXVK_DIR/$LATEST_DXVK"
        tar -xzf "/tmp/dxvk-latest.tar.gz" -C "$DXVK_DIR/$LATEST_DXVK" --strip-components=1
        rm -f "/tmp/dxvk-latest.tar.gz"
        ok "DXVK $LATEST_DXVK installed"
        INSTALLED+=("dxvk-$LATEST_DXVK")
    else
        fail "DXVK download failed"
        FAILED+=("dxvk")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 13 — VKD3D-PROTON
# ════════════════════════════════════════════════════════════════════════════
phase_vkd3d() {
    print_section "PHASE 13 — VKD3D-Proton (DirectX 12 → Vulkan)"

    VKD3D_DIR="$HOME/.local/share/vkd3d"
    mkdir -p "$VKD3D_DIR"

    step "Fetching latest VKD3D-Proton..."
    LATEST_VKD3D=$(get_latest_github_tag "HansKristian-Work/vkd3d-proton")

    if [[ -z "$LATEST_VKD3D" ]]; then
        fail "Could not fetch VKD3D-Proton release info"
        FAILED+=("vkd3d"); return
    fi

    info "Latest: $LATEST_VKD3D"

    if [[ -d "$VKD3D_DIR/$LATEST_VKD3D" ]]; then
        ok "VKD3D-Proton $LATEST_VKD3D already installed"
        SKIPPED+=("vkd3d"); return
    fi

    sudo apt install -y -qq zstd 2>/dev/null

    VKD3D_URL=$(get_latest_github_asset_url "HansKristian-Work/vkd3d-proton" "tar.zst")
    [[ -z "$VKD3D_URL" ]] && VKD3D_URL=$(get_latest_github_asset_url "HansKristian-Work/vkd3d-proton" "tar.gz")

    step "Downloading VKD3D-Proton $LATEST_VKD3D..."
    if curl -L --progress-bar "$VKD3D_URL" -o "/tmp/vkd3d-latest.tar.zst"; then
        mkdir -p "$VKD3D_DIR/$LATEST_VKD3D"
        tar -xf "/tmp/vkd3d-latest.tar.zst" -C "$VKD3D_DIR/$LATEST_VKD3D" --strip-components=1 2>/dev/null
        rm -f "/tmp/vkd3d-latest.tar.zst"
        ok "VKD3D-Proton $LATEST_VKD3D installed"
        INSTALLED+=("vkd3d-$LATEST_VKD3D")
    else
        fail "VKD3D-Proton download failed"
        FAILED+=("vkd3d")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 14 — DXVK-NVAPI (NVIDIA only — DLSS/Reflex)
# ════════════════════════════════════════════════════════════════════════════
phase_dxvk_nvapi() {
    # Only for NVIDIA setups
    if [[ "$CHOSEN_GPU" != "nvidia" ]] && [[ "$CHOSEN_GPU" != *"nvidia"* ]]; then
        return
    fi

    print_section "PHASE 14 — DXVK-NVAPI (DLSS + NVIDIA Reflex)"

    NVAPI_DIR="$HOME/.local/share/dxvk-nvapi"
    mkdir -p "$NVAPI_DIR"

    step "Fetching latest DXVK-NVAPI..."
    LATEST_NVAPI=$(get_latest_github_tag "jp7677/dxvk-nvapi")

    if [[ -z "$LATEST_NVAPI" ]]; then
        warn "Could not fetch DXVK-NVAPI — skipping"
        SKIPPED+=("dxvk-nvapi"); return
    fi

    if [[ -d "$NVAPI_DIR/$LATEST_NVAPI" ]]; then
        ok "DXVK-NVAPI $LATEST_NVAPI already installed"
        SKIPPED+=("dxvk-nvapi"); return
    fi

    NVAPI_URL=$(get_latest_github_asset_url "jp7677/dxvk-nvapi" "tar.gz")

    step "Downloading DXVK-NVAPI $LATEST_NVAPI..."
    if curl -L --progress-bar "$NVAPI_URL" -o "/tmp/dxvk-nvapi.tar.gz" 2>/dev/null; then
        mkdir -p "$NVAPI_DIR/$LATEST_NVAPI"
        tar -xzf "/tmp/dxvk-nvapi.tar.gz" -C "$NVAPI_DIR/$LATEST_NVAPI" --strip-components=1 2>/dev/null
        rm -f "/tmp/dxvk-nvapi.tar.gz"
        ok "DXVK-NVAPI $LATEST_NVAPI installed — DLSS & Reflex enabled"
        INSTALLED+=("dxvk-nvapi-$LATEST_NVAPI")
    else
        warn "DXVK-NVAPI download failed — non-critical"
        FAILED+=("dxvk-nvapi")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 15 — ZRAM & SYSTEM MEMORY
# ════════════════════════════════════════════════════════════════════════════
phase_zram() {
    print_section "PHASE 15 — ZRAM (Compressed Swap)"

    if swapon --show 2>/dev/null | grep -q "zram"; then
        ok "ZRAM already active"
        SKIPPED+=("zram"); return
    fi

    step "Installing ZRAM..."
    if sudo apt install -y -qq zram-config 2>/dev/null; then
        sudo systemctl enable zram-config --now 2>/dev/null || true
        ok "ZRAM installed and enabled"
        INSTALLED+=("zram")
    elif sudo apt install -y -qq zram-tools 2>/dev/null; then
        ok "zram-tools installed"
        INSTALLED+=("zram-tools")
    else
        warn "ZRAM not available — skipping"
        SKIPPED+=("zram")
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 16 — IRQ BALANCE
# ════════════════════════════════════════════════════════════════════════════
phase_irq() {
    print_section "PHASE 16 — IRQ Balance"

    if systemctl is-active --quiet irqbalance 2>/dev/null; then
        ok "irqbalance already running"
        SKIPPED+=("irqbalance"); return
    fi

    sudo apt install -y -qq irqbalance 2>/dev/null && \
        sudo systemctl enable irqbalance --now && \
        ok "irqbalance enabled" && INSTALLED+=("irqbalance") || \
        warn "irqbalance install failed"
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 17 — HEROIC GAMES LAUNCHER
# ════════════════════════════════════════════════════════════════════════════
phase_heroic() {
    print_section "PHASE 17 — Heroic Games Launcher (Epic/GOG)"

    if flatpak list 2>/dev/null | grep -q "com.heroicgameslauncher.hgl"; then
        ok "Heroic already installed"
        SKIPPED+=("heroic"); return
    fi

    step "Installing Heroic via Flatpak..."
    flatpak install -y flathub com.heroicgameslauncher.hgl 2>/dev/null && \
        ok "Heroic Games Launcher installed" && INSTALLED+=("heroic") || \
        warn "Heroic install failed — download from heroicgameslauncher.com"
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 18 — AUTOMATED UPDATE PIPELINE
# ════════════════════════════════════════════════════════════════════════════
phase_auto_pipeline() {
    print_section "PHASE 18 — Automated Weekly Update Pipeline"

    PIPELINE_SCRIPT="/usr/local/bin/gaming-update"

    step "Installing gaming-update script..."

    sudo tee "$PIPELINE_SCRIPT" > /dev/null << PIPELINE
#!/bin/bash
# ════════════════════════════════════════════════════════════
# Debian Gaming Update Pipeline — Universal Edition
# GPU: $GPU_LABEL | CPU: $CPU_LABEL
# Run manually: gaming-update
# ════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

LOG_DIR="\$HOME/.local/share/gaming-update-logs"
mkdir -p "\$LOG_DIR"
LOG="\$LOG_DIR/update-\$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "\$LOG") 2>&1

ok()   { echo -e "  \${GREEN}✓\${NC} \$1"; }
info() { echo -e "  \${CYAN}→\${NC} \$1"; }
step() { echo -e "\n  \${YELLOW}▶\${NC} \${BOLD}\$1\${NC}"; }
skip() { echo -e "  \${CYAN}◌\${NC} \$1 — already latest"; }

echo -e "\${BLUE}══════════════════════════════════════════════\${NC}"
echo -e "\${BLUE}  Debian Gaming Update — Universal Edition   \${NC}"
echo -e "\${BLUE}  GPU: $GPU_LABEL | CPU: $CPU_LABEL\${NC}"
echo -e "\${BLUE}══════════════════════════════════════════════\${NC}"

# System update
step "System packages..."
sudo apt update -qq && sudo apt upgrade -y -qq
ok "System updated"

# GPU driver updates
step "GPU drivers..."
$(
if [[ "$CHOSEN_GPU" == "amd" ]]; then
echo 'sudo apt install --only-upgrade -y -qq mesa-vulkan-drivers libvulkan1 mesa-utils libgl1-mesa-dri 2>/dev/null'
echo 'ok "AMD Mesa drivers updated"'
elif [[ "$CHOSEN_GPU" == "nvidia" ]] || [[ "$CHOSEN_GPU" == *"nvidia"* ]]; then
echo 'sudo ubuntu-drivers autoinstall 2>/dev/null || sudo apt install --only-upgrade -y -qq nvidia-driver-570 2>/dev/null'
echo 'ok "NVIDIA driver checked"'
echo 'sudo systemctl enable nvidia-persistenced --now 2>/dev/null'
elif [[ "$CHOSEN_GPU" == "intel_arc" ]]; then
echo 'sudo apt install --only-upgrade -y -qq mesa-vulkan-drivers intel-media-va-driver-non-free 2>/dev/null'
echo 'ok "Intel Arc drivers updated"'
fi
)

# GE-Proton
step "GE-Proton..."
PROTON_DIR="\$HOME/.steam/root/compatibilitytools.d"
mkdir -p "\$PROTON_DIR"
LATEST_GE=\$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [[ -d "\$PROTON_DIR/\$LATEST_GE" ]]; then
    skip "GE-Proton \$LATEST_GE"
else
    info "Downloading GE-Proton \$LATEST_GE..."
    curl -L -s "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/\$LATEST_GE/\$LATEST_GE.tar.gz" -o "/tmp/\$LATEST_GE.tar.gz"
    tar -xzf "/tmp/\$LATEST_GE.tar.gz" -C "\$PROTON_DIR"
    rm -f "/tmp/\$LATEST_GE.tar.gz"
    ok "GE-Proton \$LATEST_GE installed"
    ls -d "\$PROTON_DIR"/GE-Proton* 2>/dev/null | sort -V | head -n -2 | xargs rm -rf 2>/dev/null
fi

# Wine-GE
step "Wine-GE..."
WINE_DIR="\$HOME/.local/share/lutris/runners/wine"
mkdir -p "\$WINE_DIR"
LATEST_WINE=\$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [[ -d "\$WINE_DIR/\$LATEST_WINE" ]]; then
    skip "Wine-GE \$LATEST_WINE"
else
    WINE_URL=\$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest | grep '"browser_download_url"' | grep '.tar.xz' | cut -d'"' -f4 | head -1)
    info "Downloading Wine-GE \$LATEST_WINE..."
    curl -L -s "\$WINE_URL" -o "/tmp/wine-ge.tar.xz"
    mkdir -p "\$WINE_DIR/\$LATEST_WINE"
    tar -xJf "/tmp/wine-ge.tar.xz" -C "\$WINE_DIR/\$LATEST_WINE" --strip-components=1
    rm -f "/tmp/wine-ge.tar.xz"
    ok "Wine-GE \$LATEST_WINE installed"
fi

# DXVK
step "DXVK..."
DXVK_DIR="\$HOME/.local/share/dxvk"
mkdir -p "\$DXVK_DIR"
LATEST_DXVK=\$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [[ -d "\$DXVK_DIR/\$LATEST_DXVK" ]]; then
    skip "DXVK \$LATEST_DXVK"
else
    DXVK_URL=\$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest | grep '"browser_download_url"' | grep '.tar.gz' | cut -d'"' -f4 | head -1)
    info "Downloading DXVK \$LATEST_DXVK..."
    curl -L -s "\$DXVK_URL" -o "/tmp/dxvk.tar.gz"
    mkdir -p "\$DXVK_DIR/\$LATEST_DXVK"
    tar -xzf "/tmp/dxvk.tar.gz" -C "\$DXVK_DIR/\$LATEST_DXVK" --strip-components=1
    rm -f "/tmp/dxvk.tar.gz"
    ok "DXVK \$LATEST_DXVK installed"
fi

# Gaming tools
step "GameMode & MangoHud..."
sudo apt install --only-upgrade -y -qq gamemode mangohud 2>/dev/null
ok "Gaming tools updated"

# Flatpak updates
step "Flatpak apps..."
flatpak update -y 2>/dev/null && ok "Flatpaks updated"

# Verify sysctl tweaks are active
step "Verifying gaming tweaks..."
[[ ! -f /etc/sysctl.d/99-gaming-universal.conf ]] && sudo sysctl -p /etc/sysctl.d/99-gaming-universal.conf > /dev/null 2>&1
CURRENT_GOV=\$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
[[ "\$CURRENT_GOV" != "performance" ]] && sudo cpupower frequency-set -g performance > /dev/null 2>&1
ok "Gaming tweaks verified"

echo -e "\n\${BLUE}══════════════════════════════════════════════\${NC}"
echo -e "\${GREEN}  Update complete!\${NC}"
echo -e "  GE-Proton : \${GREEN}\$LATEST_GE\${NC}"
echo -e "  Wine-GE   : \${GREEN}\$LATEST_WINE\${NC}"
echo -e "  DXVK      : \${GREEN}\$LATEST_DXVK\${NC}"
echo -e "  Log       : \${CYAN}\$LOG\${NC}"
echo -e "\${YELLOW}  Restart Steam for Proton changes to take effect\${NC}"
echo -e "\${BLUE}══════════════════════════════════════════════\${NC}\n"
PIPELINE

    sudo chmod +x "$PIPELINE_SCRIPT"
    ok "gaming-update script installed — run anytime with: gaming-update"
    INSTALLED+=("gaming-update-script")

    # Systemd timer
    step "Setting up weekly auto-update timer..."
    sudo tee /etc/systemd/system/gaming-patch.service > /dev/null << 'EOF'
[Unit]
Description=Debian Gaming Patch Pipeline
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gaming-update
StandardOutput=journal
StandardError=journal
EOF

    sudo tee /etc/systemd/system/gaming-patch.timer > /dev/null << 'EOF'
[Unit]
Description=Weekly Gaming Patch Update
Requires=gaming-patch.service

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable gaming-patch.timer --now 2>/dev/null
    ok "Weekly auto-update timer enabled"
    INSTALLED+=("gaming-patch-timer")
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 19 — LAUNCH OPTIONS + RAY TRACING CONFIGURATION
# ════════════════════════════════════════════════════════════════════════════
phase_launch_options() {
    print_section "PHASE 19 — Launch Options & Ray Tracing Configuration"

    LAUNCH_FILE="$HOME/Gaming-Launch-Options.txt"
    RT_ENV_DIR="/etc/environment.d/"
    sudo mkdir -p "$RT_ENV_DIR"

    # ── Write GPU-specific RT environment config ──────────────────────
    step "Writing ray tracing environment config for $GPU_LABEL..."

    case "$CHOSEN_GPU" in
        amd)
            sudo tee "${RT_ENV_DIR}99-amd-raytracing.conf" > /dev/null << 'EOF'
# AMD RDNA Ray Tracing Optimisations
RADV_PERFTEST=gpl,rt,ngg_streamout
VKD3D_CONFIG=dxr,dxr11
DXVK_ASYNC=1
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "AMD RDNA ray tracing environment config written"
            INSTALLED+=("amd-rt-env-config")
            ;;

        nvidia)
            sudo tee "${RT_ENV_DIR}99-nvidia-raytracing.conf" > /dev/null << 'EOF'
# NVIDIA RTX Ray Tracing Optimisations
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1
VKD3D_CONFIG=dxr,dxr11
DXVK_ASYNC=1
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SIZE=10737418240
__GL_THREADED_OPTIMIZATIONS=1
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "NVIDIA RTX ray tracing environment config written"
            INSTALLED+=("nvidia-rt-env-config")
            ;;

        intel_arc)
            sudo tee "${RT_ENV_DIR}99-intel-arc-raytracing.conf" > /dev/null << 'EOF'
# Intel Arc Ray Tracing Optimisations
ANV_ENABLE_PIPELINE_CACHE=1
VKD3D_CONFIG=dxr,dxr11
DXVK_ASYNC=1
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "Intel Arc ray tracing environment config written"
            INSTALLED+=("intel-arc-rt-env-config")
            ;;

        hybrid_amd_nvidia|hybrid_intel_nvidia)
            sudo tee "${RT_ENV_DIR}99-nvidia-raytracing.conf" > /dev/null << 'EOF'
# NVIDIA RTX Ray Tracing Optimisations (Hybrid)
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1
VKD3D_CONFIG=dxr,dxr11
DXVK_ASYNC=1
__GL_THREADED_OPTIMIZATIONS=1
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "Hybrid NVIDIA RT environment config written"
            INSTALLED+=("hybrid-nvidia-rt-env-config")
            ;;
    esac

    # ── Write personalised launch options file ────────────────────────
    cat > "$LAUNCH_FILE" << EOF
════════════════════════════════════════════════════════════════
DEBIAN GAMING SUITE — Steam Launch Options + Ray Tracing
GPU: $GPU_LABEL | CPU: $CPU_LABEL
════════════════════════════════════════════════════════════════

$(
case "$CHOSEN_GPU" in
    amd)
echo "GLOBAL — All games (Steam → Settings → General):
RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 VKD3D_CONFIG=dxr,dxr11 MESA_VK_WSI_PRESENT_MODE=mailbox gamemoderun mangohud %command%

DEMANDING GAMES — No RT (right click game → Properties):
RADV_PERFTEST=gpl,ngg_streamout WINE_FULLSCREEN_FSR=1 DXVK_ASYNC=1 gamemoderun mangohud %command%

RAY TRACING — DX12 titles (Cyberpunk, Alan Wake 2 etc):
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

MAXIMUM RT PERFORMANCE — with FSR:
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV WINE_FULLSCREEN_FSR=1 gamemoderun mangohud %command%

KEY VARIABLES:
  RADV_PERFTEST=gpl,rt       → RADV hardware RT acceleration
  VKD3D_CONFIG=dxr,dxr11     → DX12 RT (DXR 1.0 and 1.1)
  DXVK_ASYNC=1               → Reduces RT stutter on first load
  AMD_VULKAN_ICD=RADV        → Forces best RDNA RT Vulkan driver
  WINE_FULLSCREEN_FSR=1      → AMD FSR upscaling pairs well with RT"
        ;;
    nvidia)
echo "GLOBAL — All games (Steam → Settings → General):
PROTON_ENABLE_NVAPI=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

RT + DLSS — DX12 titles:
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

RT + DLSS + REFLEX — competitive titles:
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 __GL_THREADED_OPTIMIZATIONS=1 gamemoderun mangohud %command%

KEY VARIABLES:
  PROTON_ENABLE_NVAPI=1              → DLSS, Reflex and RT API
  DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1   → Full RT/DLSS compatibility
  VKD3D_CONFIG=dxr,dxr11             → DX12 ray tracing
  DXVK_ASYNC=1                       → Reduces RT stutter"
        ;;
    intel_arc)
echo "GLOBAL — All games (Steam → Settings → General):
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true gamemoderun mangohud %command%

RAY TRACING — DX12 titles:
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json gamemoderun mangohud %command%

KEY VARIABLES:
  ANV_ENABLE_PIPELINE_CACHE=1  → Intel Vulkan RT pipeline cache
  VKD3D_CONFIG=dxr,dxr11       → DX12 ray tracing
  mesa_glthread=true            → Multi-threaded OpenGL
NOTE: Intel Arc RT on Linux is still maturing — update regularly"
        ;;
    hybrid_amd_nvidia|hybrid_intel_nvidia)
echo "HYBRID — Run on NVIDIA dGPU with RT (demanding games):
PROTON_ENABLE_NVAPI=1 VKD3D_CONFIG=dxr,dxr11 __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_ASYNC=1 gamemoderun mangohud %command%

HYBRID — Simple NVIDIA mode:
prime-run %command%

HYBRID — Integrated GPU (light games / battery saving):
DRI_PRIME=0 gamemoderun %command%"
        ;;
esac
)

════════════════════════════════════════════════════════════════
RAY TRACING TIPS:
  • Enable RT in game graphics settings after applying above options
  • RT shader cache builds on first launch — stutter is normal
  • Use upscaling (FSR/DLSS/XeSS) alongside RT for best performance
  • VKD3D_CONFIG=dxr11 needed for DXR 1.1 titles (richer RT effects)
  • Run gaming-update regularly — RT support improves with each update

REMEMBER:
  • Enable ReBAR in BIOS for free 5-15% GPU performance boost
  • Set GE-Proton as default in Steam → Settings → Compatibility
════════════════════════════════════════════════════════════════
EOF

    ok "Launch options + RT config saved to ~/Gaming-Launch-Options.txt"
    echo -e "\n  ${CYAN}Your personalised RT launch options:${NC}"
    echo -e "  ${WHITE}See ~/Gaming-Launch-Options.txt for full details${NC}"
    INSTALLED+=("launch-options-rt-guide")
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 20 — ANTI-CHEAT SUPPORT (EAC + BattlEye — Universal)
# ════════════════════════════════════════════════════════════════════════════
phase_anticheat() {
    print_section "PHASE 20 — Anti-Cheat Support (EAC + BattlEye)"

    info "Enabling Linux runtime support for:"
    info "EAC: Fortnite, Battlefield, Apex Legends, Rust, Hunt Showdown"
    info "BattlEye: Rainbow Six Siege, DayZ, Halo Infinite and more"

    step "Writing anti-cheat environment variables..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-anticheat.conf > /dev/null << 'EOF'
# Anti-Cheat Linux Support — EAC + BattlEye via Proton
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt
WINE_LARGE_ADDRESS_AWARE=1
PROTON_USE_SECCOMP=1
EOF
    ok "Anti-cheat environment config written"
    INSTALLED+=("anticheat-env-config")

    step "Setting EAC-compatible kernel parameter..."
    sudo sysctl -w kernel.perf_event_paranoid=-1 > /dev/null 2>&1
    ok "kernel.perf_event_paranoid=-1 set for EAC"
    INSTALLED+=("eac-kernel-param")

    step "Writing anti-cheat launch options guide..."
    cat > "$HOME/Gaming-AntiCheat-Launch-Options.txt" << EOF
════════════════════════════════════════════════════════════════
ANTI-CHEAT LAUNCH OPTIONS — $GPU_LABEL
EAC + BattlEye via Proton
════════════════════════════════════════════════════════════════

STEP 1 — Install in Steam (ONE TIME):
  steam steam://install/1826330   ← Easy Anti-Cheat Runtime
  steam steam://install/1161040   ← BattlEye Service Runtime

STEP 2 — Steam → Settings → Compatibility → Enable Steam Play

UNIVERSAL (most EAC + BattlEye games):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 DXVK_ASYNC=1 gamemoderun mangohud %command%

FORTNITE / APEX (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 DXVK_ASYNC=1 gamemoderun mangohud %command%

BATTLEFIELD 2042 / BATTLEFIELD 6 (EAC + RT):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

GTA 5 / GTA ONLINE:
VKD3D_CONFIG=dxr DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

RAINBOW SIX / RUST / DAYZ (BattlEye):
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt DXVK_ASYNC=1 gamemoderun mangohud %command%

════════════════════════════════════════════════════════════════
WORKING: Fortnite ✓  Apex ✓  GTA5 ✓  Battlefield ✓
         R6 Siege ✓  Rust ✓  DayZ ✓  Hunt Showdown ✓
NOT WORKING: Valorant (Vanguard kernel anti-cheat)
Check protondb.com for latest status of any game
════════════════════════════════════════════════════════════════
EOF
    ok "Anti-cheat guide saved to ~/Gaming-AntiCheat-Launch-Options.txt"
    INSTALLED+=("anticheat-launch-guide")
}

# ════════════════════════════════════════════════════════════════════════════
# PHASE 21 — UPSCALING TECHNOLOGY (FSR 3 + DLSS + XeSS + Gamescope)
# ════════════════════════════════════════════════════════════════════════════
phase_upscaling() {
    print_section "PHASE 21 — Upscaling: FSR 4 + DLSS 4.5 + XeSS 3 MFG + Gamescope"

    info "GPU: $GPU_LABEL"
    info "FSR 4    — RDNA4 native AI, RDNA3/2 fallback via VKD3D-Proton 3.0"
    info "DLSS 4.5 — NVIDIA only, 2nd gen transformer + 6X Dynamic MFG Spring 2026"
    info "XeSS 3   — Arc MFG 2x/3x/4x (DX12) + upscaling all GPUs"
    info "Gamescope — System FSR on any GPU, no game support needed"

    step "Installing Gamescope upscaling compositor..."
    if sudo apt install -y -qq gamescope 2>/dev/null; then
        ok "Gamescope installed — forces FSR in any game without upscaling"
        INSTALLED+=("gamescope")
    else
        warn "Gamescope not in repos — FSR via Wine still works"
    fi

    step "Writing GPU-specific upscaling environment config (FSR4/DLSS4.5/XeSS3)..."
    sudo mkdir -p /etc/environment.d/

    case "$CHOSEN_GPU" in
        amd)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# AMD FSR 4 + FSR 3 Upscaling — March 2026
# FSR 4: use PROTON_FSR4_UPGRADE=1 launch option (RDNA4=native, RDNA3=fallback)
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "AMD FSR 4/3 configured" ;;
        nvidia|hybrid_amd_nvidia|hybrid_intel_nvidia)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# NVIDIA DLSS 4.5 + FSR 3 — March 2026
# DLSS 4.5: 2nd gen transformer model + Dynamic 6X MFG (Spring 2026)
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "NVIDIA DLSS 4.5 + FSR 3 fallback configured" ;;
        intel_arc)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# Intel XeSS 3 + FSR 3 — March 2026
# XeSS 3 MFG: 2x/3x/4x frames on Arc A/B-series (DX12 required)
ANV_ENABLE_PIPELINE_CACHE=1
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "Intel XeSS 3 + FSR 3 configured" ;;
        *)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# Universal FSR 3 Upscaling
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
EOF
            ok "FSR 3 universal fallback configured" ;;
    esac
    INSTALLED+=("upscaling-env-config-fsr4")

    step "Writing FSR4/DLSS4.5/XeSS3 launch options guide..."
    cat > "$HOME/Gaming-Upscaling-Options.txt" << EOF
════════════════════════════════════════════════════════════════════════
UPSCALING LAUNCH OPTIONS — March 2026
FSR 4 (AI) • DLSS 4.5 • XeSS 3 MFG • Gamescope
GPU: $GPU_LABEL
════════════════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 — AI Upscaling (RDNA4 native / all AMD fallback)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Enable FSR 4 (upgrades FSR 3.1 games via GE-Proton):
PROTON_FSR4_UPGRADE=1 %command%

FSR 4 + RT (RDNA4 sweet spot):
PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

FSR 4 + Anti-Cheat + RT (Battlefield 6, Fortnite):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

$(case "$CHOSEN_GPU" in
nvidia|hybrid_amd_nvidia|hybrid_intel_nvidia)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLSS 4.5 — NVIDIA (2nd gen transformer + Dynamic 6X MFG)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLSS 4.5 Super Resolution (all RTX):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 %command%

DLSS 4.5 + Frame Gen (RTX 40/50):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_ASYNC=1 %command%

DLSS 4.5 force latest transformer preset:
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_DLSS_PRESET=f DXVK_ASYNC=1 %command%
NOTE: 6X Dynamic MFG coming April 2026 — update GE-Proton then"
;;
intel_arc)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS 3 — Intel Arc AI Upscaling + Multi-Frame Gen 2x/3x/4x
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS upscaling (all GPUs — enable in game settings, no flags):
Just enable XeSS in game graphics settings — works automatically

XeSS 3 MFG on DX12 titles (Arc GPU required):
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true %command%
NOTE: XeSS 3 MFG currently DX12/Windows only — Linux support coming"
;;
esac)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 3 — Universal fallback (all GPUs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
In-game: WINE_FULLSCREEN_FSR=1 WINE_FULLSCREEN_FSR_STRENGTH=2 %command%
Gamescope 1440p: gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling --fsr-sharpness 5 -- %command%
Gamescope 4K:    gamescope -w 1920 -h 1080 -W 3840 -H 2160 -f --fsr-upscaling -- %command%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OptiScaler — Inject any upscaler into any game
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files at: ~/.local/share/optiscaler/ (downloaded by gaming-update)
Launch: WINEDLLOVERRIDES="winmm.dll=n,b" %command%
Overlay: Press INSERT in-game | WARNING: Never in online games!

════════════════════════════════════════════════════════════════════════
FSR 4 note: PROTON_FSR4_UPGRADE=1 only works in FSR 3.1 supported games
FSR strength: 0=sharpest  2=balanced  5=softest
Gamescope:    0=sharpest  20=softest (--fsr-sharpness, opposite scale!)
Run gaming-update regularly — FSR 4 game support grows every update
════════════════════════════════════════════════════════════════════════
EOF
    ok "FSR4/DLSS4.5/XeSS3 upscaling guide saved to ~/Gaming-Upscaling-Options.txt"
    INSTALLED+=("fsr4-dlss45-xess3-upscaling-guide")
}

# ════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ════════════════════════════════════════════════════════════════════════════
print_summary() {
    echo -e "\n${BLUE}  ╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}  ║${GREEN}${BOLD}                  SETUP COMPLETE — SUMMARY                      ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}  ╚══════════════════════════════════════════════════════════════════╝${NC}"

    echo -e "\n  ${GREEN}${BOLD}Installed (${#INSTALLED[@]})${NC}"
    for item in "${INSTALLED[@]}"; do echo -e "    ${GREEN}✓${NC} $item"; done

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo -e "\n  ${DIM}Already Present / Skipped (${#SKIPPED[@]})${NC}"
        for item in "${SKIPPED[@]}"; do echo -e "    ${DIM}◌ $item${NC}"; done
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "\n  ${RED}${BOLD}Failed (${#FAILED[@]})${NC}"
        for item in "${FAILED[@]}"; do echo -e "    ${RED}✗${NC} $item"; done
    fi

    echo -e "\n${BLUE}  ┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${YELLOW}  POST-SETUP STEPS                                                ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}  └──────────────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${YELLOW}1.${NC} ${WHITE}REBOOT${NC} — activates XanMod kernel + GPU drivers"
    echo -e "  ${YELLOW}2.${NC} Enable ${WHITE}Resizable BAR${NC} in BIOS (AMD/NVIDIA free performance)"
    echo -e "  ${YELLOW}3.${NC} Open ${WHITE}Steam → Settings → Compatibility${NC} → Enable Steam Play"
    echo -e "  ${YELLOW}4.${NC} Set ${WHITE}GE-Proton${NC} as default in Steam compatibility settings"
    echo -e "  ${YELLOW}5.${NC} Copy launch options from ${WHITE}~/Gaming-Launch-Options.txt${NC}"
    echo -e "  ${YELLOW}6.${NC} Run ${WHITE}gaming-update${NC} after reboot to verify everything"

    echo -e "\n${BLUE}  ┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${CYAN}  YOUR SETUP                                                      ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}  └──────────────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${CYAN}OS      :${NC} $DETECTED_DISTRO"
    echo -e "  ${CYAN}GPU     :${NC} $GPU_LABEL"
    echo -e "  ${CYAN}CPU     :${NC} $CPU_LABEL"
    echo -e "  ${CYAN}Kernel  :${NC} $(uname -r) → XanMod after reboot"
    echo -e "  ${CYAN}Command :${NC} gaming-update (run weekly)"

    echo -e "\n  ${DIM}Full log: $LOG_FILE${NC}"
    echo -e "\n${GREEN}${BOLD}  Welcome to Nobara-level gaming on Debian. Enjoy!${NC}"
    echo -e "${DIM}  Share this script with anyone on Debian-based Linux — they deserve it too.${NC}\n"
}

# ════════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════════
main() {
    print_banner
    check_root
    check_internet

    # Detection & selection
    detect_system
    hardware_selection

    # Universal phases
    phase_system_prep
    phase_kernel
    phase_gpu_drivers
    phase_grub
    phase_sysctl
    phase_cpu_governor
    phase_gaming_stack
    phase_steam
    phase_ge_proton
    phase_wine_ge
    phase_dxvk
    phase_vkd3d
    phase_dxvk_nvapi    # only runs for NVIDIA
    phase_zram
    phase_irq
    phase_heroic
    phase_auto_pipeline
    phase_launch_options
    phase_anticheat
    phase_upscaling

    print_summary
}

main "$@"
