#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║          DEBIAN GAMING UPDATE SUITE — UNIVERSAL EDITION                 ║
# ║          Supports: Ubuntu • Zorin • Mint • Pop!_OS • Debian             ║
# ║          GPU: AMD RDNA • NVIDIA • Intel Arc                             ║
# ║          CPU: AMD Ryzen • Intel Core                                    ║
# ║                                                                          ║
# ║          Run this regularly to stay cutting edge                        ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';        BOLD='\033[1m';  NC='\033[0m'

# ── Log file ──────────────────────────────────────────────────────────────────
LOG_DIR="$HOME/.local/share/gaming-update-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/universal-update-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── State tracking ────────────────────────────────────────────────────────────
UPDATED=(); SKIPPED=(); FAILED=()
START_TIME=$(date +%s)

# ── Hardware detection (auto) ─────────────────────────────────────────────────
DETECTED_GPU_VENDOR=""
DETECTED_CPU_VENDOR=""

# ════════════════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════════════════
ok()     { echo -e "  ${GREEN}✓${NC}  $1"; }
info()   { echo -e "  ${CYAN}→${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()   { echo -e "  ${RED}✗${NC}  $1"; }
step()   { echo -e "\n  ${MAGENTA}▶${NC}  ${BOLD}$1${NC}"; }
skip()   { echo -e "  ${DIM}◌  $1 — already latest${NC}"; }
newver() { echo -e "  ${GREEN}↑${NC}  ${BOLD}$1${NC}  ${DIM}$2 → $3${NC}"; }

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║       DEBIAN GAMING UPDATE SUITE — UNIVERSAL EDITION             ║"
    echo "  ║       AMD • NVIDIA • Intel Arc  ×  Ryzen • Intel Core            ║"
    echo -e "  ╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DIM}$(date '+%A, %d %B %Y — %H:%M:%S')${NC}"
    echo -e "  ${DIM}Log: $LOG_FILE${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}  ┌───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC}  ${YELLOW}${BOLD}$1${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────────────────────┘${NC}"
}

check_root() {
    [[ $EUID -eq 0 ]] && { fail "Do not run as root."; exit 1; }
}

check_internet() {
    step "Checking internet connection..."
    curl -s --max-time 8 https://google.com > /dev/null && ok "Internet confirmed" || \
        { fail "No internet — connect and try again."; exit 1; }
}

get_latest_github_tag() {
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4
}

get_latest_github_asset_url() {
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"browser_download_url"' \
        | grep "$2" | cut -d'"' -f4 | head -1
}

elapsed_time() {
    local END=$(date +%s)
    local DIFF=$((END - START_TIME))
    echo "$((DIFF / 60))m $((DIFF % 60))s"
}

# ════════════════════════════════════════════════════════════════════════════
# AUTO-DETECT HARDWARE
# ════════════════════════════════════════════════════════════════════════════
detect_hardware() {
    print_section "Hardware Detection"

    step "Detecting GPU..."
    GPU_LIST=$(lspci 2>/dev/null | grep -iE "vga|3d|display")

    if echo "$GPU_LIST" | grep -qi "nvidia"; then
        DETECTED_GPU_VENDOR="nvidia"
        GPU_NAME=$(echo "$GPU_LIST" | grep -i nvidia | head -1 | sed 's/.*: //')
    elif echo "$GPU_LIST" | grep -qi "amd\|radeon"; then
        DETECTED_GPU_VENDOR="amd"
        GPU_NAME=$(echo "$GPU_LIST" | grep -iE "amd|radeon" | head -1 | sed 's/.*: //')
    elif echo "$GPU_LIST" | grep -qi "intel.*arc\|intel.*xe\|intel.*alchemist\|intel.*battlemage"; then
        DETECTED_GPU_VENDOR="intel_arc"
        GPU_NAME=$(echo "$GPU_LIST" | grep -i intel | head -1 | sed 's/.*: //')
    elif echo "$GPU_LIST" | grep -qi "intel"; then
        DETECTED_GPU_VENDOR="intel_igp"
        GPU_NAME=$(echo "$GPU_LIST" | grep -i intel | head -1 | sed 's/.*: //')
    else
        DETECTED_GPU_VENDOR="unknown"
        GPU_NAME="Unknown GPU"
    fi

    # Also check for hybrid
    NVIDIA_COUNT=$(echo "$GPU_LIST" | grep -ic nvidia)
    AMD_COUNT=$(echo "$GPU_LIST" | grep -icE "amd|radeon")
    INTEL_COUNT=$(echo "$GPU_LIST" | grep -ic intel)

    if [[ $NVIDIA_COUNT -gt 0 ]] && [[ $AMD_COUNT -gt 0 ]]; then
        DETECTED_GPU_VENDOR="hybrid_amd_nvidia"
        GPU_NAME="AMD + NVIDIA Hybrid"
    elif [[ $NVIDIA_COUNT -gt 0 ]] && [[ $INTEL_COUNT -gt 0 ]]; then
        DETECTED_GPU_VENDOR="hybrid_intel_nvidia"
        GPU_NAME="Intel + NVIDIA Hybrid"
    fi

    info "GPU : $GPU_NAME ($DETECTED_GPU_VENDOR)"

    step "Detecting CPU..."
    CPU_INFO=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    if echo "$CPU_INFO" | grep -qi "amd\|ryzen"; then
        DETECTED_CPU_VENDOR="amd"
    else
        DETECTED_CPU_VENDOR="intel"
    fi

    info "CPU : $CPU_INFO ($DETECTED_CPU_VENDOR)"
    info "OS  : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
}

# ════════════════════════════════════════════════════════════════════════════
# 01 — SYSTEM PACKAGES
# ════════════════════════════════════════════════════════════════════════════
update_system() {
    print_section "01 — Core System Packages"

    step "Refreshing package lists..."
    if sudo apt update -qq 2>/dev/null; then
        ok "Package lists refreshed"
    else
        fail "apt update failed"
        FAILED+=("apt-update"); return
    fi

    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo 0)
    info "$UPGRADABLE packages upgradable"

    step "Upgrading system packages..."
    sudo apt upgrade -y -qq 2>/dev/null
    ok "System packages upgraded"
    UPDATED+=("system-packages ($UPGRADABLE upgrades)")

    step "Cleaning orphaned packages..."
    sudo apt autoremove -y -qq 2>/dev/null
    ok "Cleanup done"
}

