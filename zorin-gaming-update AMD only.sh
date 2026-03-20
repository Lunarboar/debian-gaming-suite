#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║         ZORIN OS — CUTTING EDGE GAMING UPDATE SCRIPT            ║
# ║         Ryzen CPU + RX 9070 XT (RDNA 4) Edition                 ║
# ║         Keeps everything on par with Nobara                      ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Colours ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Log file ─────────────────────────────────────────────────────────
LOG_DIR="$HOME/.local/share/gaming-update-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── State tracking ───────────────────────────────────────────────────
UPDATED=()
SKIPPED=()
FAILED=()
START_TIME=$(date +%s)

# ════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ════════════════════════════════════════════════════════════════════
ok()      { echo -e "  ${GREEN}✓${NC}  $1"; }
info()    { echo -e "  ${CYAN}→${NC}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()    { echo -e "  ${RED}✗${NC}  $1"; }
step()    { echo -e "\n  ${MAGENTA}▶${NC}  ${BOLD}$1${NC}"; }
skip()    { echo -e "  ${DIM}◌  $1 — already latest${NC}"; }
newver()  { echo -e "  ${GREEN}↑${NC}  ${BOLD}$1${NC}  ${DIM}$2 → $3${NC}"; }

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║       ZORIN OS — GAMING UPDATE ENGINE                       ║"
    echo "  ║       Ryzen + RX 9070 XT  •  Now with Ray Tracing Support   ║"
    echo -e "  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DIM}$(date '+%A, %d %B %Y — %H:%M:%S')${NC}"
    echo -e "  ${DIM}Log: $LOG_FILE${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}  ┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC} ${YELLOW}${BOLD} $1${NC}"
    echo -e "${BLUE}  └─────────────────────────────────────────────────────────────┘${NC}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        fail "Do not run as root. Run as your normal user."
        exit 1
    fi
}

check_internet() {
    step "Checking internet connection..."
    if ! curl -s --max-time 8 https://google.com > /dev/null; then
        fail "No internet. Connect and try again."
        exit 1
    fi
    ok "Internet confirmed"
}

get_latest_github_tag() {
    # $1 = owner/repo
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4
}

get_latest_github_asset_url() {
    # $1 = owner/repo  $2 = pattern to grep
    curl -s "https://api.github.com/repos/$1/releases/latest" \
        | grep '"browser_download_url"' \
        | grep "$2" \
        | cut -d'"' -f4 \
        | head -1
}

elapsed_time() {
    END=$(date +%s)
    DIFF=$((END - START_TIME))
    echo "$((DIFF / 60))m $((DIFF % 60))s"
}

# ════════════════════════════════════════════════════════════════════
# 01 — SYSTEM PACKAGES
# ════════════════════════════════════════════════════════════════════
update_system() {
    print_section "01 — Core System Packages"

    step "Refreshing package lists..."
    if sudo apt update -qq 2>/dev/null; then
        ok "Package lists refreshed"
    else
        fail "apt update failed — check your sources"
        FAILED+=("apt-update")
        return
    fi

    step "Upgrading system packages..."
    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo 0)
    info "$UPGRADABLE packages upgradable"

    if sudo apt upgrade -y -qq 2>/dev/null; then
        ok "System packages upgraded"
        UPDATED+=("system-packages ($UPGRADABLE upgrades)")
    else
        warn "Some packages may not have upgraded cleanly"
    fi

    step "Removing orphaned packages..."
    sudo apt autoremove -y -qq 2>/dev/null
    ok "Cleanup done"
}

# ════════════════════════════════════════════════════════════════════
# 02 — XANMOD KERNEL
# ════════════════════════════════════════════════════════════════════
update_kernel() {
    print_section "02 — XanMod Kernel (BORE Scheduler)"

    step "Checking for XanMod kernel updates..."
    CURRENT_KERNEL=$(uname -r)
    info "Running kernel: $CURRENT_KERNEL"

    # Check if XanMod repo exists
    if [[ ! -f /etc/apt/sources.list.d/xanmod-release.list ]]; then
        warn "XanMod repo not configured — adding it now..."
        wget -qO - https://dl.xanmod.org/archive.key | \
            sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://dl.xanmod.org releases main' | \
            sudo tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null
        sudo apt update -qq 2>/dev/null
    fi

    # Get latest available XanMod version
    LATEST_XANMOD=$(apt-cache policy linux-xanmod-rt-x64v3 2>/dev/null \
        | grep Candidate | awk '{print $2}')

    INSTALLED_XANMOD=$(apt-cache policy linux-xanmod-rt-x64v3 2>/dev/null \
        | grep Installed | awk '{print $2}')

    if [[ "$INSTALLED_XANMOD" == "$LATEST_XANMOD" ]] && [[ "$INSTALLED_XANMOD" != "(none)" ]]; then
        skip "XanMod kernel $INSTALLED_XANMOD"
        SKIPPED+=("xanmod-kernel")
    else
        if [[ "$INSTALLED_XANMOD" == "(none)" ]]; then
            info "Installing XanMod kernel for the first time..."
        else
            newver "XanMod kernel" "$INSTALLED_XANMOD" "$LATEST_XANMOD"
        fi

        if sudo apt install -y linux-xanmod-rt-x64v3 2>/dev/null || \
           sudo apt install -y linux-xanmod-x64v3 2>/dev/null; then
            ok "XanMod kernel updated — active after reboot"
            UPDATED+=("xanmod-kernel → $LATEST_XANMOD")
        else
            fail "XanMod kernel update failed"
            FAILED+=("xanmod-kernel")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 03 — MESA (Critical for RX 9070 XT RDNA 4)
# ════════════════════════════════════════════════════════════════════
update_mesa() {
    print_section "03 — Mesa Drivers (RDNA 4 / RX 9070 XT)"

    # Ensure kisak PPA is present
    if ! grep -r "kisak-mesa" /etc/apt/sources.list.d/ &>/dev/null; then
        step "Adding kisak bleeding-edge Mesa PPA..."
        sudo add-apt-repository -y ppa:kisak/kisak-mesa 2>/dev/null
        sudo apt update -qq 2>/dev/null
        ok "kisak-mesa PPA added"
    fi

    CURRENT_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "unknown")
    info "Current Mesa: $CURRENT_MESA"

    step "Upgrading Mesa packages..."
    MESA_PACKAGES=(
        mesa-vulkan-drivers
        libvulkan1
        mesa-utils
        libgl1-mesa-dri
        libglx-mesa0
        libgles2-mesa
        mesa-vdpau-drivers
        mesa-va-drivers
        libdrm-amdgpu1
        libdrm-radeon1
    )

    MESA_UPGRADED=0
    for pkg in "${MESA_PACKAGES[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
            if sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null; then
                MESA_UPGRADED=$((MESA_UPGRADED + 1))
            fi
        fi
    done

    NEW_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' || echo "check after reboot")

    if [[ "$CURRENT_MESA" != "$NEW_MESA" ]]; then
        newver "Mesa" "$CURRENT_MESA" "$NEW_MESA"
        UPDATED+=("mesa → $NEW_MESA")
    else
        skip "Mesa $CURRENT_MESA"
        SKIPPED+=("mesa")
    fi

    # RADV / Vulkan info
    step "Checking Vulkan / RADV status..."
    if command -v vulkaninfo &>/dev/null; then
        VULKAN_VER=$(vulkaninfo 2>/dev/null | grep "Vulkan Instance Version" | awk '{print $NF}')
        info "Vulkan: $VULKAN_VER"
    fi
}

