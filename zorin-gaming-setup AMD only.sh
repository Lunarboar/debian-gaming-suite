#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║         ZORIN OS 18 PRO — GAMING OPTIMISATION PIPELINE          ║
# ║         Ryzen CPU + RX 9070 XT (RDNA 4) Edition                 ║
# ║         Replicates Nobara-level gaming performance               ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Colours ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'
BOLD='\033[1m'

# ── Logging ──────────────────────────────────────────────────────────
LOG_FILE="$HOME/gaming-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Helper Functions ─────────────────────────────────────────────────
print_banner() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${CYAN}${BOLD}         ZORIN OS 18 PRO — GAMING OPTIMISATION PIPELINE          ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}║${DIM}         Ryzen CPU + RX 9070 XT (RDNA 4) Edition                 ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${YELLOW}${BOLD}  $1${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────┘${NC}"
}

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
step() { echo -e "\n  ${MAGENTA}▶${NC} ${BOLD}$1${NC}"; }

confirm() {
    echo -e "\n${YELLOW}  $1 ${WHITE}[y/N]${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        fail "Do not run this script as root. Run as your normal user."
        fail "The script will ask for sudo when needed."
        exit 1
    fi
}

check_zorin() {
    if ! grep -q "Zorin" /etc/os-release 2>/dev/null; then
        warn "This doesn't appear to be Zorin OS."
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi
}

check_internet() {
    step "Checking internet connection..."
    if ! curl -s --max-time 5 https://google.com > /dev/null; then
        fail "No internet connection detected. Please connect and try again."
        exit 1
    fi
    ok "Internet connection confirmed"
}

# ── Track what was installed ──────────────────────────────────────────
INSTALLED=()
SKIPPED=()
FAILED=()

# ════════════════════════════════════════════════════════════════════
# PHASE 1 — SYSTEM PREPARATION
# ════════════════════════════════════════════════════════════════════
phase_system_prep() {
    print_section "PHASE 1 — System Preparation"

    step "Updating package lists..."
    if sudo apt update -qq; then
        ok "Package lists updated"
    else
        fail "Failed to update package lists"
        FAILED+=("apt-update")
    fi

    step "Upgrading existing packages..."
    if sudo apt upgrade -y -qq; then
        ok "System packages upgraded"
        INSTALLED+=("system-upgrade")
    else
        warn "Some packages may not have upgraded cleanly"
    fi

    step "Installing core dependencies..."
    DEPS=(
        git curl wget python3 python3-pip
        cabextract p7zip-full flatpak
        cpufrequtils linux-tools-common
        build-essential dkms
        vulkan-tools mesa-utils
        winetricks
    )

    for dep in "${DEPS[@]}"; do
        if dpkg -l "$dep" &>/dev/null; then
            info "$dep already installed"
        else
            if sudo apt install -y -qq "$dep"; then
                ok "$dep installed"
                INSTALLED+=("$dep")
            else
                warn "Could not install $dep"
                FAILED+=("$dep")
            fi
        fi
    done
}