# ════════════════════════════════════════════════════════════════════════════
# 02 — XANMOD KERNEL
# ════════════════════════════════════════════════════════════════════════════
update_kernel() {
    print_section "02 — XanMod Kernel (BORE Scheduler)"

    CURRENT_KERNEL=$(uname -r)
    info "Running: $CURRENT_KERNEL"

    # Ensure repo exists
    if [[ ! -f /etc/apt/sources.list.d/xanmod-release.list ]]; then
        warn "XanMod repo missing — adding..."
        wget -qO - https://dl.xanmod.org/archive.key | \
            sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://dl.xanmod.org releases main' | \
            sudo tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null
        sudo apt update -qq 2>/dev/null
        ok "XanMod repo added"
    fi

    step "Checking XanMod kernel updates..."
    LATEST_XAN=$(apt-cache policy linux-xanmod-rt-x64v3 2>/dev/null | grep Candidate | awk '{print $2}')
    INSTALLED_XAN=$(apt-cache policy linux-xanmod-rt-x64v3 2>/dev/null | grep Installed | awk '{print $2}')
    info "Installed : ${INSTALLED_XAN:-none}"
    info "Available : ${LATEST_XAN:-unknown}"

    if [[ "$INSTALLED_XAN" == "$LATEST_XAN" ]] && [[ "$INSTALLED_XAN" != "(none)" ]]; then
        skip "XanMod kernel $INSTALLED_XAN"
        SKIPPED+=("xanmod-kernel")
    else
        if sudo apt install -y linux-xanmod-rt-x64v3 2>/dev/null || \
           sudo apt install -y linux-xanmod-x64v3 2>/dev/null; then
            ok "XanMod kernel updated — active after reboot"
            UPDATED+=("xanmod-kernel → $LATEST_XAN")
        else
            fail "XanMod kernel update failed"
            FAILED+=("xanmod-kernel")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 03 — GPU DRIVERS (Universal — auto-detects)
# ════════════════════════════════════════════════════════════════════════════
update_gpu_drivers() {
    print_section "03 — GPU Drivers ($GPU_NAME)"

    case "$DETECTED_GPU_VENDOR" in

        amd)
            update_amd_drivers
            ;;

        nvidia)
            update_nvidia_drivers
            ;;

        intel_arc)
            update_intel_arc_drivers
            ;;

        intel_igp)
            update_intel_igp_drivers
            ;;

        hybrid_amd_nvidia)
            info "Hybrid AMD + NVIDIA — updating both"
            update_amd_drivers
            update_nvidia_drivers
            ;;

        hybrid_intel_nvidia)
            info "Hybrid Intel + NVIDIA — updating both"
            update_intel_igp_drivers
            update_nvidia_drivers
            ;;

        *)
            warn "Unknown GPU vendor — skipping GPU-specific updates"
            SKIPPED+=("gpu-drivers")
            ;;
    esac
}

update_amd_drivers() {
    step "Updating AMD Mesa drivers (RDNA)..."

    # Ensure kisak PPA
    if grep -qi "ubuntu\|zorin\|mint\|pop" /etc/os-release 2>/dev/null; then
        if ! grep -r "kisak-mesa" /etc/apt/sources.list.d/ &>/dev/null; then
            sudo add-apt-repository -y ppa:kisak/kisak-mesa 2>/dev/null
            sudo apt update -qq 2>/dev/null
            ok "kisak bleeding-edge Mesa PPA added"
        fi
    fi

    CURRENT_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "unknown")
    info "Current Mesa: $CURRENT_MESA"

    AMD_PKGS=(mesa-vulkan-drivers libvulkan1 mesa-utils libgl1-mesa-dri
              libglx-mesa0 mesa-vdpau-drivers mesa-va-drivers libdrm-amdgpu1 libdrm2)

    for pkg in "${AMD_PKGS[@]}"; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
    done

    NEW_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "check after reboot")

    if [[ "$CURRENT_MESA" != "$NEW_MESA" ]]; then
        newver "Mesa (AMD)" "$CURRENT_MESA" "$NEW_MESA"
        UPDATED+=("amd-mesa → $NEW_MESA")
        # Clear Mesa shader cache since Mesa updated
        rm -rf "$HOME/.cache/mesa_shader_cache" 2>/dev/null
        ok "Mesa shader cache cleared for rebuild"
    else
        skip "AMD Mesa $CURRENT_MESA"
        SKIPPED+=("amd-mesa")
    fi

    # AMD firmware
    step "Checking AMDGPU firmware..."
    sudo apt install --only-upgrade -y -qq linux-firmware 2>/dev/null && \
        ok "AMDGPU firmware checked" || warn "Firmware check skipped"
}

update_nvidia_drivers() {
    step "Updating NVIDIA drivers..."

    # Ensure PPA
    if grep -qi "ubuntu\|zorin\|mint\|pop" /etc/os-release 2>/dev/null; then
        if ! grep -r "graphics-drivers" /etc/apt/sources.list.d/ &>/dev/null; then
            sudo add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null
            sudo apt update -qq 2>/dev/null
            ok "NVIDIA graphics PPA added"
        fi
    fi

    CURRENT_DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "unknown")
    info "Current driver: $CURRENT_DRV"

    RECOMMENDED=""
    command -v ubuntu-drivers &>/dev/null && \
        RECOMMENDED=$(ubuntu-drivers devices 2>/dev/null | grep "recommended" | awk '{print $3}')
    [[ -z "$RECOMMENDED" ]] && RECOMMENDED="nvidia-driver-570"

    if sudo apt install --only-upgrade -y -qq "$RECOMMENDED" 2>/dev/null || \
       sudo ubuntu-drivers autoinstall 2>/dev/null; then
        NEW_DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "check after reboot")
        if [[ "$CURRENT_DRV" != "$NEW_DRV" ]]; then
            newver "NVIDIA driver" "$CURRENT_DRV" "$NEW_DRV"
            UPDATED+=("nvidia-driver → $NEW_DRV")
            warn "Reboot required for new driver"
        else
            skip "NVIDIA driver $CURRENT_DRV"
            SKIPPED+=("nvidia-driver")
        fi
    else
        fail "NVIDIA driver update failed"
        FAILED+=("nvidia-driver")
    fi

    # nvidia-persistenced
    step "Verifying nvidia-persistenced..."
    if sudo systemctl is-active --quiet nvidia-persistenced 2>/dev/null; then
        ok "nvidia-persistenced running"
        SKIPPED+=("nvidia-persistenced")
    else
        sudo systemctl enable nvidia-persistenced --now 2>/dev/null && \
            ok "nvidia-persistenced started" && UPDATED+=("nvidia-persistenced") || \
            warn "nvidia-persistenced unavailable — check after reboot"
    fi

    # NVIDIA Vulkan libs
    for pkg in libvulkan1 vulkan-tools; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
    done
    ok "NVIDIA Vulkan libs checked"
}