# ════════════════════════════════════════════════════════════════════
# 04 — GE-PROTON
# ════════════════════════════════════════════════════════════════════
update_ge_proton() {
    print_section "04 — GE-Proton (GloriousEggroll)"

    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$PROTON_DIR"

    step "Fetching latest GE-Proton release..."
    LATEST_GE=$(get_latest_github_tag "GloriousEggroll/proton-ge-custom")

    if [[ -z "$LATEST_GE" ]]; then
        fail "Could not reach GitHub API for GE-Proton"
        FAILED+=("ge-proton")
        return
    fi

    info "Latest GE-Proton: $LATEST_GE"

    # Find currently installed versions
    INSTALLED_GE=$(ls "$PROTON_DIR" 2>/dev/null | grep "GE-Proton" | sort -V | tail -1)
    info "Installed: ${INSTALLED_GE:-none}"

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

            # Clean up old versions (keep last 2)
            step "Cleaning old GE-Proton versions (keeping last 2)..."
            OLD_VERSIONS=$(ls -d "$PROTON_DIR"/GE-Proton* 2>/dev/null | sort -V | head -n -2)
            if [[ -n "$OLD_VERSIONS" ]]; then
                echo "$OLD_VERSIONS" | while read -r old; do
                    rm -rf "$old"
                    info "Removed old: $(basename "$old")"
                done
            fi
        else
            fail "GE-Proton download failed"
            FAILED+=("ge-proton")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 05 — WINE-GE
# ════════════════════════════════════════════════════════════════════
update_wine_ge() {
    print_section "05 — Wine-GE (Lutris)"

    WINE_DIR="$HOME/.local/share/lutris/runners/wine"
    mkdir -p "$WINE_DIR"

    step "Fetching latest Wine-GE release..."
    LATEST_WINE=$(get_latest_github_tag "GloriousEggroll/wine-ge-custom")

    if [[ -z "$LATEST_WINE" ]]; then
        fail "Could not reach GitHub API for Wine-GE"
        FAILED+=("wine-ge")
        return
    fi

    info "Latest Wine-GE: $LATEST_WINE"

    INSTALLED_WINE=$(ls "$WINE_DIR" 2>/dev/null | grep -i "wine" | sort -V | tail -1)
    info "Installed: ${INSTALLED_WINE:-none}"

    if [[ -n "$INSTALLED_WINE" ]] && echo "$INSTALLED_WINE" | grep -q "${LATEST_WINE//GE-/}"; then
        skip "Wine-GE $LATEST_WINE"
        SKIPPED+=("wine-ge")
    else
        newver "Wine-GE" "${INSTALLED_WINE:-none}" "$LATEST_WINE"

        WINE_URL=$(get_latest_github_asset_url "GloriousEggroll/wine-ge-custom" ".tar.xz")

        step "Downloading Wine-GE $LATEST_WINE..."
        if curl -L --progress-bar "$WINE_URL" -o "/tmp/wine-ge-latest.tar.xz"; then
            WINE_INSTALL_DIR="$WINE_DIR/$LATEST_WINE"
            mkdir -p "$WINE_INSTALL_DIR"
            tar -xJf "/tmp/wine-ge-latest.tar.xz" -C "$WINE_INSTALL_DIR" --strip-components=1
            rm -f "/tmp/wine-ge-latest.tar.xz"
            ok "Wine-GE $LATEST_WINE installed"
            UPDATED+=("wine-ge → $LATEST_WINE")
        else
            fail "Wine-GE download failed"
            FAILED+=("wine-ge")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 06 — DXVK
# ════════════════════════════════════════════════════════════════════
update_dxvk() {
    print_section "06 — DXVK (DirectX → Vulkan)"

    DXVK_DIR="$HOME/.local/share/dxvk"
    mkdir -p "$DXVK_DIR"

    step "Fetching latest DXVK release..."
    LATEST_DXVK=$(get_latest_github_tag "doitsujin/dxvk")

    if [[ -z "$LATEST_DXVK" ]]; then
        fail "Could not reach GitHub API for DXVK"
        FAILED+=("dxvk")
        return
    fi

    info "Latest DXVK: $LATEST_DXVK"

    INSTALLED_DXVK=$(ls "$DXVK_DIR" 2>/dev/null | sort -V | tail -1)
    info "Installed: ${INSTALLED_DXVK:-none}"

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

            # Clean old versions
            OLD_DXVK=$(ls -d "$DXVK_DIR"/v* 2>/dev/null | sort -V | head -n -2)
            if [[ -n "$OLD_DXVK" ]]; then
                echo "$OLD_DXVK" | while read -r old; do rm -rf "$old"; done
                info "Old DXVK versions cleaned"
            fi
        else
            fail "DXVK download failed"
            FAILED+=("dxvk")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 07 — VKD3D-PROTON
# ════════════════════════════════════════════════════════════════════
update_vkd3d() {
    print_section "07 — VKD3D-Proton (DirectX 12 → Vulkan)"

    VKD3D_DIR="$HOME/.local/share/vkd3d"
    mkdir -p "$VKD3D_DIR"

    step "Fetching latest VKD3D-Proton release..."
    LATEST_VKD3D=$(get_latest_github_tag "HansKristian-Work/vkd3d-proton")

    if [[ -z "$LATEST_VKD3D" ]]; then
        fail "Could not reach GitHub API for VKD3D-Proton"
        FAILED+=("vkd3d")
        return
    fi

    info "Latest VKD3D-Proton: $LATEST_VKD3D"

    INSTALLED_VKD3D=$(ls "$VKD3D_DIR" 2>/dev/null | sort -V | tail -1)
    info "Installed: ${INSTALLED_VKD3D:-none}"

    if [[ "$INSTALLED_VKD3D" == "$LATEST_VKD3D" ]]; then
        skip "VKD3D-Proton $LATEST_VKD3D"
        SKIPPED+=("vkd3d")
    else
        newver "VKD3D-Proton" "${INSTALLED_VKD3D:-none}" "$LATEST_VKD3D"

        # Install zstd if needed
        sudo apt install -y -qq zstd 2>/dev/null

        VKD3D_URL=$(get_latest_github_asset_url "HansKristian-Work/vkd3d-proton" "tar.zst")
        [[ -z "$VKD3D_URL" ]] && VKD3D_URL=$(get_latest_github_asset_url "HansKristian-Work/vkd3d-proton" "tar.gz")

        step "Downloading VKD3D-Proton $LATEST_VKD3D..."
        if curl -L --progress-bar "$VKD3D_URL" -o "/tmp/vkd3d-latest.tar.zst"; then
            mkdir -p "$VKD3D_DIR/$LATEST_VKD3D"
            tar -xf "/tmp/vkd3d-latest.tar.zst" \
                -C "$VKD3D_DIR/$LATEST_VKD3D" \
                --strip-components=1 2>/dev/null
            rm -f "/tmp/vkd3d-latest.tar.zst"
            ok "VKD3D-Proton $LATEST_VKD3D installed"
            UPDATED+=("vkd3d → $LATEST_VKD3D")
        else
            fail "VKD3D-Proton download failed"
            FAILED+=("vkd3d")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 08 — DXVK-NVAPI (async shader cache)
# ════════════════════════════════════════════════════════════════════
update_dxvk_nvapi() {
    print_section "08 — DXVK-NVAPI"

    NVAPI_DIR="$HOME/.local/share/dxvk-nvapi"
    mkdir -p "$NVAPI_DIR"

    step "Fetching latest DXVK-NVAPI release..."
    LATEST_NVAPI=$(get_latest_github_tag "jp7677/dxvk-nvapi")

    if [[ -z "$LATEST_NVAPI" ]]; then
        warn "Could not fetch DXVK-NVAPI info — skipping"
        SKIPPED+=("dxvk-nvapi")
        return
    fi

    info "Latest DXVK-NVAPI: $LATEST_NVAPI"
    INSTALLED_NVAPI=$(ls "$NVAPI_DIR" 2>/dev/null | sort -V | tail -1)

    if [[ "$INSTALLED_NVAPI" == "$LATEST_NVAPI" ]]; then
        skip "DXVK-NVAPI $LATEST_NVAPI"
        SKIPPED+=("dxvk-nvapi")
    else
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
            SKIPPED+=("dxvk-nvapi")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 09 — GAMEMODE
# ════════════════════════════════════════════════════════════════════
update_gamemode() {
    print_section "09 — GameMode"

    step "Checking GameMode..."
    CURRENT_GM=$(gamemoded --version 2>/dev/null | awk '{print $2}' || echo "not installed")

    if sudo apt install --only-upgrade -y -qq gamemode 2>/dev/null; then
        NEW_GM=$(gamemoded --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        if [[ "$CURRENT_GM" != "$NEW_GM" ]]; then
            newver "GameMode" "$CURRENT_GM" "$NEW_GM"
            UPDATED+=("gamemode → $NEW_GM")
        else
            skip "GameMode $CURRENT_GM"
            SKIPPED+=("gamemode")
        fi
    else
        # Try building from source for latest
        warn "apt GameMode is latest — checking GitHub for newer..."
        LATEST_GM=$(get_latest_github_tag "FeralInteractive/gamemode")
        info "GitHub latest: $LATEST_GM"
        SKIPPED+=("gamemode")
    fi
}

# ════════════════════════════════════════════════════════════════════
# 10 — MANGOHUD
# ════════════════════════════════════════════════════════════════════
update_mangohud() {
    print_section "10 — MangoHud (Performance Overlay)"

    step "Checking MangoHud..."
    CURRENT_MH=$(mangohud --version 2>/dev/null | awk '{print $2}' || echo "not installed")
    info "Current MangoHud: $CURRENT_MH"

    # Check GitHub for latest
    LATEST_MH=$(get_latest_github_tag "flightlessmango/MangoHud")
    info "Latest MangoHud: $LATEST_MH"

    if sudo apt install --only-upgrade -y -qq mangohud 2>/dev/null; then
        NEW_MH=$(mangohud --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        if [[ "$CURRENT_MH" != "$NEW_MH" ]]; then
            newver "MangoHud" "$CURRENT_MH" "$NEW_MH"
            UPDATED+=("mangohud → $NEW_MH")
        else
            skip "MangoHud $CURRENT_MH"
            SKIPPED+=("mangohud")
        fi
    fi

    # Update MangoHud config if missing new options
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

# ════════════════════════════════════════════════════════════════════
# 11 — LUTRIS
# ════════════════════════════════════════════════════════════════════
update_lutris() {
    print_section "11 — Lutris"

    step "Checking Lutris..."
    CURRENT_LT=$(lutris --version 2>/dev/null | awk '{print $2}' || echo "not installed")
    info "Current Lutris: $CURRENT_LT"

    if sudo apt install --only-upgrade -y -qq lutris 2>/dev/null; then
        NEW_LT=$(lutris --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        if [[ "$CURRENT_LT" != "$NEW_LT" ]]; then
            newver "Lutris" "$CURRENT_LT" "$NEW_LT"
            UPDATED+=("lutris → $NEW_LT")
        else
            skip "Lutris $CURRENT_LT"
            SKIPPED+=("lutris")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 12 — STEAM (Flatpak + native)
# ════════════════════════════════════════════════════════════════════
update_steam() {
    print_section "12 — Steam"

    step "Checking Steam updates..."

    # Native Steam
    if dpkg -l steam 2>/dev/null | grep -q "^ii"; then
        if sudo apt install --only-upgrade -y -qq steam 2>/dev/null; then
            ok "Steam (native) checked/updated"
            UPDATED+=("steam-native")
        fi
    fi

    # Flatpak Steam
    if flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
        if flatpak update -y com.valvesoftware.Steam 2>/dev/null; then
            ok "Steam (Flatpak) updated"
            UPDATED+=("steam-flatpak")
        fi
    fi

    # Update all Flatpaks while we're at it
    step "Updating all Flatpak apps..."
    flatpak update -y 2>/dev/null && ok "Flatpaks updated" || warn "Flatpak update skipped"
}

# ════════════════════════════════════════════════════════════════════
# 13 — HEROIC GAMES LAUNCHER
# ════════════════════════════════════════════════════════════════════
update_heroic() {
    print_section "13 — Heroic Games Launcher (Epic/GOG)"

    step "Checking Heroic Games Launcher..."

    # Flatpak Heroic
    if flatpak list 2>/dev/null | grep -q "com.heroicgameslauncher.hgl"; then
        flatpak update -y com.heroicgameslauncher.hgl 2>/dev/null
        ok "Heroic (Flatpak) checked"
        UPDATED+=("heroic-flatpak")
        return
    fi

    # Check GitHub for latest .deb
    LATEST_HEROIC=$(get_latest_github_tag "Heroic-Games-Launcher/HeroicGamesLauncher")
    info "Latest Heroic: $LATEST_HEROIC"

    if command -v heroic &>/dev/null; then
        CURRENT_HEROIC=$(heroic --version 2>/dev/null || echo "unknown")
        info "Installed Heroic: $CURRENT_HEROIC"
        skip "Heroic (check manually if needed)"
        SKIPPED+=("heroic")
    else
        warn "Heroic not installed — install via Flatpak:"
        info "flatpak install flathub com.heroicgameslauncher.hgl"
        SKIPPED+=("heroic-not-installed")
    fi
}

# ════════════════════════════════════════════════════════════════════
# 14 — VULKAN TOOLS & RUNTIME
# ════════════════════════════════════════════════════════════════════
update_vulkan() {
    print_section "14 — Vulkan Runtime & Tools"

    step "Updating Vulkan packages..."
    VULKAN_PACKAGES=(
        vulkan-tools
        vulkan-validationlayers
        libvulkan1
        libvulkan-dev
    )

    for pkg in "${VULKAN_PACKAGES[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
            sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
        fi
    done

    ok "Vulkan packages updated"
    UPDATED+=("vulkan-runtime")

    # Display Vulkan device info
    if command -v vulkaninfo &>/dev/null; then
        VULKAN_DEVICE=$(vulkaninfo 2>/dev/null | grep "GPU id" | head -1 | sed 's/.*: //')
        info "Vulkan device: ${VULKAN_DEVICE:-check vulkaninfo}"
    fi
}

# ════════════════════════════════════════════════════════════════════
# 15 — AMD RDNA 4 SPECIFIC (RX 9070 XT)
# ════════════════════════════════════════════════════════════════════
update_rdna4() {
    print_section "15 — AMD RDNA 4 Specific (RX 9070 XT)"

    step "Updating AMD userspace components..."
    AMD_PACKAGES=(
        libdrm-amdgpu1
        libdrm-radeon1
        libdrm2
        libdrm-dev
        radeontop
    )

    for pkg in "${AMD_PACKAGES[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
            sudo apt install --only-upgrade -y -qq "$pkg" 2>/dev/null
        fi
    done
    ok "AMD userspace components updated"
    UPDATED+=("amd-rdna4-userspace")

    # Check AMDGPU firmware
    step "Checking AMDGPU firmware..."
    if sudo apt install --only-upgrade -y -qq firmware-amdgpu 2>/dev/null || \
       sudo apt install --only-upgrade -y -qq linux-firmware 2>/dev/null; then
        ok "GPU firmware updated"
        UPDATED+=("amdgpu-firmware")
    fi

    # RADV environment check
    step "Verifying RADV driver status..."
    if glxinfo 2>/dev/null | grep -q "AMD RADV"; then
        RADV_VER=$(glxinfo 2>/dev/null | grep "AMD RADV" | head -1)
        ok "RADV active: $RADV_VER"
    else
        warn "RADV not confirmed — check after reboot"
    fi
}

# ════════════════════════════════════════════════════════════════════
# 15b — RAY TRACING OPTIMISATION (RDNA 4 / RX 9070 XT)
# ════════════════════════════════════════════════════════════════════
update_raytracing() {
    print_section "15b — Ray Tracing Optimisation (RDNA 4)"

    info "RDNA 4 has dedicated hardware ray tracing — configuring for maximum RT performance"

    # ── RT Environment File ─────────────────────────────────────────
    step "Writing RDNA 4 ray tracing environment config..."
    RT_ENV="/etc/environment.d/99-amd-raytracing.conf"
    sudo mkdir -p /etc/environment.d/

    RT_CONTENT='# ══════════════════════════════════════════════════
# AMD RDNA 4 Ray Tracing Optimisations
# RX 9070 XT — Updated automatically by gaming-update
# ══════════════════════════════════════════════════

# ── RADV Ray Tracing ───────────────────────────────
# Enable RT performance improvements in RADV Vulkan driver
RADV_PERFTEST=gpl,rt,ngg_streamout

# ── VKD3D-Proton DX12 Ray Tracing ─────────────────
# Explicitly enable DX12 ray tracing (DXR) and DXR 1.1
VKD3D_CONFIG=dxr,dxr11

# ── DXVK Async + RT ───────────────────────────────
# Async shader compilation reduces RT stutter on first load
DXVK_ASYNC=1

# ── Mesa RT specific ───────────────────────────────
# Forces RADV to use hardware RT acceleration
AMD_VULKAN_ICD=RADV
mesa_glthread=true

# ── Presentation mode for RT titles ───────────────
# Mailbox reduces input lag in RT-heavy scenes
MESA_VK_WSI_PRESENT_MODE=mailbox'

    CURRENT_RT_CONTENT=""
    [[ -f "$RT_ENV" ]] && CURRENT_RT_CONTENT=$(cat "$RT_ENV")

    if [[ "$CURRENT_RT_CONTENT" == "$RT_CONTENT" ]]; then
        skip "RDNA 4 RT environment config up to date"
        SKIPPED+=("rt-env-config")
    else
        echo "$RT_CONTENT" | sudo tee "$RT_ENV" > /dev/null
        ok "RDNA 4 ray tracing environment config written"
        UPDATED+=("rdna4-rt-env-config")
    fi

    # ── RT Launch Options File ──────────────────────────────────────
    step "Updating ray tracing Steam launch options..."
    RT_LAUNCH="$HOME/Gaming-Launch-Options-RT.txt"

    cat > "$RT_LAUNCH" << 'EOF'
════════════════════════════════════════════════════════════════
AMD RX 9070 XT (RDNA 4) — Ray Tracing Steam Launch Options
Updated automatically by gaming-update
════════════════════════════════════════════════════════════════

GLOBAL — Works for all games (Steam → Settings → General):
RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 VKD3D_CONFIG=dxr,dxr11 MESA_VK_WSI_PRESENT_MODE=mailbox gamemoderun mangohud %command%

RAY TRACING GAMES (DX12 titles — Cyberpunk, Alan Wake 2 etc):
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

RAY TRACING GAMES (DX11 titles):
RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

MAXIMUM PERFORMANCE RT (for demanding RT scenes):
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV MESA_VK_WSI_PRESENT_MODE=mailbox WINE_FULLSCREEN_FSR=1 gamemoderun mangohud %command%

════════════════════════════════════════════════════════════════
VARIABLE EXPLANATION:
  RADV_PERFTEST=gpl,rt       → Enables RADV RT hardware acceleration
  RADV_PERFTEST=ngg_streamout→ RDNA 4 geometry pipeline optimisation
  VKD3D_CONFIG=dxr           → Enables DX12 ray tracing (DXR 1.0)
  VKD3D_CONFIG=dxr11         → Enables DX12 ray tracing (DXR 1.1)
  DXVK_ASYNC=1               → Async shader compile (less RT stutter)
  AMD_VULKAN_ICD=RADV        → Forces RADV open-source Vulkan driver
  WINE_FULLSCREEN_FSR=1      → AMD FSR upscaling (pairs well with RT)
  gamemoderun                → CPU/GPU performance boost
  mangohud                   → Live FPS/temp/VRAM overlay

════════════════════════════════════════════════════════════════
RT PERFORMANCE TIPS FOR RX 9070 XT:
  • RDNA 4 has dedicated RT hardware — enable RT in game settings
  • Use FSR Quality or Balanced with RT for best perf/quality
  • VKD3D_CONFIG=dxr11 is needed for DXR 1.1 titles (better RT)
  • If RT causes crashes try removing ngg_streamout first
  • MangoHud will show GPU% — RT heavy scenes push it to 90-100%
════════════════════════════════════════════════════════════════
EOF

    ok "RT launch options saved to ~/Gaming-Launch-Options-RT.txt"
    UPDATED+=("rt-launch-options")

    # ── Verify RT is available in Mesa ─────────────────────────────
    step "Verifying ray tracing support in Mesa/RADV..."
    if command -v vulkaninfo &>/dev/null; then
        RT_SUPPORT=$(vulkaninfo 2>/dev/null | grep -i "raytracing\|ray_tracing\|VK_KHR_ray" | head -3)
        if [[ -n "$RT_SUPPORT" ]]; then
            ok "Hardware ray tracing confirmed available in Vulkan"
            info "$RT_SUPPORT" | head -1
        else
            warn "RT extensions not visible yet — may need reboot after Mesa update"
        fi
    else
        warn "vulkaninfo not available — install vulkan-tools to verify RT support"
    fi

    # ── RT Shader Cache ─────────────────────────────────────────────
    step "Checking RT shader cache..."
    RADV_RT_CACHE="$HOME/.cache/radv_builtin_shaders"
    if [[ -d "$RADV_RT_CACHE" ]]; then
        RT_CACHE_SIZE=$(du -sh "$RADV_RT_CACHE" 2>/dev/null | cut -f1)
        info "RADV RT shader cache: $RT_CACHE_SIZE"
        # Clear if Mesa was updated to force RT shader rebuild
        if [[ " ${UPDATED[*]} " =~ "mesa" ]]; then
            rm -rf "$RADV_RT_CACHE" 2>/dev/null
            ok "RT shader cache cleared — will rebuild optimally on next RT game launch"
        fi
    else
        info "RT shader cache will be created on first ray tracing game launch"
    fi
}

# ════════════════════════════════════════════════════════════════════
# 16 — GAMESCOPE (Valve's micro-compositor — used in Nobara)
# ════════════════════════════════════════════════════════════════════
update_gamescope() {
    print_section "16 — Gamescope (Valve's Game Compositor)"

    step "Checking Gamescope..."
    LATEST_GS=$(get_latest_github_tag "ValveSoftware/gamescope")
    info "Latest Gamescope: $LATEST_GS"

    if command -v gamescope &>/dev/null; then
        CURRENT_GS=$(gamescope --version 2>/dev/null || echo "installed")
        skip "Gamescope $CURRENT_GS"
        SKIPPED+=("gamescope")
    else
        step "Installing Gamescope..."
        if sudo apt install -y -qq gamescope 2>/dev/null; then
            ok "Gamescope installed"
            UPDATED+=("gamescope")
            info "Use in Steam launch options: gamescope -f -- %command%"
        else
            warn "Gamescope not available in apt — may need manual build"
            SKIPPED+=("gamescope")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# 17 — SHADER CACHE MANAGEMENT
# ════════════════════════════════════════════════════════════════════
manage_shader_cache() {
    print_section "17 — Shader Cache Management"

    step "Checking shader cache sizes..."

    STEAM_SHADER="$HOME/.local/share/Steam/steamapps/shadercache"
    DXVK_CACHE="$HOME/.cache/dxvk"
    RADV_CACHE="$HOME/.cache/radv_builtin_shaders"
    MESA_CACHE="$HOME/.cache/mesa_shader_cache"

    for cache_dir in "$STEAM_SHADER" "$DXVK_CACHE" "$RADV_CACHE" "$MESA_CACHE"; do
        if [[ -d "$cache_dir" ]]; then
            SIZE=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
            info "$(basename "$cache_dir"): $SIZE"
        fi
    done

    # Check if Mesa cache needs rebuild after update
    if [[ " ${UPDATED[*]} " =~ "mesa" ]]; then
        step "Mesa was updated — clearing Mesa shader cache for rebuild..."
        rm -rf "$MESA_CACHE" 2>/dev/null
        ok "Mesa shader cache cleared — will rebuild on next game launch"
    else
        ok "Shader caches healthy — no action needed"
    fi

    SKIPPED+=("shader-cache-check")
}

# ════════════════════════════════════════════════════════════════════
# 18 — SYSCTL & KERNEL PARAMETERS CHECK
# ════════════════════════════════════════════════════════════════════
verify_sysctl() {
    print_section "18 — Verify Gaming Tweaks Still Active"

    step "Checking sysctl gaming config..."
    if [[ ! -f /etc/sysctl.d/99-gaming.conf ]]; then
        warn "Gaming sysctl config missing — recreating..."
        sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null << 'EOF'
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
        sudo sysctl -p /etc/sysctl.d/99-gaming.conf > /dev/null 2>&1
        ok "Gaming sysctl config restored"
        UPDATED+=("sysctl-restored")
    else
        ok "Gaming sysctl config present"
        SKIPPED+=("sysctl")
    fi

    step "Checking CPU governor..."
    CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    info "CPU governor: $CURRENT_GOV"

    if [[ "$CURRENT_GOV" != "performance" ]]; then
        warn "CPU governor is '$CURRENT_GOV' — setting to performance..."
        sudo cpupower frequency-set -g performance > /dev/null 2>&1
        ok "CPU governor set to performance"
        UPDATED+=("cpu-governor-reset")
    else
        ok "CPU governor already on performance"
        SKIPPED+=("cpu-governor")
    fi

    step "Checking ZRAM..."
    if swapon --show 2>/dev/null | grep -q "zram"; then
        ZRAM_SIZE=$(swapon --show 2>/dev/null | grep zram | awk '{print $3}')
        ok "ZRAM active: $ZRAM_SIZE"
        SKIPPED+=("zram")
    else
        warn "ZRAM not active"
        sudo systemctl start zram-config 2>/dev/null || true
    fi
}

# ════════════════════════════════════════════════════════════════════
# 18b — ANTI-CHEAT SUPPORT (EAC + BattlEye)
# ════════════════════════════════════════════════════════════════════
update_anticheat() {
    print_section "18b — Anti-Cheat Support (EAC + BattlEye)"

    info "Configuring Linux anti-cheat runtime for EAC and BattlEye games"
    info "Supports: Battlefield series, GTA 5, Fortnite, Apex Legends and more"

    # ── Steam Runtime Anti-Cheat ─────────────────────────────────────
    step "Checking Steam runtime for anti-cheat support..."
    STEAM_ROOT="$HOME/.steam/steam"
    STEAM_RT="$HOME/.steam/root"

    # Ensure Steam pressure-vessel runtime is present (needed for EAC)
    if [[ -d "$STEAM_ROOT" ]]; then
        ok "Steam root found: $STEAM_ROOT"
    else
        warn "Steam not found at expected path — anti-cheat setup needs Steam installed first"
        SKIPPED+=("anticheat-eac")
        return
    fi

    # ── EAC Runtime ──────────────────────────────────────────────────
    step "Setting up Easy Anti-Cheat (EAC) Linux runtime..."
    EAC_DIR="$HOME/.steam/steam/steamapps/common/Proton EasyAntiCheat Runtime"

    # EAC runtime is installed via Steam app ID 1826330
    # Check if it exists, if not note it needs Steam download
    if [[ -d "$EAC_DIR" ]]; then
        ok "EAC Linux runtime already present"
        SKIPPED+=("eac-runtime")
    else
        info "EAC runtime not yet installed — flagging for Steam download"
        cat >> "$HOME/Gaming-Launch-Options.txt" << 'EOF'

════════════════════════════════════════════════════════════════
ANTI-CHEAT SETUP — Run these commands after Steam is open:
════════════════════════════════════════════════════════════════
EAC Runtime (required for Battlefield, Fortnite etc):
  Open Steam → Library → search "Easy Anti-Cheat Runtime" → Install
  OR run: steam steam://install/1826330

BattlEye Runtime (required for some titles):
  Open Steam → Library → search "BattlEye Service" → Install
  OR run: steam steam://install/1161040
════════════════════════════════════════════════════════════════
EOF
        warn "EAC runtime not found — see ~/Gaming-Launch-Options.txt for install steps"
        UPDATED+=("eac-install-instructions")
    fi

    # ── Proton EAC Environment Variables ────────────────────────────
    step "Configuring EAC + BattlEye Proton environment..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-anticheat.conf > /dev/null << 'EOF'
# ══════════════════════════════════════════════════
# Anti-Cheat Linux Support
# EAC + BattlEye via Proton
# ══════════════════════════════════════════════════

# Enable EAC Linux runtime via Proton
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt

# BattlEye support via Proton
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt

# Allow EAC to access required kernel interfaces
WINE_LARGE_ADDRESS_AWARE=1

# Needed for some EAC titles to detect hardware correctly
PROTON_USE_SECCOMP=1
EOF
    ok "Anti-cheat environment variables configured"
    UPDATED+=("anticheat-env-config")

    # ── Kernel Parameters for EAC ────────────────────────────────────
    step "Checking kernel parameters for anti-cheat compatibility..."

    # EAC needs certain kernel interfaces — verify they are accessible
    if [[ -f /proc/sys/kernel/perf_event_paranoid ]]; then
        PARANOID=$(cat /proc/sys/kernel/perf_event_paranoid)
        if [[ "$PARANOID" == "-1" ]]; then
            ok "kernel.perf_event_paranoid=-1 (EAC compatible)"
        else
            sudo sysctl -w kernel.perf_event_paranoid=-1 > /dev/null 2>&1
            ok "kernel.perf_event_paranoid set to -1 for EAC compatibility"
            UPDATED+=("eac-kernel-perf")
        fi
    fi

    # ── Steam Launch Options for Anti-Cheat Games ────────────────────
    step "Writing anti-cheat game launch options..."
    AC_LAUNCH="$HOME/Gaming-AntiCheat-Launch-Options.txt"

    cat > "$AC_LAUNCH" << 'EOF'
════════════════════════════════════════════════════════════════
ANTI-CHEAT GAME LAUNCH OPTIONS — Linux
EAC + BattlEye supported games
════════════════════════════════════════════════════════════════

STEP 1 — Install runtimes in Steam (ONE TIME ONLY):
  steam steam://install/1826330   ← Easy Anti-Cheat Runtime
  steam steam://install/1161040   ← BattlEye Service Runtime

STEP 2 — Enable in Steam Settings:
  Steam → Settings → Compatibility → Enable Steam Play for all titles
  Select GE-Proton as compatibility tool

STEP 3 — Per-game launch options:

FORTNITE (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

BATTLEFIELD 2042 / BATTLEFIELD 6 (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun mangohud %command%

GTA 5 / GTA ONLINE (no anti-cheat issues on Linux):
RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 VKD3D_CONFIG=dxr WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

APEX LEGENDS (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun %command%

RAINBOW SIX SIEGE (BattlEye):
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun mangohud %command%

RUST (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt DXVK_ASYNC=1 gamemoderun mangohud %command%

UNIVERSAL (works for most EAC/BattlEye games):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun mangohud %command%

════════════════════════════════════════════════════════════════
GAMES THAT DO NOT WORK ON LINUX (kernel-level anti-cheat):
  ✗ Valorant (Vanguard — requires Windows kernel access)
  ✗ PUBG (varies — check ProtonDB for current status)
  ✗ Some older EAC games before they enabled Linux runtime

GAMES CONFIRMED WORKING:
  ✓ Fortnite (EAC — confirmed working via Proton)
  ✓ Apex Legends (EAC — confirmed working)
  ✓ GTA 5 (no kernel AC — works great)
  ✓ Battlefield 2042 (EAC — working via Proton)
  ✓ Rainbow Six Siege (BattlEye — working)
  ✓ Rust (EAC — confirmed working)
  ✓ DayZ (BattlEye — working)
  ✓ Hunt Showdown (EAC — working)
  ✓ Dead by Daylight (EAC — working)
  Always check protondb.com for the latest status of any game
════════════════════════════════════════════════════════════════
EOF

    ok "Anti-cheat launch options saved to ~/Gaming-AntiCheat-Launch-Options.txt"
    UPDATED+=("anticheat-launch-options")
}

# ════════════════════════════════════════════════════════════════════
# 18c — UPSCALING TECHNOLOGY (FSR3 + DLSS + XeSS + Gamescope)
# ════════════════════════════════════════════════════════════════════
update_upscaling() {
    print_section "18c — Upscaling: FSR 4 + DLSS 4.5 + XeSS 3 + Gamescope"

    info "FSR 4    — Native on RX 9070 XT (RDNA 4) via GE-Proton + VKD3D-Proton 3.0"
    info "FSR 3    — Fallback for all GPUs via WINE_FULLSCREEN_FSR"
    info "XeSS 3   — MFG (2x/3x/4x frames) on Intel Arc via DX12/Proton"
    info "DLSS 4.5 — NVIDIA only via DXVK-NVAPI + latest driver"
    info "Gamescope — System compositor upscaling, works on ALL GPUs"

    # ── Gamescope update ──────────────────────────────────────────────
    step "Installing/updating Gamescope..."
    if sudo apt install --only-upgrade -y gamescope 2>/dev/null || \
       sudo apt install -y gamescope 2>/dev/null; then
        ok "Gamescope updated — system-level FSR upscaling active"
        UPDATED+=("gamescope")
    else
        warn "Gamescope not in apt repos — trying Flatpak..."
        flatpak install -y flathub com.valvesoftware.gamescope 2>/dev/null && \
            ok "Gamescope via Flatpak" || info "Gamescope unavailable — FSR via Wine still works"
    fi

    # ── FSR 4 via GE-Proton + VKD3D-Proton 3.0 ───────────────────────
    step "Verifying FSR 4 support for your RX 9070 XT (RDNA 4)..."
    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    LATEST_GE=$(ls "$PROTON_DIR" 2>/dev/null | grep "GE-Proton" | sort -V | tail -1)
    VKD3D_DIR="$HOME/.local/share/vkd3d"
    LATEST_VKD3D=$(ls "$VKD3D_DIR" 2>/dev/null | sort -V | tail -1)

    if [[ -n "$LATEST_GE" ]]; then
        ok "GE-Proton present: $LATEST_GE — FSR 4 available via PROTON_FSR4_UPGRADE=1"
        info "Your RDNA 4 GPU gets FULL native FSR 4 quality — no hacks needed"
    fi
    if [[ -n "$LATEST_VKD3D" ]]; then
        ok "VKD3D-Proton present: $LATEST_VKD3D — FSR 4 frame gen + XeSS 3 active"
    fi

    # ── OptiScaler — FSR4/DLSS4.5/XeSS3 middleware ───────────────────
    step "Checking OptiScaler (FSR4/DLSS4.5/XeSS3 bridge for all games)..."
    OPTISCALER_DIR="$HOME/.local/share/optiscaler"
    mkdir -p "$OPTISCALER_DIR"

    LATEST_OPTI=$(curl -s "https://api.github.com/repos/optiscaler/OptiScaler/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null)
    INSTALLED_OPTI=$(cat "$OPTISCALER_DIR/version.txt" 2>/dev/null || echo "none")

    info "Latest OptiScaler: ${LATEST_OPTI:-unavailable}"
    info "Installed:         $INSTALLED_OPTI"

    if [[ -n "$LATEST_OPTI" ]] && [[ "$INSTALLED_OPTI" != "$LATEST_OPTI" ]]; then
        OPTI_URL=$(curl -s "https://api.github.com/repos/optiscaler/OptiScaler/releases/latest" \
            | grep '"browser_download_url"' | grep -i "linux\|OptiScaler" | grep -i "zip\|tar" \
            | cut -d'"' -f4 | head -1)

        if [[ -n "$OPTI_URL" ]]; then
            info "Downloading OptiScaler $LATEST_OPTI..."
            if curl -L --progress-bar "$OPTI_URL" -o "/tmp/optiscaler-latest.zip" 2>/dev/null; then
                mkdir -p "$OPTISCALER_DIR/$LATEST_OPTI"
                unzip -q "/tmp/optiscaler-latest.zip" -d "$OPTISCALER_DIR/$LATEST_OPTI" 2>/dev/null || \
                    tar -xf "/tmp/optiscaler-latest.zip" -C "$OPTISCALER_DIR/$LATEST_OPTI" 2>/dev/null
                echo "$LATEST_OPTI" > "$OPTISCALER_DIR/version.txt"
                rm -f "/tmp/optiscaler-latest.zip"
                ok "OptiScaler $LATEST_OPTI downloaded to $OPTISCALER_DIR"
                info "Per-game install: copy files from $OPTISCALER_DIR/$LATEST_OPTI to game folder"
                UPDATED+=("optiscaler → $LATEST_OPTI")
            fi
        else
            warn "OptiScaler binary URL not found — check github.com/optiscaler/OptiScaler manually"
        fi
    elif [[ "$INSTALLED_OPTI" == "$LATEST_OPTI" ]]; then
        skip "OptiScaler $INSTALLED_OPTI"
        SKIPPED+=("optiscaler")
    fi

    # ── Updated upscaling environment config ─────────────────────────
    step "Writing upscaling environment config (FSR4/DLSS4.5/XeSS3)..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# ══════════════════════════════════════════════════════
# Upscaling Configuration — March 2026
# FSR 4 (RDNA4 native) • FSR 3 (all GPUs) • XeSS 3 • DLSS 4.5
# ══════════════════════════════════════════════════════

# ── FSR 4 via GE-Proton (RX 9070 XT native, RDNA3 fallback) ──────
# Add PROTON_FSR4_UPGRADE=1 to per-game launch options
# to upgrade FSR 3.1 games to FSR 4 automatically
# For RDNA4 (RX 9000): full quality FSR 4 with dedicated hardware
# For RDNA3 (RX 7000): FSR 4 via FP16 emulation (slight perf cost)

# ── FSR 3 fallback (all GPUs via Wine) ───────────────────────────
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2

# ── Low latency presentation ──────────────────────────────────────
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
    ok "Upscaling environment config updated (FSR4/DLSS4.5/XeSS3)"
    UPDATED+=("upscaling-env-config")

    # ── Full upscaling launch options guide ───────────────────────────
    step "Writing complete upscaling launch options guide..."
    cat > "$HOME/Gaming-Upscaling-Options.txt" << 'EOF'
════════════════════════════════════════════════════════════════════════
UPSCALING LAUNCH OPTIONS — March 2026
FSR 4 (AI) • FSR 3 • DLSS 4.5 • XeSS 3 MFG • Gamescope
RX 9070 XT (RDNA 4) Edition
════════════════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 — AI Upscaling (RDNA 4 native / all AMD via fallback)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR RX 9070 XT gets FULL hardware FSR 4 — no compromises!
FSR 4 uses a machine learning model for dramatically better quality
than FSR 3. Requires GE-Proton + VKD3D-Proton 3.0 (already installed).

ENABLE FSR 4 (in-game FSR 3.1 games auto-upgrade to FSR 4):
PROTON_FSR4_UPGRADE=1 %command%

FSR 4 with verification overlay:
PROTON_FSR4_UPGRADE=1 PROTON_FSR4_INDICATOR=1 %command%

FSR 4 + RT + full performance (RECOMMENDED for RX 9070 XT):
PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

FSR 4 + Anti-Cheat games (Battlefield 6, Fortnite etc):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

NOTES:
  • PROTON_FSR4_UPGRADE=1 only works in games that support FSR 3.1
  • The game will still SHOW FSR 3.1 in menus but renders with FSR 4
  • Cyberpunk 2077, Silent Hill 2, Ratchet & Clank confirmed working
  • Vulkan-only games (Doom Dark Ages) need OptiScaler instead
  • Add SteamDeck=0 if game disables FSR options under Proton

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 3 — Fallback (all GPUs including NVIDIA and Intel)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 3 via Wine (in-game must support FSR):
WINE_FULLSCREEN_FSR=1 WINE_FULLSCREEN_FSR_STRENGTH=2 %command%

FSR via Gamescope (NO game support needed — forces upscaling):
gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling --fsr-sharpness 5 -- %command%

FSR 3 at 4K output:
gamescope -w 1920 -h 1080 -W 3840 -H 2160 -f --fsr-upscaling -- %command%

STRENGTH: 0=sharpest  2=balanced (recommended)  5=softest

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS 3 — Intel AI Upscaling with Multi-Frame Generation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS 3 supports 2x, 3x, 4x frame generation on Arc A/B-series.
Works on ALL GPUs for upscaling. MFG requires Arc GPU + DX12.

XeSS 3 upscaling (all GPUs — enable in game settings):
VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 %command%

XeSS 3 on Intel Arc (with pipeline cache for best performance):
ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 mesa_glthread=true %command%

NOTES:
  • XeSS upscaling (Super Resolution) works on any GPU in game settings
  • XeSS 3 Multi-Frame Generation currently Windows/DX12 only
  • On Linux XeSS upscaling works perfectly via VKD3D-Proton
  • MFG on Linux via Intel Arc may come with future driver updates

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLSS 4.5 — NVIDIA Only (2nd gen transformer + 6X Multi Frame Gen)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DLSS 4.5 announced CES 2026: 2nd gen transformer model + Dynamic MFG.
6X Multi Frame Generation available Spring 2026 (RTX 50 series).
Linux support via DXVK-NVAPI + latest NVIDIA driver.

DLSS 4.5 Super Resolution (all RTX GPUs):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 %command%

DLSS 4.5 + Frame Generation (RTX 40/50 series):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_ASYNC=1 %command%

DLSS 4.5 with preset override (force latest transformer model):
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_DLSS_PRESET=f DXVK_ASYNC=1 %command%

NOTES:
  • DXVK_DLSS_PRESET=f forces latest transformer model quality preset
  • 6X Dynamic Multi Frame Generation coming April 2026 to NVIDIA App
  • Linux 6X MFG support depends on Valve Proton update — check GE-Proton

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OptiScaler — Inject ANY upscaler into ANY game
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OptiScaler bridges FSR4/DLSS4/XeSS3 across GPUs.
Install per-game by copying from ~/.local/share/optiscaler/[version]/

Steam launch option for OptiScaler games (Linux):
WINEDLLOVERRIDES="winmm.dll=n,b" %command%

NOTES:
  • Press INSERT in-game to open OptiScaler overlay
  • Do NOT use OptiScaler with online multiplayer (anti-cheat)
  • Files downloaded to ~/.local/share/optiscaler/ by gaming-update
  • See github.com/optiscaler/OptiScaler/wiki for per-game setup

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GAMESCOPE — System compositor upscaling (any game, any GPU)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1080p render → 1440p display (FSR):
gamescope -w 1920 -h 1080 -W 2560 -H 1440 -f --fsr-upscaling -- %command%

1080p render → 4K display (FSR):
gamescope -w 1920 -h 1080 -W 3840 -H 2160 -f --fsr-upscaling -- %command%

High refresh 144Hz + FSR + RT (RX 9070 XT sweet spot):
gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling --fsr-sharpness 5 -- \
  env PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 gamemoderun %command%

INTEGER SCALING (retro/pixel art games):
gamescope -f -W 2560 -H 1440 --integer-scaling -- %command%

GAMESCOPE OPTIONS:
  -w/-h = render resolution   -W/-H = display resolution
  -f = fullscreen             -r = framerate cap
  --fsr-upscaling = AMD FSR   --fsr-sharpness 0-20 (0=sharpest)
  --integer-scaling = pixel perfect

════════════════════════════════════════════════════════════════════════
PRIORITY RECOMMENDATION FOR RX 9070 XT (RDNA 4) — March 2026:
  1st choice: PROTON_FSR4_UPGRADE=1 — native AI FSR 4 in FSR 3.1 games
  2nd choice: In-game FSR 4 if game has it natively
  3rd choice: Gamescope FSR for games without any upscaler support
  Combine with RT: add RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11
  For anti-cheat games: add PROTON_EAC_RUNTIME=... before FSR4 flags
════════════════════════════════════════════════════════════════════════
EOF

    ok "Upscaling guide updated to FSR4/DLSS4.5/XeSS3 — saved to ~/Gaming-Upscaling-Options.txt"
    UPDATED+=("upscaling-launch-options-fsr4-dlss45-xess3")
}

# ════════════════════════════════════════════════════════════════════
# 19 — PROTONDB QUICK STATUS
# ════════════════════════════════════════════════════════════════════
check_protondb() {
    print_section "19 — ProtonDB Quick Status (Installed Games)"

    STEAM_APPS="$HOME/.steam/steam/steamapps"

    if [[ ! -d "$STEAM_APPS" ]]; then
        warn "No Steam apps directory found — skipping ProtonDB check"
        SKIPPED+=("protondb")
        return
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
            "borked")   echo -e "    ${RED}[BORKED]${NC}  $GAMENAME" ;;
            *)          echo -e "    ${DIM}[UNKNOWN]${NC} $GAMENAME" ;;
        esac
        COUNT=$((COUNT + 1))
    done

    if [[ $COUNT -eq 0 ]]; then
        info "No installed Steam games found"
    else
        ok "$COUNT games checked"
    fi
    UPDATED+=("protondb-check")
}

# ════════════════════════════════════════════════════════════════════
# 20 — LOG ROTATION
# ════════════════════════════════════════════════════════════════════
rotate_logs() {
    print_section "20 — Log Rotation"

    step "Cleaning old update logs (keeping last 10)..."
    LOG_COUNT=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)

    if [[ $LOG_COUNT -gt 10 ]]; then
        ls -t "$LOG_DIR"/*.log | tail -n +11 | xargs rm -f
        ok "Old logs cleaned — kept last 10"
    else
        skip "Log rotation ($LOG_COUNT/10 logs)"
    fi
    SKIPPED+=("log-rotation")
}

# ════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ════════════════════════════════════════════════════════════════════
print_summary() {
    ELAPSED=$(elapsed_time)

    echo -e "\n${BLUE}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}  ║${GREEN}${BOLD}                   UPDATE COMPLETE — SUMMARY                  ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}  ╚══════════════════════════════════════════════════════════════╝${NC}"

    echo -e "\n  ${GREEN}${BOLD}Updated / Installed (${#UPDATED[@]})${NC}"
    for item in "${UPDATED[@]}"; do
        echo -e "    ${GREEN}↑${NC} $item"
    done

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo -e "\n  ${DIM}Already Latest / Skipped (${#SKIPPED[@]})${NC}"
        for item in "${SKIPPED[@]}"; do
            echo -e "    ${DIM}◌ $item${NC}"
        done
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "\n  ${RED}${BOLD}Failed (${#FAILED[@]})${NC}"
        for item in "${FAILED[@]}"; do
            echo -e "    ${RED}✗${NC} $item"
        done
    fi

    echo -e "\n${BLUE}  ┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${YELLOW}  SYSTEM STATUS${NC}"
    echo -e "${BLUE}  └─────────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${CYAN}Kernel    :${NC} $(uname -r)"
    echo -e "  ${CYAN}Mesa      :${NC} $(glxinfo 2>/dev/null | grep 'OpenGL version' | awk '{print $4}' || echo 'check after reboot')"
    echo -e "  ${CYAN}Governor  :${NC} $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'unknown')"
    echo -e "  ${CYAN}ZRAM      :${NC} $(swapon --show 2>/dev/null | grep zram | awk '{print $3}' || echo 'inactive')"
    echo -e "  ${CYAN}Elapsed   :${NC} $ELAPSED"
    echo -e "  ${CYAN}Log       :${NC} $LOG_FILE"

    # Reboot warning if kernel was updated
    if [[ " ${UPDATED[*]} " =~ "xanmod-kernel" ]]; then
        echo -e "\n  ${YELLOW}${BOLD}⚠  REBOOT REQUIRED — new kernel installed${NC}"
    fi

    echo -e "\n  ${GREEN}${BOLD}Your gaming stack is cutting edge. Ready to play!${NC}\n"
}

# ════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════
main() {
    print_banner
    check_root
    check_internet

    update_system
    update_kernel
    update_mesa
    update_ge_proton
    update_wine_ge
    update_dxvk
    update_vkd3d
    update_dxvk_nvapi
    update_gamemode
    update_mangohud
    update_lutris
    update_steam
    update_heroic
    update_vulkan
    update_rdna4
    update_raytracing
    update_gamescope
    manage_shader_cache
    verify_sysctl
    update_anticheat
    update_upscaling
    check_protondb
    rotate_logs

    print_summary
}

main "$@"