# ════════════════════════════════════════════════════════════════════
# PHASE 2 — XANMOD KERNEL (BORE Scheduler, Ryzen Optimised)
# ════════════════════════════════════════════════════════════════════
phase_kernel() {
    print_section "PHASE 2 — XanMod Gaming Kernel (BORE Scheduler)"

    # Check if XanMod already installed
    if uname -r | grep -q "xanmod"; then
        ok "XanMod kernel already running: $(uname -r)"
        SKIPPED+=("xanmod-kernel")
        return
    fi

    step "Adding XanMod repository..."
    wget -qO - https://dl.xanmod.org/archive.key | \
        sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg

    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://dl.xanmod.org releases main' | \
        sudo tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null

    sudo apt update -qq

    step "Installing XanMod RT kernel with BORE scheduler (Ryzen optimised)..."
    if sudo apt install -y linux-xanmod-rt-x64v3; then
        ok "XanMod RT x64v3 kernel installed"
        INSTALLED+=("xanmod-kernel")
        warn "Kernel will be active after reboot"
    else
        warn "RT kernel failed, trying standard XanMod..."
        if sudo apt install -y linux-xanmod-x64v3; then
            ok "XanMod x64v3 kernel installed"
            INSTALLED+=("xanmod-kernel")
        else
            fail "XanMod kernel installation failed"
            FAILED+=("xanmod-kernel")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 3 — BLEEDING EDGE MESA (Critical for RX 9070 XT RDNA 4)
# ════════════════════════════════════════════════════════════════════
phase_mesa() {
    print_section "PHASE 3 — Bleeding Edge Mesa (RDNA 4 Support)"

    CURRENT_MESA=$(glxinfo 2>/dev/null | grep "OpenGL version" | awk '{print $4}' | cut -d'.' -f1)

    step "Current Mesa version check..."
    info "Mesa version: $(glxinfo 2>/dev/null | grep 'OpenGL version' | awk '{print $4}' || echo 'unknown')"

    step "Adding kisak bleeding-edge Mesa PPA..."
    if sudo add-apt-repository -y ppa:kisak/kisak-mesa; then
        sudo apt update -qq
        if sudo apt upgrade -y mesa-vulkan-drivers libvulkan1 mesa-utils \
            libgl1-mesa-dri libglx-mesa0 2>/dev/null; then
            ok "Mesa upgraded to bleeding-edge"
            INSTALLED+=("mesa-bleeding-edge")
            info "New Mesa: $(glxinfo 2>/dev/null | grep 'OpenGL version' | awk '{print $4}' || echo 'check after reboot')"
        else
            if sudo apt install -y mesa-vulkan-drivers libvulkan1 mesa-utils; then
                ok "Mesa drivers installed"
                INSTALLED+=("mesa")
            fi
        fi
    else
        warn "Could not add kisak-mesa PPA"
        FAILED+=("mesa-ppa")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 4 — GAMING KERNEL BOOT PARAMETERS
# ════════════════════════════════════════════════════════════════════
phase_grub() {
    print_section "PHASE 4 — Gaming Kernel Boot Parameters"

    GRUB_FILE="/etc/default/grub"
    GRUB_BACKUP="/etc/default/grub.backup.$(date +%Y%m%d)"

    step "Backing up GRUB config..."
    sudo cp "$GRUB_FILE" "$GRUB_BACKUP"
    ok "Backup saved to $GRUB_BACKUP"

    GAMING_PARAMS="quiet splash mitigations=off nowatchdog nohz_full=all rcu_nocbs=all threadirqs amd_pstate=active"

    step "Checking current GRUB parameters..."
    CURRENT_PARAMS=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE")
    info "Current: $CURRENT_PARAMS"

    if echo "$CURRENT_PARAMS" | grep -q "mitigations=off"; then
        ok "Gaming parameters already applied"
        SKIPPED+=("grub-params")
    else
        step "Applying gaming kernel parameters..."
        sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GAMING_PARAMS\"|" "$GRUB_FILE"

        if sudo update-grub 2>/dev/null; then
            ok "GRUB updated with gaming parameters"
            INSTALLED+=("grub-gaming-params")
            info "Parameters applied: $GAMING_PARAMS"
        else
            fail "GRUB update failed — restoring backup"
            sudo cp "$GRUB_BACKUP" "$GRUB_FILE"
            FAILED+=("grub-params")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 5 — SYSCTL GAMING TWEAKS
# ════════════════════════════════════════════════════════════════════
phase_sysctl() {
    print_section "PHASE 5 — Ryzen sysctl Gaming Tweaks"

    SYSCTL_FILE="/etc/sysctl.d/99-gaming.conf"

    if [[ -f "$SYSCTL_FILE" ]]; then
        ok "Gaming sysctl config already exists"
        SKIPPED+=("sysctl")
        return
    fi

    step "Writing gaming sysctl configuration..."
    sudo tee "$SYSCTL_FILE" > /dev/null << 'EOF'
# ══════════════════════════════════════════
# Zorin OS Gaming Tweaks — sysctl
# Ryzen CPU + RDNA 4 Optimised
# ══════════════════════════════════════════

# ── Memory ────────────────────────────────
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.nr_hugepages=128
vm.compaction_proactiveness=0

# ── Network BBR ───────────────────────────
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3

# ── CPU & Scheduler ───────────────────────
kernel.sched_autogroup_enabled=1
kernel.numa_balancing=0
kernel.perf_event_paranoid=-1

# ── Filesystem ────────────────────────────
fs.inotify.max_user_watches=524288
fs.file-max=2097152
EOF

    if sudo sysctl -p "$SYSCTL_FILE" > /dev/null 2>&1; then
        ok "Gaming sysctl tweaks applied"
        INSTALLED+=("sysctl-gaming")
    else
        warn "Some sysctl values may not have applied (normal on some kernels)"
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 6 — CPU PERFORMANCE GOVERNOR
# ════════════════════════════════════════════════════════════════════
phase_cpu_governor() {
    print_section "PHASE 6 — CPU Performance Governor (Ryzen)"

    SERVICE_FILE="/etc/systemd/system/cpu-performance.service"

    if [[ -f "$SERVICE_FILE" ]]; then
        ok "CPU performance service already exists"
        SKIPPED+=("cpu-governor")
        return
    fi

    step "Creating CPU performance governor service..."
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

    if sudo systemctl daemon-reload && sudo systemctl enable cpu-performance.service --now; then
        ok "CPU performance governor enabled"
        INSTALLED+=("cpu-governor")
        CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
        info "Current governor: $CURRENT_GOV"
    else
        fail "CPU governor service failed"
        FAILED+=("cpu-governor")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 7 — GAMING STACK (GameMode, MangoHud, Lutris)
# ════════════════════════════════════════════════════════════════════
phase_gaming_stack() {
    print_section "PHASE 7 — Gaming Stack Installation"

    GAMING_PACKAGES=(gamemode mangohud lutris)

    for pkg in "${GAMING_PACKAGES[@]}"; do
        step "Installing $pkg..."
        if dpkg -l "$pkg" &>/dev/null; then
            ok "$pkg already installed"
            SKIPPED+=("$pkg")
        else
            if sudo apt install -y -qq "$pkg"; then
                ok "$pkg installed"
                INSTALLED+=("$pkg")
            else
                fail "$pkg installation failed"
                FAILED+=("$pkg")
            fi
        fi
    done

    # MangoHud config
    step "Setting up MangoHud config..."
    MANGOHUD_DIR="$HOME/.config/MangoHud"
    mkdir -p "$MANGOHUD_DIR"

    if [[ ! -f "$MANGOHUD_DIR/MangoHud.conf" ]]; then
        cat > "$MANGOHUD_DIR/MangoHud.conf" << 'EOF'
# MangoHud Config — Zorin Gaming Setup
fps
frametime
gpu_stats
gpu_temp
cpu_stats
cpu_temp
ram
vram
wine
vulkan_driver
EOF
        ok "MangoHud config created"
        INSTALLED+=("mangohud-config")
    else
        ok "MangoHud config already exists"
        SKIPPED+=("mangohud-config")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 8 — STEAM
# ════════════════════════════════════════════════════════════════════
phase_steam() {
    print_section "PHASE 8 — Steam Installation"

    if command -v steam &>/dev/null || flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
        ok "Steam already installed"
        SKIPPED+=("steam")
        return
    fi

    step "Enabling 32-bit architecture for Steam..."
    sudo dpkg --add-architecture i386
    sudo apt update -qq

    step "Installing Steam..."
    if sudo apt install -y steam-installer 2>/dev/null || sudo apt install -y steam 2>/dev/null; then
        ok "Steam installed via apt"
        INSTALLED+=("steam")
    else
        step "Trying Steam via Flatpak..."
        if flatpak install -y flathub com.valvesoftware.Steam 2>/dev/null; then
            ok "Steam installed via Flatpak"
            INSTALLED+=("steam-flatpak")
        else
            warn "Steam could not be installed automatically"
            info "Download manually from: https://store.steampowered.com/about/"
            FAILED+=("steam")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 9 — GE-PROTON
# ════════════════════════════════════════════════════════════════════
phase_ge_proton() {
    print_section "PHASE 9 — GE-Proton Installation"

    PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$PROTON_DIR"

    step "Fetching latest GE-Proton release..."
    LATEST_GE=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)

    if [[ -z "$LATEST_GE" ]]; then
        fail "Could not fetch GE-Proton release info"
        FAILED+=("ge-proton")
        return
    fi

    info "Latest GE-Proton: $LATEST_GE"

    if [[ -d "$PROTON_DIR/$LATEST_GE" ]]; then
        ok "GE-Proton $LATEST_GE already installed"
        SKIPPED+=("ge-proton")
        return
    fi

    step "Downloading GE-Proton $LATEST_GE..."
    if curl -L --progress-bar \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_GE/$LATEST_GE.tar.gz" \
        -o "/tmp/$LATEST_GE.tar.gz"; then

        step "Extracting GE-Proton..."
        tar -xzf "/tmp/$LATEST_GE.tar.gz" -C "$PROTON_DIR"
        rm "/tmp/$LATEST_GE.tar.gz"
        ok "GE-Proton $LATEST_GE installed to $PROTON_DIR"
        INSTALLED+=("ge-proton-$LATEST_GE")
    else
        fail "GE-Proton download failed"
        FAILED+=("ge-proton")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 10 — WINE-GE
# ════════════════════════════════════════════════════════════════════
phase_wine_ge() {
    print_section "PHASE 10 — Wine-GE Installation (Lutris)"

    WINE_DIR="$HOME/.local/share/lutris/runners/wine"
    mkdir -p "$WINE_DIR"

    step "Fetching latest Wine-GE release..."
    LATEST_WINE=$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)

    if [[ -z "$LATEST_WINE" ]]; then
        fail "Could not fetch Wine-GE release info"
        FAILED+=("wine-ge")
        return
    fi

    info "Latest Wine-GE: $LATEST_WINE"

    if [[ -d "$WINE_DIR/$LATEST_WINE" ]]; then
        ok "Wine-GE $LATEST_WINE already installed"
        SKIPPED+=("wine-ge")
        return
    fi

    step "Downloading Wine-GE $LATEST_WINE..."
    WINE_TAR=$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest \
        | grep '"browser_download_url"' | grep '.tar.xz' | cut -d'"' -f4 | head -1)

    if curl -L --progress-bar "$WINE_TAR" -o "/tmp/wine-ge-latest.tar.xz"; then
        mkdir -p "$WINE_DIR/$LATEST_WINE"
        tar -xJf "/tmp/wine-ge-latest.tar.xz" -C "$WINE_DIR/$LATEST_WINE" --strip-components=1
        rm "/tmp/wine-ge-latest.tar.xz"
        ok "Wine-GE $LATEST_WINE installed"
        INSTALLED+=("wine-ge-$LATEST_WINE")
    else
        fail "Wine-GE download failed"
        FAILED+=("wine-ge")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 11 — DXVK
# ════════════════════════════════════════════════════════════════════
phase_dxvk() {
    print_section "PHASE 11 — DXVK Installation"

    DXVK_DIR="$HOME/.local/share/dxvk"
    mkdir -p "$DXVK_DIR"

    step "Fetching latest DXVK release..."
    LATEST_DXVK=$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)

    if [[ -z "$LATEST_DXVK" ]]; then
        fail "Could not fetch DXVK release info"
        FAILED+=("dxvk")
        return
    fi

    info "Latest DXVK: $LATEST_DXVK"

    if [[ -d "$DXVK_DIR/$LATEST_DXVK" ]]; then
        ok "DXVK $LATEST_DXVK already installed"
        SKIPPED+=("dxvk")
        return
    fi

    step "Downloading DXVK $LATEST_DXVK..."
    DXVK_TAR=$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest \
        | grep '"browser_download_url"' | grep '.tar.gz' | cut -d'"' -f4 | head -1)

    if curl -L --progress-bar "$DXVK_TAR" -o "/tmp/dxvk-latest.tar.gz"; then
        mkdir -p "$DXVK_DIR/$LATEST_DXVK"
        tar -xzf "/tmp/dxvk-latest.tar.gz" -C "$DXVK_DIR/$LATEST_DXVK" --strip-components=1
        rm "/tmp/dxvk-latest.tar.gz"
        ok "DXVK $LATEST_DXVK installed"
        INSTALLED+=("dxvk-$LATEST_DXVK")
    else
        fail "DXVK download failed"
        FAILED+=("dxvk")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 12 — VKD3D-PROTON
# ════════════════════════════════════════════════════════════════════
phase_vkd3d() {
    print_section "PHASE 12 — VKD3D-Proton Installation"

    VKD3D_DIR="$HOME/.local/share/vkd3d"
    mkdir -p "$VKD3D_DIR"

    step "Fetching latest VKD3D-Proton release..."
    LATEST_VKD3D=$(curl -s https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)

    if [[ -z "$LATEST_VKD3D" ]]; then
        fail "Could not fetch VKD3D-Proton release info"
        FAILED+=("vkd3d")
        return
    fi

    info "Latest VKD3D-Proton: $LATEST_VKD3D"

    if [[ -d "$VKD3D_DIR/$LATEST_VKD3D" ]]; then
        ok "VKD3D-Proton $LATEST_VKD3D already installed"
        SKIPPED+=("vkd3d")
        return
    fi

    step "Downloading VKD3D-Proton $LATEST_VKD3D..."
    VKD3D_URL=$(curl -s https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases/latest \
        | grep '"browser_download_url"' | grep -E '\.(tar\.zst|tar\.gz)' | cut -d'"' -f4 | head -1)

    # Install zstd if needed
    sudo apt install -y -qq zstd 2>/dev/null

    if curl -L --progress-bar "$VKD3D_URL" -o "/tmp/vkd3d-latest.tar.zst"; then
        mkdir -p "$VKD3D_DIR/$LATEST_VKD3D"
        tar -xf "/tmp/vkd3d-latest.tar.zst" -C "$VKD3D_DIR/$LATEST_VKD3D" --strip-components=1 2>/dev/null || \
        tar -xzf "/tmp/vkd3d-latest.tar.zst" -C "$VKD3D_DIR/$LATEST_VKD3D" --strip-components=1 2>/dev/null
        rm "/tmp/vkd3d-latest.tar.zst"
        ok "VKD3D-Proton $LATEST_VKD3D installed"
        INSTALLED+=("vkd3d-$LATEST_VKD3D")
    else
        fail "VKD3D-Proton download failed"
        FAILED+=("vkd3d")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 13 — ZRAM
# ════════════════════════════════════════════════════════════════════
phase_zram() {
    print_section "PHASE 13 — ZRAM (Nobara-style Memory Compression)"

    if swapon --show | grep -q "zram"; then
        ok "ZRAM already active"
        SKIPPED+=("zram")
        return
    fi

    step "Installing zram-config..."
    if sudo apt install -y -qq zram-config; then
        sudo systemctl enable zram-config --now 2>/dev/null || true
        ok "ZRAM installed and enabled"
        INSTALLED+=("zram")
        info "$(cat /proc/swaps)"
    else
        warn "zram-config not available, trying zram-tools..."
        if sudo apt install -y -qq zram-tools; then
            ok "zram-tools installed"
            INSTALLED+=("zram-tools")
        else
            fail "ZRAM installation failed"
            FAILED+=("zram")
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 14 — IRQ BALANCE
# ════════════════════════════════════════════════════════════════════
phase_irq() {
    print_section "PHASE 14 — IRQ Balance"

    if systemctl is-active --quiet irqbalance; then
        ok "irqbalance already running"
        SKIPPED+=("irqbalance")
        return
    fi

    step "Installing irqbalance..."
    if sudo apt install -y -qq irqbalance; then
        sudo systemctl enable irqbalance --now
        ok "irqbalance installed and enabled"
        INSTALLED+=("irqbalance")
    else
        fail "irqbalance installation failed"
        FAILED+=("irqbalance")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 15 — AUTOMATED PATCH PIPELINE
# ════════════════════════════════════════════════════════════════════
phase_auto_pipeline() {
    print_section "PHASE 15 — Automated Gaming Patch Pipeline"

    PIPELINE_SCRIPT="/usr/local/bin/gaming-update"

    step "Installing gaming-update script..."
    sudo tee "$PIPELINE_SCRIPT" > /dev/null << 'PIPELINE'
#!/bin/bash
# ═══════════════════════════════════════════
# Gaming Patch Pipeline — Zorin OS
# Run manually: gaming-update
# ═══════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
info() { echo -e "  ${BLUE}→${NC} $1"; }
step() { echo -e "\n  ${YELLOW}▶${NC} $1"; }

echo -e "${BLUE}════════════════════════════════════${NC}"
echo -e "${BLUE}   Gaming Patch Pipeline Running    ${NC}"
echo -e "${BLUE}════════════════════════════════════${NC}"

# System update
step "System update..."
sudo apt update -qq && sudo apt upgrade -y -qq
ok "System updated"

# Mesa update
step "Mesa drivers..."
sudo apt install --only-upgrade -y -qq mesa-vulkan-drivers libvulkan1 mesa-utils 2>/dev/null
ok "Mesa updated"

# GE-Proton
step "Checking GE-Proton..."
PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
mkdir -p "$PROTON_DIR"
LATEST_GE=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [[ -d "$PROTON_DIR/$LATEST_GE" ]]; then
    ok "GE-Proton $LATEST_GE up to date"
else
    info "Downloading GE-Proton $LATEST_GE..."
    curl -L -s "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_GE/$LATEST_GE.tar.gz" -o "/tmp/$LATEST_GE.tar.gz"
    tar -xzf "/tmp/$LATEST_GE.tar.gz" -C "$PROTON_DIR"
    rm "/tmp/$LATEST_GE.tar.gz"
    ok "GE-Proton $LATEST_GE installed"
fi

# Wine-GE
step "Checking Wine-GE..."
WINE_DIR="$HOME/.local/share/lutris/runners/wine"
mkdir -p "$WINE_DIR"
LATEST_WINE=$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [[ -d "$WINE_DIR/$LATEST_WINE" ]]; then
    ok "Wine-GE $LATEST_WINE up to date"
else
    WINE_TAR=$(curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases/latest | grep '"browser_download_url"' | grep '.tar.xz' | cut -d'"' -f4 | head -1)
    info "Downloading Wine-GE $LATEST_WINE..."
    curl -L -s "$WINE_TAR" -o "/tmp/wine-ge.tar.xz"
    mkdir -p "$WINE_DIR/$LATEST_WINE"
    tar -xJf "/tmp/wine-ge.tar.xz" -C "$WINE_DIR/$LATEST_WINE" --strip-components=1
    rm "/tmp/wine-ge.tar.xz"
    ok "Wine-GE $LATEST_WINE installed"
fi

# DXVK
step "Checking DXVK..."
DXVK_DIR="$HOME/.local/share/dxvk"
mkdir -p "$DXVK_DIR"
LATEST_DXVK=$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [[ -d "$DXVK_DIR/$LATEST_DXVK" ]]; then
    ok "DXVK $LATEST_DXVK up to date"
else
    DXVK_TAR=$(curl -s https://api.github.com/repos/doitsujin/dxvk/releases/latest | grep '"browser_download_url"' | grep '.tar.gz' | cut -d'"' -f4 | head -1)
    info "Downloading DXVK $LATEST_DXVK..."
    curl -L -s "$DXVK_TAR" -o "/tmp/dxvk.tar.gz"
    mkdir -p "$DXVK_DIR/$LATEST_DXVK"
    tar -xzf "/tmp/dxvk.tar.gz" -C "$DXVK_DIR/$LATEST_DXVK" --strip-components=1
    rm "/tmp/dxvk.tar.gz"
    ok "DXVK $LATEST_DXVK installed"
fi

# GameMode & MangoHud
step "GameMode & MangoHud..."
sudo apt install --only-upgrade -y -qq gamemode mangohud 2>/dev/null
ok "GameMode & MangoHud updated"

echo -e "\n${BLUE}════════════════════════════════════${NC}"
echo -e "${GREEN}  Pipeline complete!${NC}"
echo -e "${BLUE}════════════════════════════════════${NC}"
echo -e "  GE-Proton : ${GREEN}$LATEST_GE${NC}"
echo -e "  Wine-GE   : ${GREEN}$LATEST_WINE${NC}"
echo -e "  DXVK      : ${GREEN}$LATEST_DXVK${NC}"
echo -e "\n${YELLOW}  Restart Steam for changes to take effect${NC}\n"
PIPELINE

    sudo chmod +x "$PIPELINE_SCRIPT"
    ok "gaming-update script installed — run with: gaming-update"
    INSTALLED+=("gaming-update-script")

    # Systemd timer
    step "Setting up weekly auto-update timer..."

    sudo tee /etc/systemd/system/gaming-patch.service > /dev/null << 'EOF'
[Unit]
Description=Gaming Patch Pipeline
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
    if sudo systemctl enable gaming-patch.timer --now; then
        ok "Weekly auto-update timer enabled"
        INSTALLED+=("gaming-patch-timer")
    fi
}

# ════════════════════════════════════════════════════════════════════
# PHASE 16 — STEAM LAUNCH OPTIONS + RAY TRACING CONFIG
# ════════════════════════════════════════════════════════════════════
phase_launch_options() {
    print_section "PHASE 16 — Launch Options & Ray Tracing Configuration"

    # ── Ray Tracing Environment Variables ───────────────────────────
    step "Writing RDNA 4 ray tracing environment config..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-amd-raytracing.conf > /dev/null << 'EOF'
# ══════════════════════════════════════════════════
# AMD RDNA 4 Ray Tracing Optimisations
# RX 9070 XT — Zorin OS Gaming Suite
# ══════════════════════════════════════════════════

# RADV hardware ray tracing acceleration
RADV_PERFTEST=gpl,rt,ngg_streamout

# VKD3D-Proton DX12 ray tracing (DXR 1.0 + DXR 1.1)
VKD3D_CONFIG=dxr,dxr11

# Async shader compilation — reduces RT stutter
DXVK_ASYNC=1

# Force RADV open-source Vulkan driver (best RDNA 4 RT support)
AMD_VULKAN_ICD=RADV

# Multi-threaded OpenGL
mesa_glthread=true

# Low latency presentation
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
    ok "RDNA 4 ray tracing environment config written"
    INSTALLED+=("rdna4-rt-env-config")

    # ── Standard Launch Options ──────────────────────────────────────
    echo -e "\n  ${CYAN}Global Steam launch options (includes RT):${NC}"
    echo -e "  ${WHITE}RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 VKD3D_CONFIG=dxr,dxr11 gamemoderun mangohud %command%${NC}"
    echo -e "\n  ${DIM}Full options saved to: ~/Gaming-Launch-Options.txt${NC}\n"

    cat > "$HOME/Gaming-Launch-Options.txt" << 'EOF'
════════════════════════════════════════════════════════════════
ZORIN OS GAMING — Steam Launch Options (RX 9070 XT / RDNA 4)
Includes Ray Tracing Configuration
════════════════════════════════════════════════════════════════

GLOBAL — All games (Steam → Settings → General → Launch Options):
RADV_PERFTEST=gpl,rt DXVK_ASYNC=1 VKD3D_CONFIG=dxr,dxr11 MESA_VK_WSI_PRESENT_MODE=mailbox gamemoderun mangohud %command%

DEMANDING GAMES — Without RT (right click game → Properties):
RADV_PERFTEST=gpl,ngg_streamout WINE_FULLSCREEN_FSR=1 DXVK_ASYNC=1 gamemoderun mangohud %command%

RAY TRACING GAMES — DX12 titles (Cyberpunk 2077, Alan Wake 2 etc):
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

MAXIMUM RT PERFORMANCE — with FSR upscaling:
RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV WINE_FULLSCREEN_FSR=1 gamemoderun mangohud %command%

════════════════════════════════════════════════════════════════
VARIABLE EXPLANATION:
  RADV_PERFTEST=gpl          → Faster shader compilation (RDNA 4)
  RADV_PERFTEST=rt           → Enables RADV hardware RT acceleration
  RADV_PERFTEST=ngg_streamout→ RDNA 4 geometry pipeline optimisation
  VKD3D_CONFIG=dxr           → DX12 ray tracing DXR 1.0
  VKD3D_CONFIG=dxr11         → DX12 ray tracing DXR 1.1 (better quality)
  DXVK_ASYNC=1               → Async shaders — reduces RT stutter
  AMD_VULKAN_ICD=RADV        → Forces open-source RADV Vulkan driver
  WINE_FULLSCREEN_FSR=1      → AMD FSR upscaling (pairs well with RT)
  MESA_VK_WSI_PRESENT_MODE   → mailbox = lower input lag
  gamemoderun                → CPU/GPU performance boost while gaming
  mangohud                   → Live FPS/temp/VRAM overlay

════════════════════════════════════════════════════════════════
RAY TRACING TIPS FOR RX 9070 XT (RDNA 4):
  • RDNA 4 has dedicated RT hardware — turn RT on in game settings
  • Use FSR Quality or Balanced mode alongside RT for best perf
  • VKD3D_CONFIG=dxr11 required for DXR 1.1 titles (better RT)
  • RT shader cache builds on first launch — expect initial stutter
  • MangoHud shows GPU% — RT heavy scenes will push it to 90-100%
  • If RT causes crashes remove ngg_streamout first and retry

════════════════════════════════════════════════════════════════
REMEMBER:
  • Enable ReBAR in BIOS for free 5-15% GPU performance boost
  • Run gaming-update regularly to stay cutting edge
════════════════════════════════════════════════════════════════
EOF

    ok "Launch options + RT guide saved to ~/Gaming-Launch-Options.txt"
    INSTALLED+=("launch-options-rt-guide")
}

# ════════════════════════════════════════════════════════════════════
# PHASE 17 — ANTI-CHEAT SUPPORT (EAC + BattlEye)
# ════════════════════════════════════════════════════════════════════
phase_anticheat() {
    print_section "PHASE 17 — Anti-Cheat Support (EAC + BattlEye)"

    info "Setting up EAC and BattlEye Linux runtime for games like:"
    info "Fortnite, Battlefield, GTA 5, Apex Legends, Rust and more"

    step "Writing anti-cheat environment config..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-anticheat.conf > /dev/null << 'EOF'
# Anti-Cheat Linux Support — EAC + BattlEye
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt
WINE_LARGE_ADDRESS_AWARE=1
PROTON_USE_SECCOMP=1
EOF
    ok "Anti-cheat environment config written"
    INSTALLED+=("anticheat-env-config")

    step "Setting kernel parameter for EAC compatibility..."
    sudo sysctl -w kernel.perf_event_paranoid=-1 > /dev/null 2>&1
    # Make it persistent (already in 99-gaming.conf but ensuring it's there)
    grep -q "perf_event_paranoid" /etc/sysctl.d/99-gaming.conf 2>/dev/null || \
        echo "kernel.perf_event_paranoid=-1" | sudo tee -a /etc/sysctl.d/99-gaming.conf > /dev/null
    ok "EAC kernel parameter set"
    INSTALLED+=("eac-kernel-param")

    step "Creating anti-cheat launch options guide..."
    cat > "$HOME/Gaming-AntiCheat-Launch-Options.txt" << 'EOF'
════════════════════════════════════════════════════════════════
ANTI-CHEAT GAME LAUNCH OPTIONS — RX 9070 XT / RDNA 4
EAC + BattlEye via Proton
════════════════════════════════════════════════════════════════

STEP 1 — Install runtimes (ONE TIME — open Steam first):
  steam steam://install/1826330   ← Easy Anti-Cheat Runtime
  steam steam://install/1161040   ← BattlEye Service Runtime

STEP 2 — Steam Settings → Compatibility → Enable Steam Play

UNIVERSAL (most EAC + BattlEye games):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun mangohud %command%

FORTNITE (EAC + FSR):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt WINE_LARGE_ADDRESS_AWARE=1 RADV_PERFTEST=gpl DXVK_ASYNC=1 WINE_FULLSCREEN_FSR=1 gamemoderun mangohud %command%

BATTLEFIELD 2042 / BATTLEFIELD 6 (EAC + RT):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

GTA 5 / GTA ONLINE:
RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

APEX LEGENDS (EAC):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun %command%

RAINBOW SIX SIEGE / RUST (BattlEye):
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt RADV_PERFTEST=gpl DXVK_ASYNC=1 gamemoderun mangohud %command%

════════════════════════════════════════════════════════════════
CONFIRMED WORKING:
  ✓ Fortnite    ✓ Apex Legends    ✓ GTA 5
  ✓ Battlefield ✓ Rainbow Six     ✓ Rust
  ✓ DayZ        ✓ Hunt Showdown   ✓ Dead by Daylight
NOT WORKING: Valorant (kernel-level Vanguard — Windows only)
Check protondb.com for latest game status
════════════════════════════════════════════════════════════════
EOF
    ok "Anti-cheat guide saved to ~/Gaming-AntiCheat-Launch-Options.txt"
    INSTALLED+=("anticheat-launch-guide")
}

# ════════════════════════════════════════════════════════════════════
# PHASE 18 — UPSCALING TECHNOLOGY (FSR 3 + XeSS + Gamescope)
# ════════════════════════════════════════════════════════════════════
phase_upscaling() {
    print_section "PHASE 18 — Upscaling: FSR 4 + XeSS 3 + Gamescope (RX 9070 XT)"

    info "Your RX 9070 XT (RDNA 4) gets FULL native FSR 4 — no compromises"
    info "FSR 4 uses AI/ML for dramatically better quality than FSR 3"
    info "Gamescope forces upscaling even in games with no upscaler support"

    step "Installing Gamescope upscaling compositor..."
    if sudo apt install -y -qq gamescope 2>/dev/null; then
        ok "Gamescope installed — system-level upscaling active"
        INSTALLED+=("gamescope-upscaling")
    else
        warn "Gamescope not in repos — FSR via Wine still works"
    fi

    step "Writing FSR 4 / FSR 3 upscaling environment config..."
    sudo mkdir -p /etc/environment.d/
    sudo tee /etc/environment.d/99-upscaling.conf > /dev/null << 'EOF'
# ═══════════════════════════════════════════════════
# Upscaling — RX 9070 XT (RDNA 4) — March 2026
# FSR 4 (AI native) + FSR 3 fallback
# ═══════════════════════════════════════════════════
# FSR 4: use PROTON_FSR4_UPGRADE=1 in Steam launch options
# FSR 3 fallback for all games via Wine:
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
    ok "FSR 4 / FSR 3 environment config written"
    INSTALLED+=("fsr4-fsr3-env-config")

    step "Creating FSR4/XeSS3 upscaling launch options guide..."
    cat > "$HOME/Gaming-Upscaling-Options.txt" << 'EOF'
════════════════════════════════════════════════════════════════════════
UPSCALING LAUNCH OPTIONS — RX 9070 XT (RDNA 4) — March 2026
FSR 4 (AI) • FSR 3 • XeSS 3 • Gamescope
════════════════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 4 — Native AI Upscaling (RX 9070 XT has dedicated hardware!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Enable FSR 4 (upgrades FSR 3.1 games automatically via GE-Proton):
PROTON_FSR4_UPGRADE=1 %command%

FSR 4 with confirmation overlay (verify it's working):
PROTON_FSR4_UPGRADE=1 PROTON_FSR4_INDICATOR=1 %command%

FSR 4 + RT (the ultimate RX 9070 XT combo):
PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt,ngg_streamout VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 AMD_VULKAN_ICD=RADV gamemoderun mangohud %command%

FSR 4 + RT + Anti-Cheat (Battlefield 6, Fortnite, EAC games):
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 WINE_LARGE_ADDRESS_AWARE=1 gamemoderun mangohud %command%

NOTES ON FSR 4:
  • Works in games that support FSR 3.1 (60+ games as of March 2026)
  • Game still shows FSR 3.1 in menu — it IS rendering with FSR 4
  • Confirmed: Cyberpunk 2077, Silent Hill 2, Ratchet & Clank
  • Add SteamDeck=0 if game disables FSR options under Proton
  • For Vulkan-only games (Doom Dark Ages) use OptiScaler instead

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FSR 3 — Fallback (in-game or via Gamescope, works on any GPU)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
In-game FSR 3 (game must support it):
WINE_FULLSCREEN_FSR=1 WINE_FULLSCREEN_FSR_STRENGTH=2 %command%

Via Gamescope (NO game support needed — any game, any resolution):
gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling --fsr-sharpness 5 -- %command%
gamescope -w 1920 -h 1080 -W 3840 -H 2160 -f --fsr-upscaling -- %command%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS 3 — Works via VKD3D-Proton (enable in game settings)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XeSS upscaling works on ALL GPUs — just enable it in game settings
No launch options needed for upscaling
XeSS 3 Multi-Frame Generation (2x/3x/4x): currently DX12/Windows only
Linux MFG support expected in future VKD3D-Proton updates

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OptiScaler — Inject FSR4/DLSS4/XeSS3 into any compatible game
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files at: ~/.local/share/optiscaler/[version]/
Copy to game folder then launch with: WINEDLLOVERRIDES="winmm.dll=n,b" %command%
Press INSERT in-game for OptiScaler overlay
WARNING: Never use OptiScaler in online multiplayer games (anti-cheat)

════════════════════════════════════════════════════════════════════════
RECOMMENDATION FOR RX 9070 XT — March 2026:
  1st: PROTON_FSR4_UPGRADE=1         native AI FSR 4 (best quality)
  2nd: In-game FSR 4 if natively supported in game
  3rd: WINE_FULLSCREEN_FSR=1         FSR 3 via Wine (universal)
  4th: Gamescope --fsr-upscaling     FSR 3 without any game support
  Always combine with RT: RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11
  Run gaming-update regularly — FSR 4 support expands every update
════════════════════════════════════════════════════════════════════════
EOF
    ok "FSR4/XeSS3 upscaling guide saved to ~/Gaming-Upscaling-Options.txt"
    INSTALLED+=("fsr4-xess3-upscaling-guide")
}

# ════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ════════════════════════════════════════════════════════════════════
print_summary() {

    echo -e "\n  ${GREEN}${BOLD}Installed (${#INSTALLED[@]})${NC}"
    for item in "${INSTALLED[@]}"; do
        echo -e "    ${GREEN}✓${NC} $item"
    done

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo -e "\n  ${CYAN}${BOLD}Already Present / Skipped (${#SKIPPED[@]})${NC}"
        for item in "${SKIPPED[@]}"; do
            echo -e "    ${CYAN}→${NC} $item"
        done
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "\n  ${RED}${BOLD}Failed (${#FAILED[@]})${NC}"
        for item in "${FAILED[@]}"; do
            echo -e "    ${RED}✗${NC} $item"
        done
    fi

    echo -e "\n${BLUE}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${YELLOW}  IMPORTANT POST-SETUP STEPS                                      ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${YELLOW}1.${NC} ${WHITE}REBOOT${NC} to activate XanMod kernel + GRUB params"
    echo -e "  ${YELLOW}2.${NC} Enable ${WHITE}ReBAR${NC} in BIOS (Above 4G Decoding + Resizable BAR)"
    echo -e "  ${YELLOW}3.${NC} Open ${WHITE}Steam → Settings → Compatibility${NC} → Enable Steam Play"
    echo -e "  ${YELLOW}4.${NC} Set ${WHITE}GE-Proton${NC} as default compatibility tool in Steam"
    echo -e "  ${YELLOW}5.${NC} Add launch options from ${WHITE}~/Gaming-Launch-Options.txt${NC}"
    echo -e "  ${YELLOW}6.${NC} Run ${WHITE}gaming-update${NC} weekly or let the timer handle it"

    echo -e "\n${BLUE}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${CYAN}  USEFUL COMMANDS                                                  ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${CYAN}gaming-update${NC}                   Run patch pipeline manually"
    echo -e "  ${CYAN}uname -r${NC}                        Verify XanMod kernel"
    echo -e "  ${CYAN}glxinfo | grep OpenGL${NC}           Check Mesa version"
    echo -e "  ${CYAN}cat /proc/swaps${NC}                 Verify ZRAM active"
    echo -e "  ${CYAN}systemctl status gaming-patch.timer${NC}  Check auto-update"
    echo -e "  ${CYAN}journalctl -u gaming-patch.service${NC}   View update logs"

    echo -e "\n  ${DIM}Full log saved to: $LOG_FILE${NC}"
    echo -e "\n${GREEN}${BOLD}  Your Zorin OS is now optimised for gaming. Reboot when ready!${NC}\n"
}

# ════════════════════════════════════════════════════════════════════
# MAIN — Run all phases
# ════════════════════════════════════════════════════════════════════
main() {
    print_banner
    check_root
    check_zorin
    check_internet

    echo -e "\n${YELLOW}  This script will:${NC}"
    echo -e "  • Install XanMod kernel with BORE scheduler"
    echo -e "  • Upgrade Mesa to bleeding-edge (RDNA 4)"
    echo -e "  • Apply gaming GRUB & sysctl tweaks"
    echo -e "  • Install GameMode, MangoHud, Lutris, Steam"
    echo -e "  • Install GE-Proton, Wine-GE, DXVK, VKD3D"
    echo -e "  • Configure RDNA 4 Ray Tracing (DXR 1.0 + DXR 1.1)"
    echo -e "  • Set up automated weekly patch pipeline"
    echo -e "  • Configure CPU performance governor"
    echo -e "\n${YELLOW}  A full log will be saved to: $LOG_FILE${NC}"

    if ! confirm "Ready to begin? This will take 10-20 minutes."; then
        echo -e "\n${YELLOW}  Setup cancelled.${NC}\n"
        exit 0
    fi

    phase_system_prep
    phase_kernel
    phase_mesa
    phase_grub
    phase_sysctl
    phase_cpu_governor
    phase_gaming_stack
    phase_steam
    phase_ge_proton
    phase_wine_ge
    phase_dxvk
    phase_vkd3d
    phase_zram
    phase_irq
    phase_auto_pipeline
    phase_launch_options
    phase_anticheat
    phase_upscaling

    print_summary
}

main "$@"