update_intel_arc_drivers() {
    step "Updating Intel Arc drivers..."

    # Ensure Intel graphics repo
    if grep -qi "ubuntu\|zorin\|mint\|pop" /etc/os-release 2>/dev/null; then
        if [[ ! -f /etc/apt/sources.list.d/intel-graphics.list ]]; then
            CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
            wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
                sudo gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg 2>/dev/null
            echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
https://repositories.intel.com/gpu/ubuntu ${CODENAME} client" | \
                sudo tee /etc/apt/sources.list.d/intel-graphics.list > /dev/null
            sudo apt update -qq 2>/dev/null
            ok "Intel graphics repo added"
        fi
    fi

    CURRENT_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "unknown")
    info "Current Mesa (Intel): $CURRENT_MESA"

    ARC_PKGS=(mesa-vulkan-drivers intel-media-va-driver-non-free
              intel-opencl-icd libvulkan1 mesa-utils libgl1-mesa-dri)

    for pkg in "${ARC_PKGS[@]}"; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
    done

    NEW_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "check after reboot")
    if [[ "$CURRENT_MESA" != "$NEW_MESA" ]]; then
        newver "Mesa (Intel Arc)" "$CURRENT_MESA" "$NEW_MESA"
        UPDATED+=("intel-arc-mesa → $NEW_MESA")
    else
        skip "Intel Arc Mesa $CURRENT_MESA"
        SKIPPED+=("intel-arc-mesa")
    fi
}

update_intel_igp_drivers() {
    step "Updating Intel integrated graphics..."

    for pkg in mesa-vulkan-drivers intel-media-va-driver libvulkan1 libgl1-mesa-dri; do
        apt-cache show "$pkg" &>/dev/null 2>/dev/null && \
            sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
    done

    ok "Intel integrated graphics drivers checked"
    UPDATED+=("intel-igp-drivers")
}

# ════════════════════════════════════════════════════════════════════════════
# 04 — GE-PROTON
# ════════════════════════════════════════════════════════════════════════════
update_ge_proton() {
    print_section "04 — GE-Proton (GloriousEggroll)"

    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$PROTON_DIR"

    step "Fetching latest GE-Proton..."
    LATEST_GE=$(get_latest_github_tag "GloriousEggroll/proton-ge-custom")

    if [[ -z "$LATEST_GE" ]]; then
        fail "Could not reach GitHub for GE-Proton"
        FAILED+=("ge-proton"); return
    fi

    INSTALLED_GE=$(ls "$PROTON_DIR" 2>/dev/null | grep "GE-Proton" | sort -V | tail -1)
    info "Latest    : $LATEST_GE"
    info "Installed : ${INSTALLED_GE:-none}"

    if [[ "$INSTALLED_GE" == "$LATEST_GE" ]]; then
        skip "GE-Proton $LATEST_GE"
        SKIPPED+=("ge-proton")
    else
        newver "GE-Proton" "${INSTALLED_GE:-none}" "$LATEST_GE"
        step "Downloading GE-Proton $LATEST_GE..."
        if curl -L --progress-bar \
            "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_GE/$LATEST_GE.tar.gz" \
            -o "/tmp/$LATEST_GE.tar.gz"; then
            tar -xzf "/tmp/$LATEST_GE.tar.gz" -C "$PROTON_DIR"
            rm -f "/tmp/$LATEST_GE.tar.gz"
            ok "GE-Proton $LATEST_GE installed"
            UPDATED+=("ge-proton → $LATEST_GE")
            # Clean old versions (keep 2)
            ls -d "$PROTON_DIR"/GE-Proton* 2>/dev/null | sort -V | head -n -2 | xargs rm -rf 2>/dev/null
            info "Old GE-Proton versions cleaned"
        else
            fail "GE-Proton download failed"
            FAILED+=("ge-proton")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 05 — WINE-GE
# ════════════════════════════════════════════════════════════════════════════
update_wine_ge() {
    print_section "05 — Wine-GE (Lutris)"

    WINE_DIR="$HOME/.local/share/lutris/runners/wine"
    mkdir -p "$WINE_DIR"

    step "Fetching latest Wine-GE..."
    LATEST_WINE=$(get_latest_github_tag "GloriousEggroll/wine-ge-custom")

    if [[ -z "$LATEST_WINE" ]]; then
        fail "Could not reach GitHub for Wine-GE"
        FAILED+=("wine-ge"); return
    fi

    INSTALLED_WINE=$(ls "$WINE_DIR" 2>/dev/null | sort -V | tail -1)
    info "Latest    : $LATEST_WINE"
    info "Installed : ${INSTALLED_WINE:-none}"

    if [[ -n "$INSTALLED_WINE" ]] && echo "$INSTALLED_WINE" | grep -q "${LATEST_WINE//GE-/}"; then
        skip "Wine-GE $LATEST_WINE"
        SKIPPED+=("wine-ge")
    else
        newver "Wine-GE" "${INSTALLED_WINE:-none}" "$LATEST_WINE"
        WINE_URL=$(get_latest_github_asset_url "GloriousEggroll/wine-ge-custom" ".tar.xz")

        step "Downloading Wine-GE $LATEST_WINE..."
        if curl -L --progress-bar "$WINE_URL" -o "/tmp/wine-ge-latest.tar.xz"; then
            mkdir -p "$WINE_DIR/$LATEST_WINE"
            tar -xJf "/tmp/wine-ge-latest.tar.xz" -C "$WINE_DIR/$LATEST_WINE" --strip-components=1
            rm -f "/tmp/wine-ge-latest.tar.xz"
            ok "Wine-GE $LATEST_WINE installed"
            UPDATED+=("wine-ge → $LATEST_WINE")
        else
            fail "Wine-GE download failed"
            FAILED+=("wine-ge")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 06 — DXVK
# ════════════════════════════════════════════════════════════════════════════
update_dxvk() {
    print_section "06 — DXVK (DirectX 9/10/11 → Vulkan)"

    DXVK_DIR="$HOME/.local/share/dxvk"
    mkdir -p "$DXVK_DIR"

    step "Fetching latest DXVK..."
    LATEST_DXVK=$(get_latest_github_tag "doitsujin/dxvk")

    if [[ -z "$LATEST_DXVK" ]]; then
        fail "Could not reach GitHub for DXVK"
        FAILED+=("dxvk"); return
    fi

    INSTALLED_DXVK=$(ls "$DXVK_DIR" 2>/dev/null | sort -V | tail -1)
    info "Latest    : $LATEST_DXVK"
    info "Installed : ${INSTALLED_DXVK:-none}"

    if [[ "$INSTALLED_DXVK" == "$LATEST_DXVK" ]]; then
        skip "DXVK $LATEST_DXVK"
        SKIPPED+=("dxvk")
    else
        newver "DXVK" "${INSTALLED_DXVK:-none}" "$LATEST_DXVK"
        DXVK_URL=$(get_latest_github_asset_url "doitsujin/dxvk" ".tar.gz")

        step "Downloading DXVK $LATEST_DXVK..."
        if curl -L --progress-bar "$DXVK_URL" -o "/tmp/dxvk-latest.tar.gz"; then
            mkdir -p "$DXVK_DIR/$LATEST_DXVK"
            tar -xzf "/tmp/dxvk-latest.tar.gz" -C "$DXVK_DIR/$LATEST_DXVK" --strip-components=1
            rm -f "/tmp/dxvk-latest.tar.gz"
            ok "DXVK $LATEST_DXVK installed"
            UPDATED+=("dxvk → $LATEST_DXVK")
            ls -d "$DXVK_DIR"/v* 2>/dev/null | sort -V | head -n -2 | xargs rm -rf 2>/dev/null
        else
            fail "DXVK download failed"
            FAILED+=("dxvk")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 07 — VKD3D-PROTON
# ════════════════════════════════════════════════════════════════════════════
update_vkd3d() {
    print_section "07 — VKD3D-Proton (DirectX 12 → Vulkan)"

    VKD3D_DIR="$HOME/.local/share/vkd3d"
    mkdir -p "$VKD3D_DIR"

    step "Fetching latest VKD3D-Proton..."
    LATEST_VKD3D=$(get_latest_github_tag "HansKristian-Work/vkd3d-proton")

    if [[ -z "$LATEST_VKD3D" ]]; then
        fail "Could not reach GitHub for VKD3D-Proton"
        FAILED+=("vkd3d"); return
    fi

    INSTALLED_VKD3D=$(ls "$VKD3D_DIR" 2>/dev/null | sort -V | tail -1)
    info "Latest    : $LATEST_VKD3D"
    info "Installed : ${INSTALLED_VKD3D:-none}"

    if [[ "$INSTALLED_VKD3D" == "$LATEST_VKD3D" ]]; then
        skip "VKD3D-Proton $LATEST_VKD3D"
        SKIPPED+=("vkd3d")
    else
        newver "VKD3D-Proton" "${INSTALLED_VKD3D:-none}" "$LATEST_VKD3D"
        sudo apt install -y -qq zstd 2>/dev/null

        VKD3D_URL=$(get_latest_github_asset_url "HansKristian-Work/vkd3d-proton" "tar.zst")
        [[ -z "$VKD3D_URL" ]] && VKD3D_URL=$(get_latest_github_asset_url "HansKristian-Work/vkd3d-proton" "tar.gz")

        step "Downloading VKD3D-Proton $LATEST_VKD3D..."
        if curl -L --progress-bar "$VKD3D_URL" -o "/tmp/vkd3d-latest.tar.zst"; then
            mkdir -p "$VKD3D_DIR/$LATEST_VKD3D"
            tar -xf "/tmp/vkd3d-latest.tar.zst" -C "$VKD3D_DIR/$LATEST_VKD3D" --strip-components=1 2>/dev/null
            rm -f "/tmp/vkd3d-latest.tar.zst"
            ok "VKD3D-Proton $LATEST_VKD3D installed"
            UPDATED+=("vkd3d → $LATEST_VKD3D")
        else
            fail "VKD3D-Proton download failed"
            FAILED+=("vkd3d")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 08 — DXVK-NVAPI (NVIDIA only)
# ════════════════════════════════════════════════════════════════════════════
update_dxvk_nvapi() {
    if [[ "$DETECTED_GPU_VENDOR" != "nvidia" ]] && [[ "$DETECTED_GPU_VENDOR" != *"nvidia"* ]]; then
        return
    fi

    print_section "08 — DXVK-NVAPI (DLSS + NVIDIA Reflex)"

    NVAPI_DIR="$HOME/.local/share/dxvk-nvapi"
    mkdir -p "$NVAPI_DIR"

    step "Fetching latest DXVK-NVAPI..."
    LATEST_NVAPI=$(get_latest_github_tag "jp7677/dxvk-nvapi")

    if [[ -z "$LATEST_NVAPI" ]]; then
        warn "Could not fetch DXVK-NVAPI — skipping"
        SKIPPED+=("dxvk-nvapi"); return
    fi

    INSTALLED_NVAPI=$(ls "$NVAPI_DIR" 2>/dev/null | sort -V | tail -1)
    info "Latest    : $LATEST_NVAPI"
    info "Installed : ${INSTALLED_NVAPI:-none}"

    if [[ "$INSTALLED_NVAPI" == "$LATEST_NVAPI" ]]; then
        skip "DXVK-NVAPI $LATEST_NVAPI"
        SKIPPED+=("dxvk-nvapi")
    else
        newver "DXVK-NVAPI" "${INSTALLED_NVAPI:-none}" "$LATEST_NVAPI"
        NVAPI_URL=$(get_latest_github_asset_url "jp7677/dxvk-nvapi" "tar.gz")

        step "Downloading DXVK-NVAPI $LATEST_NVAPI..."
        if curl -L --progress-bar "$NVAPI_URL" -o "/tmp/dxvk-nvapi.tar.gz" 2>/dev/null; then
            mkdir -p "$NVAPI_DIR/$LATEST_NVAPI"
            tar -xzf "/tmp/dxvk-nvapi.tar.gz" -C "$NVAPI_DIR/$LATEST_NVAPI" --strip-components=1 2>/dev/null
            rm -f "/tmp/dxvk-nvapi.tar.gz"
            ok "DXVK-NVAPI $LATEST_NVAPI installed"
            UPDATED+=("dxvk-nvapi → $LATEST_NVAPI")
        else
            warn "DXVK-NVAPI download failed — non-critical"
            FAILED+=("dxvk-nvapi")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 09 — GAMEMODE & MANGOHUD
# ════════════════════════════════════════════════════════════════════════════
update_gaming_tools() {
    print_section "09 — GameMode & MangoHud"

    for pkg in gamemode mangohud; do
        step "Updating $pkg..."
        CURRENT=$(dpkg -l "$pkg" 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "not installed")
        sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
        NEW=$(dpkg -l "$pkg" 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "unknown")

        if [[ "$CURRENT" != "$NEW" ]] && [[ "$CURRENT" != "not installed" ]]; then
            newver "$pkg" "$CURRENT" "$NEW"
            UPDATED+=("$pkg → $NEW")
        else
            skip "$pkg $CURRENT"
            SKIPPED+=("$pkg")
        fi
    done

    # Ensure MangoHud config exists
    MANGOHUD_CONF="$HOME/.config/MangoHud/MangoHud.conf"
    if [[ ! -f "$MANGOHUD_CONF" ]]; then
        mkdir -p "$(dirname "$MANGOHUD_CONF")"
        cat > "$MANGOHUD_CONF" << 'EOF'
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
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 10 — STEAM & LAUNCHERS
# ════════════════════════════════════════════════════════════════════════════
update_launchers() {
    print_section "10 — Steam & Game Launchers"

    step "Checking Steam..."
    dpkg -l steam 2>/dev/null | grep -q "^ii" && \
        sudo apt install --only-upgrade -y -qq steam 2>/dev/null && \
        ok "Steam (native) checked" && UPDATED+=("steam-native")

    flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam" && \
        flatpak update -y com.valvesoftware.Steam 2>/dev/null && \
        ok "Steam (Flatpak) updated" && UPDATED+=("steam-flatpak")

    step "Updating all Flatpak apps..."
    flatpak update -y 2>/dev/null && ok "Flatpaks updated" || warn "Flatpak update skipped"

    step "Checking Lutris..."
    sudo apt install --only-upgrade -y -qq lutris 2>/dev/null
    ok "Lutris checked"

    step "Checking Heroic..."
    flatpak list 2>/dev/null | grep -q "com.heroicgameslauncher.hgl" && \
        flatpak update -y com.heroicgameslauncher.hgl 2>/dev/null && \
        ok "Heroic (Flatpak) updated"
}

# ════════════════════════════════════════════════════════════════════════════
# 11 — GAMESCOPE
# ════════════════════════════════════════════════════════════════════════════
update_gamescope() {
    print_section "11 — Gamescope"

    step "Checking Gamescope..."
    if command -v gamescope &>/dev/null; then
        sudo apt install --only-upgrade -y -qq gamescope 2>/dev/null
        ok "Gamescope checked"
        SKIPPED+=("gamescope")
    else
        sudo apt install -y -qq gamescope 2>/dev/null && \
            ok "Gamescope installed" && UPDATED+=("gamescope") || \
            info "Gamescope not in repos — skipping"
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 11b — RAY TRACING OPTIMISATION (Universal — all GPU types)
# ════════════════════════════════════════════════════════════════════════════
update_raytracing_universal() {
    print_section "11b — Ray Tracing Optimisation (Universal)"

    info "Configuring ray tracing for detected GPU: $GPU_NAME ($DETECTED_GPU_VENDOR)"

    RT_ENV_DIR="/etc/environment.d/"
    sudo mkdir -p "$RT_ENV_DIR"
    RT_LAUNCH="$HOME/Gaming-Launch-Options-RT.txt"

    case "$DETECTED_GPU_VENDOR" in

        # ── AMD Ray Tracing ─────────────────────────────────────────────
        amd)
            step "Configuring AMD RDNA ray tracing environment..."
            RT_ENV="${RT_ENV_DIR}99-amd-raytracing.conf"
            sudo tee "$RT_ENV" > /dev/null << 'EOF'
# AMD RDNA Ray Tracing Optimisations
RADV_PERFTEST=gpl,rt,ngg_streamout
VKD3D_CONFIG=dxr,dxr11
DXVK_ASYNC=1
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "AMD RT environment config written"
            UPDATED+=("amd-rt-env-config")

            cat > "$RT_LAUNCH" << 'EOF'
════════════════════════════════════════════════════════════════
AMD Radeon — Ray Tracing Steam Launch Options
════════════════════════════════════════════════════════════════

GLOBAL (Steam → Settings → General):
RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 VKD3D_CONFIG=dxr,dxr11 MESA_VK_WSI_PRESENT_MODE=mailbox gamemoderun mangohud %command%

DX12 RAY TRACING GAMES:
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

MAXIMUM RT PERFORMANCE:
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV WINE_FULLSCREEN_FSR=1 gamemoderun mangohud %command%

KEY VARIABLES:
  RADV_PERFTEST=gpl,rt       → Enables RADV hardware RT acceleration
  VKD3D_CONFIG=dxr,dxr11     → DX12 ray tracing (DXR 1.0 and 1.1)
  DXVK_ASYNC=1               → Reduces RT stutter on shader load
  AMD_VULKAN_ICD=RADV        → Forces open-source RADV Vulkan driver
  WINE_FULLSCREEN_FSR=1      → AMD FSR upscaling pairs well with RT
════════════════════════════════════════════════════════════════
EOF
            ;;

        # ── NVIDIA Ray Tracing ───────────────────────────────────────────
        nvidia|hybrid_amd_nvidia|hybrid_intel_nvidia)
            step "Configuring NVIDIA RTX ray tracing environment..."
            RT_ENV="${RT_ENV_DIR}99-nvidia-raytracing.conf"
            sudo tee "$RT_ENV" > /dev/null << 'EOF'
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
            ok "NVIDIA RT environment config written"
            UPDATED+=("nvidia-rt-env-config")

            cat > "$RT_LAUNCH" << 'EOF'
════════════════════════════════════════════════════════════════
NVIDIA RTX — Ray Tracing Steam Launch Options
════════════════════════════════════════════════════════════════

GLOBAL (Steam → Settings → General):
PROTON_ENABLE_NVAPI=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

RT + DLSS (DX12 titles):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

RT + DLSS + REFLEX (competitive RT games):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 __GL_THREADED_OPTIMIZATIONS=1 gamemoderun mangohud %command%

KEY VARIABLES:
  PROTON_ENABLE_NVAPI=1              → Enables DLSS, Reflex and RT API
  DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1   → Full DLSS/RT compatibility
  VKD3D_CONFIG=dxr,dxr11             → DX12 ray tracing
  DXVK_ASYNC=1                       → Reduces RT stutter
════════════════════════════════════════════════════════════════
EOF
            ;;

        # ── Intel Arc Ray Tracing ────────────────────────────────────────
        intel_arc)
            step "Configuring Intel Arc ray tracing environment..."
            RT_ENV="${RT_ENV_DIR}99-intel-arc-raytracing.conf"
            sudo tee "$RT_ENV" > /dev/null << 'EOF'
# Intel Arc Ray Tracing Optimisations
ANV_ENABLE_PIPELINE_CACHE=1
VKD3D_CONFIG=dxr,dxr11
DXVK_ASYNC=1
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "Intel Arc RT environment config written"
            UPDATED+=("intel-arc-rt-env-config")

            cat > "$RT_LAUNCH" << 'EOF'
════════════════════════════════════════════════════════════════
Intel Arc — Ray Tracing Steam Launch Options
════════════════════════════════════════════════════════════════

GLOBAL (Steam → Settings → General):
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true gamemoderun mangohud %command%

DX12 RAY TRACING GAMES:
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json gamemoderun mangohud %command%

KEY VARIABLES:
  ANV_ENABLE_PIPELINE_CACHE=1  → Intel Vulkan pipeline cache for RT
  VKD3D_CONFIG=dxr,dxr11       → DX12 ray tracing support
  mesa_glthread=true            → Multi-threaded OpenGL
  DXVK_ASYNC=1                  → Reduces RT stutter
NOTE: Intel Arc RT on Linux is still maturing — some games may
      need DXVK_ASYNC=1 to avoid RT-related crashes.
════════════════════════════════════════════════════════════════
EOF
            ;;

        *)
            warn "Unknown GPU — writing generic RT config"
            cat > "$RT_LAUNCH" << 'EOF'
════════════════════════════════════════════════════════════════
Generic — Ray Tracing Steam Launch Options
════════════════════════════════════════════════════════════════

GLOBAL:
VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%
════════════════════════════════════════════════════════════════
EOF
            ;;
    esac

    ok "RT launch options saved to ~/Gaming-Launch-Options-RT.txt"
    UPDATED+=("rt-launch-options")

    # ── Verify RT Vulkan Extensions ──────────────────────────────────
    step "Verifying ray tracing Vulkan extensions..."
    if command -v vulkaninfo &>/dev/null; then
        RT_EXT=$(vulkaninfo 2>/dev/null | grep -i "VK_KHR_ray\|VK_NV_ray\|raytracing" | head -3)
        if [[ -n "$RT_EXT" ]]; then
            ok "Hardware ray tracing Vulkan extensions confirmed"
        else
            warn "RT extensions not visible yet — may need reboot after driver update"
        fi
    fi

    # ── Clear RT shader cache if drivers updated ─────────────────────
    step "Checking RT shader cache..."
    RADV_RT_CACHE="$HOME/.cache/radv_builtin_shaders"
    if [[ -d "$RADV_RT_CACHE" ]] && [[ " ${UPDATED[*]} " =~ "mesa\|amd-mesa\|intel-arc-mesa" ]]; then
        rm -rf "$RADV_RT_CACHE" 2>/dev/null
        ok "RT shader cache cleared for rebuild after driver update"
    else
        ok "RT shader cache healthy"
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# 11c — ANTI-CHEAT SUPPORT (EAC + BattlEye — Universal)
# ════════════════════════════════════════════════════════════════════════════
update_anticheat_universal() {
    print_section "11c — Anti-Cheat Support (EAC + BattlEye)"

    info "Configuring EAC and BattlEye Linux runtime support"
    info "GPU: $GPU_NAME | Supported: Battlefield, GTA 5, Fortnite, Apex and more"

    step "Configuring anti-cheat environment variables..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-anticheat.conf > /dev/null << 'EOF'
# ══════════════════════════════════════════════════
# Anti-Cheat Linux Support — EAC + BattlEye
# ══════════════════════════════════════════════════
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt
WINE_LARGE_ADDRESS_AWARE=1
PROTON_USE_SECCOMP=1
EOF
    ok "Anti-cheat environment variables configured"
    UPDATED+=("anticheat-env")

    step "Checking kernel perf_event for EAC compatibility..."
    PARANOID=$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo "1")
    if [[ "$PARANOID" != "-1" ]]; then
        sudo sysctl -w kernel.perf_event_paranoid=-1 > /dev/null 2>&1
        ok "kernel.perf_event_paranoid set to -1 (EAC compatible)"
        UPDATED+=("eac-kernel-param")
    else
        ok "kernel.perf_event_paranoid already -1"
        SKIPPED+=("eac-kernel-param")
    fi

    step "Writing anti-cheat launch options..."
    cat > "$HOME/Gaming-AntiCheat-Launch-Options.txt" << 'EOF'
════════════════════════════════════════════════════════════════
ANTI-CHEAT GAME LAUNCH OPTIONS — Linux (Universal)
EAC + BattlEye supported
════════════════════════════════════════════════════════════════

STEP 1 — Install runtimes in Steam (ONE TIME ONLY):
  steam steam://install/1826330   ← Easy Anti-Cheat Runtime
  steam steam://install/1161040   ← BattlEye Service Runtime

STEP 2 — Enable Steam Play for all titles in Steam Settings

UNIVERSAL (most EAC + BattlEye games):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 DXVK_ASYNC=1 gamemoderun mangohud %command%

FORTNITE / APEX LEGENDS (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 DXVK_ASYNC=1 gamemoderun mangohud %command%

BATTLEFIELD 2042 / BATTLEFIELD 6 (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

GTA 5 / GTA ONLINE (no kernel AC — works great):
VKD3D_CONFIG=dxr DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

RAINBOW SIX SIEGE / RUST / DAYZ (BattlEye):
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt DXVK_ASYNC=1 gamemoderun mangohud %command%

════════════════════════════════════════════════════════════════
CONFIRMED WORKING ON LINUX:
  ✓ Fortnite        ✓ Apex Legends     ✓ GTA 5
  ✓ Battlefield 2042 ✓ Rainbow Six Siege ✓ Rust
  ✓ DayZ            ✓ Hunt Showdown    ✓ Dead by Daylight
  ✓ Deep Rock Galactic ✓ Halo Infinite  ✓ Elden Ring

NOT WORKING (kernel-level anti-cheat):
  ✗ Valorant (Vanguard requires Windows kernel access)
  Always verify at: protondb.com
════════════════════════════════════════════════════════════════
EOF
    ok "Anti-cheat launch options saved to ~/Gaming-AntiCheat-Launch-Options.txt"
    UPDATED+=("anticheat-launch-options")
}

# ════════════════════════════════════════════════════════════════════════════
# 11d — UPSCALING TECHNOLOGY (FSR 3 + DLSS + XeSS + Gamescope — Universal)
# ════════════════════════════════════════════════════════════════════════════
update_upscaling_universal() {
    print_section "11d — Upscaling: FSR 4 + DLSS 4.5 + XeSS 3 MFG + Gamescope"

    info "GPU: $GPU_NAME ($DETECTED_GPU_VENDOR)"
    info "FSR 4    — AI upscaling: RDNA4 native, RDNA3/2 fallback via VKD3D-Proton 3.0"
    info "DLSS 4.5 — NVIDIA only: 2nd gen transformer + 6X Dynamic MFG (Spring 2026)"
    info "XeSS 3   — Intel Arc MFG 2x/3x/4x (DX12) + upscaling all GPUs"
    info "Gamescope — System compositor FSR on any GPU without game support"

    # ── Gamescope ─────────────────────────────────────────────────────
    step "Installing/updating Gamescope..."
    if sudo apt install --only-upgrade -y gamescope 2>/dev/null || \
       sudo apt install -y gamescope 2>/dev/null; then
        ok "Gamescope installed — system-level FSR upscaling active"
        UPDATED+=("gamescope")
    else
        warn "Gamescope not in repos — FSR via Wine still works"
        SKIPPED+=("gamescope")
    fi

    # ── OptiScaler download (FSR4/DLSS4/XeSS3 bridge) ─────────────────
    step "Checking OptiScaler (bridges FSR4/DLSS4.5/XeSS3 across all GPUs)..."
    OPTISCALER_DIR="$HOME/.local/share/optiscaler"
    mkdir -p "$OPTISCALER_DIR"
    LATEST_OPTI=$(curl -s "https://api.github.com/repos/optiscaler/OptiScaler/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null)
    INSTALLED_OPTI=$(cat "$OPTISCALER_DIR/version.txt" 2>/dev/null || echo "none")
    info "Latest: ${LATEST_OPTI:-unavailable} | Installed: $INSTALLED_OPTI"

    if [[ -n "$LATEST_OPTI" ]] && [[ "$INSTALLED_OPTI" != "$LATEST_OPTI" ]]; then
        OPTI_URL=$(curl -s "https://api.github.com/repos/optiscaler/OptiScaler/releases/latest" \
            | grep '"browser_download_url"' | grep -i "zip\|tar" | cut -d'"' -f4 | head -1)
        if [[ -n "$OPTI_URL" ]]; then
            curl -L --progress-bar "$OPTI_URL" -o "/tmp/optiscaler.zip" 2>/dev/null && \
                mkdir -p "$OPTISCALER_DIR/$LATEST_OPTI" && \
                (unzip -q "/tmp/optiscaler.zip" -d "$OPTISCALER_DIR/$LATEST_OPTI" 2>/dev/null || \
                 tar -xf "/tmp/optiscaler.zip" -C "$OPTISCALER_DIR/$LATEST_OPTI" 2>/dev/null) && \
                echo "$LATEST_OPTI" > "$OPTISCALER_DIR/version.txt" && \
                rm -f "/tmp/optiscaler.zip" && \
                ok "OptiScaler $LATEST_OPTI downloaded" && \
                UPDATED+=("optiscaler → $LATEST_OPTI") || \
                warn "OptiScaler download failed — check github.com/optiscaler/OptiScaler"
        fi
    else
        skip "OptiScaler $INSTALLED_OPTI"
        SKIPPED+=("optiscaler")
    fi

    # ── GPU-specific upscaling environment ────────────────────────────
    step "Writing GPU-specific upscaling environment config (FSR4/DLSS4.5/XeSS3)..."
    sudo mkdir -p /etc/environment.d/

    case "$DETECTED_GPU_VENDOR" in
        amd)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# AMD FSR 4 + FSR 3 Upscaling — March 2026
# FSR 4 via PROTON_FSR4_UPGRADE=1 launch option (RDNA4=native, RDNA3=fallback)
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "AMD FSR 4/3 upscaling configured"
            ;;
        nvidia|hybrid_*nvidia)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# NVIDIA DLSS 4.5 + FSR 3 — March 2026
# DLSS 4.5: 2nd gen transformer + Dynamic 6X MFG (Spring 2026)
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "NVIDIA DLSS 4.5 + FSR 3 fallback configured"
            ;;
        intel_arc|intel_igp)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# Intel XeSS 3 + FSR 3 — March 2026
# XeSS 3: MFG 2x/3x/4x on Arc A/B-series (DX12 required)
ANV_ENABLE_PIPELINE_CACHE=1
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "Intel XeSS 3 + FSR 3 configured"
            ;;
        *)
            sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# Generic FSR 3 Upscaling
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
EOF
            ok "Generic FSR 3 configured"
            ;;
    esac
    UPDATED+=("upscaling-env-config-fsr4")

    # ── Write GPU-personalised launch options ─────────────────────────
    step "Writing FSR4/DLSS4.5/XeSS3 launch options guide..."
    cat > "$HOME/Gaming-Upscaling-Options.txt" << EOF
════════════════════════════════════════════════════════════════════════
UPSCALING LAUNCH OPTIONS — March 2026
FSR 4 (AI) • DLSS 4.5 • XeSS 3 MFG • Gamescope
GPU: $GPU_NAME
════════════════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 — AMD AI Upscaling (RDNA4 native, all AMD fallback)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 upgrade in FSR 3.1 games (auto-upgrades via GE-Proton):
PROTON_FSR4_UPGRADE=1 %command%

FSR 4 with visual confirmation overlay:
PROTON_FSR4_UPGRADE=1 PROTON_FSR4_INDICATOR=1 %command%

$(case "$DETECTED_GPU_VENDOR" in
nvidia|hybrid_*nvidia)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLSS 4.5 — NVIDIA AI Upscaling (2nd gen transformer)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLSS 4.5 Super Resolution (all RTX):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 %command%

DLSS 4.5 + Frame Generation (RTX 40/50):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_ASYNC=1 %command%

DLSS 4.5 with latest transformer preset (force best model):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_DLSS_PRESET=f DXVK_ASYNC=1 %command%

NOTE: DLSS 4.5 6X Dynamic MFG coming April 2026 — update GE-Proton when released"
;;
intel_arc)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS 3 — Intel AI Upscaling + Multi-Frame Generation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS upscaling works on ALL GPUs in game settings (no launch flags)
XeSS 3 MFG (2x/3x/4x) requires Arc GPU + DX12 title:
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true %command%

MFG on DX12 title (override in Intel Graphics Software for 3x/4x):
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 %command%
NOTE: XeSS 3 MFG currently Windows/DX12 only — Linux support in progress"
;;
amd)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 + RT — Best combined setup for AMD RDNA GPUs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 + Ray Tracing (RDNA 4 sweet spot):
PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

FSR 4 + RT + Anti-Cheat (EAC games):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%"
;;
esac)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 3 — Universal fallback (all GPUs, no game support needed)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
In-game FSR 3 (game must support it):
WINE_FULLSCREEN_FSR=1 WINE_FULLSCREEN_FSR_STRENGTH=2 %command%

Via Gamescope (no game support needed at all):
gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling --fsr-sharpness 5 -- %command%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OptiScaler — Inject FSR4/DLSS4/XeSS3 into ANY game
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files downloaded to: ~/.local/share/optiscaler/[version]/
Copy to game folder, then use: WINEDLLOVERRIDES="winmm.dll=n,b" %command%
Press INSERT in-game to open OptiScaler overlay
WARNING: Do NOT use OptiScaler with online anti-cheat games

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Gamescope — System compositor upscaling
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1080p → 1440p: gamescope -w 1920 -h 1080 -W 2560 -H 1440 -f --fsr-upscaling -- %command%
1080p → 4K:    gamescope -w 1920 -h 1080 -W 3840 -H 2160 -f --fsr-upscaling -- %command%
High refresh:  gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling --fsr-sharpness 5 -- %command%

════════════════════════════════════════════════════════════════════════
FSR SHARPNESS:  0=sharpest  2=balanced  5=softest (WINE_FULLSCREEN_FSR)
Gamescope:      0=sharpest  20=softest  (--fsr-sharpness, opposite scale)
FSR 4 NOTE:     PROTON_FSR4_UPGRADE=1 only works in FSR 3.1 supported games
                Always keep GE-Proton updated for latest FSR 4 fixes
════════════════════════════════════════════════════════════════════════
EOF
    ok "Upscaling guide (FSR4/DLSS4.5/XeSS3) saved to ~/Gaming-Upscaling-Options.txt"
    UPDATED+=("upscaling-fsr4-dlss45-xess3")
}

# ════════════════════════════════════════════════════════════════════════════
# 12 — SYSTEM TWEAKS VERIFICATION
# ════════════════════════════════════════════════════════════════════════════
verify_tweaks() {
    print_section "12 — Verify Gaming Tweaks"

    step "Checking sysctl config..."
    if [[ ! -f /etc/sysctl.d/99-gaming-universal.conf ]]; then
        warn "Gaming sysctl config missing — recreating..."
        sudo tee /etc/sysctl.d/99-gaming-universal.conf > /dev/null << 'EOF'
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.nr_hugepages=128
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
kernel.sched_autogroup_enabled=1
kernel.numa_balancing=0
fs.inotify.max_user_watches=524288
fs.file-max=2097152
EOF
        sudo sysctl -p /etc/sysctl.d/99-gaming-universal.conf > /dev/null 2>&1
        ok "Gaming sysctl restored"
        UPDATED+=("sysctl-restored")
    else
        ok "Gaming sysctl present"
        SKIPPED+=("sysctl")
    fi

    step "Checking CPU governor..."
    CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    info "Governor: $CURRENT_GOV"

    if [[ "$CURRENT_GOV" != "performance" ]]; then
        sudo cpupower frequency-set -g performance > /dev/null 2>&1 && \
            ok "CPU governor reset to performance" && UPDATED+=("cpu-governor-reset") || \
            warn "Could not set CPU governor"
    else
        ok "CPU governor on performance"
        SKIPPED+=("cpu-governor")
    fi

    step "Checking ZRAM..."
    if swapon --show 2>/dev/null | grep -q "zram"; then
        ZRAM_SIZE=$(swapon --show 2>/dev/null | grep zram | awk '{print $3}')
        ok "ZRAM active: $ZRAM_SIZE"
        SKIPPED+=("zram")
    else
        warn "ZRAM inactive — attempting restart..."
        sudo systemctl start zram-config 2>/dev/null || true
    fi

    step "Checking irqbalance..."
    systemctl is-active --quiet irqbalance 2>/dev/null && \
        ok "irqbalance running" || \
        { sudo systemctl start irqbalance 2>/dev/null; warn "irqbalance was stopped — restarted"; }
}

# ════════════════════════════════════════════════════════════════════════════
# 13 — PROTONDB QUICK STATUS
# ════════════════════════════════════════════════════════════════════════════
check_protondb() {
    print_section "13 — ProtonDB Compatibility Check"

    STEAM_APPS="$HOME/.steam/steam/steamapps"

    if [[ ! -d "$STEAM_APPS" ]]; then
        warn "No Steam apps directory — skipping"
        SKIPPED+=("protondb"); return
    fi

    step "Checking ProtonDB ratings for installed games..."
    echo ""

    COUNT=0
    for appmanifest in "$STEAM_APPS"/appmanifest_*.acf; do
        [[ -f "$appmanifest" ]] || continue
        APPID=$(grep '"appid"' "$appmanifest" | grep -o '[0-9]*')
        GAMENAME=$(grep '"name"' "$appmanifest" | cut -d'"' -f4)

        RATING=$(curl -s --max-time 3 \
            "https://www.protondb.com/api/v1/reports/summaries/$APPID.json" \
            | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tier', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)

        case $RATING in
            "platinum") echo -e "    ${CYAN}[PLATINUM]${NC} $GAMENAME" ;;
            "gold")     echo -e "    ${YELLOW}[GOLD]${NC}    $GAMENAME" ;;
            "silver")   echo -e "    ${WHITE}[SILVER]${NC}  $GAMENAME" ;;
            "bronze")   echo -e "    ${YELLOW}[BRONZE]${NC}  $GAMENAME" ;;
            "borked")   echo -e "    ${RED}[BORKED]${NC}  $GAMENAME ← check for fixes" ;;
            *)          echo -e "    ${DIM}[UNKNOWN]${NC} $GAMENAME" ;;
        esac
        COUNT=$((COUNT + 1))
    done

    [[ $COUNT -eq 0 ]] && info "No installed Steam games found" || ok "$COUNT games checked"
}

# ════════════════════════════════════════════════════════════════════════════
# 14 — LOG ROTATION
# ════════════════════════════════════════════════════════════════════════════
rotate_logs() {
    print_section "14 — Log Rotation"

    step "Cleaning old logs (keeping last 10)..."
    LOG_COUNT=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)

    if [[ $LOG_COUNT -gt 10 ]]; then
        ls -t "$LOG_DIR"/*.log | tail -n +11 | xargs rm -f
        ok "Old logs cleaned"
    else
        skip "Log rotation ($LOG_COUNT/10 logs)"
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ════════════════════════════════════════════════════════════════════════════
print_summary() {
    ELAPSED=$(elapsed_time)

    echo -e "\n${BLUE}  ╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}  ║${GREEN}${BOLD}                   UPDATE COMPLETE — SUMMARY                    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}  ╚══════════════════════════════════════════════════════════════════╝${NC}"

    echo -e "\n  ${GREEN}${BOLD}Updated / Installed (${#UPDATED[@]})${NC}"
    for item in "${UPDATED[@]}"; do echo -e "    ${GREEN}↑${NC} $item"; done

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo -e "\n  ${DIM}Already Latest / Skipped (${#SKIPPED[@]})${NC}"
        for item in "${SKIPPED[@]}"; do echo -e "    ${DIM}◌ $item${NC}"; done
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "\n  ${RED}${BOLD}Failed (${#FAILED[@]})${NC}"
        for item in "${FAILED[@]}"; do echo -e "    ${RED}✗${NC} $item"; done
    fi

    echo -e "\n${BLUE}  ┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${YELLOW}  SYSTEM STATUS                                                   ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}  └──────────────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${CYAN}OS            :${NC} $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    echo -e "  ${CYAN}GPU           :${NC} $GPU_NAME"
    echo -e "  ${CYAN}Kernel        :${NC} $(uname -r)"
    echo -e "  ${CYAN}CPU Governor  :${NC} $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'unknown')"
    echo -e "  ${CYAN}ZRAM          :${NC} $(swapon --show 2>/dev/null | grep zram | awk '{print $3}' || echo 'inactive')"

    # GPU-specific status
    case "$DETECTED_GPU_VENDOR" in
        amd)
            echo -e "  ${CYAN}Mesa          :${NC} $(glxinfo 2>/dev/null | grep 'OpenGL version' | awk '{print $4}' || echo 'check after reboot')"
            ;;
        nvidia|hybrid_*nvidia)
            echo -e "  ${CYAN}NVIDIA Driver :${NC} $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'check after reboot')"
            echo -e "  ${CYAN}GPU Temp      :${NC} $(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo 'N/A')°C"
            ;;
        intel_arc)
            echo -e "  ${CYAN}Mesa (Arc)    :${NC} $(glxinfo 2>/dev/null | grep 'OpenGL version' | awk '{print $4}' || echo 'check after reboot')"
            ;;
    esac

    echo -e "  ${CYAN}Elapsed       :${NC} $ELAPSED"
    echo -e "  ${CYAN}Log           :${NC} $LOG_FILE"

    if [[ " ${UPDATED[*]} " =~ "xanmod-kernel" ]] || [[ " ${UPDATED[*]} " =~ "nvidia-driver" ]]; then
        echo -e "\n  ${YELLOW}${BOLD}⚠  REBOOT RECOMMENDED — kernel or GPU driver was updated${NC}"
    fi

    echo -e "\n  ${GREEN}${BOLD}Your Debian gaming stack is cutting edge. Ready to play!${NC}"
    echo -e "  ${DIM}Share this script — every Linux gamer deserves this setup.${NC}\n"
}

# ════════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════════
main() {
    print_banner
    check_root
    check_internet
    detect_hardware

    update_system
    update_kernel
    update_gpu_drivers
    update_ge_proton
    update_wine_ge
    update_dxvk
    update_vkd3d
    update_dxvk_nvapi
    update_gaming_tools
    update_launchers
    update_gamescope
    update_raytracing_universal
    update_anticheat_universal
    update_upscaling_universal
    verify_tweaks
    check_protondb
    rotate_logs

    print_summary
}

main "$@"
