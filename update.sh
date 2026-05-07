#!/bin/bash

# ════════════════════════════════════════════════════════════════════════════
# DEBIAN GAMING UPDATE — MODULAR EDITION (2.1.0)
# ════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
MODULES_DIR="$SCRIPT_DIR/modules"

source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/hardware.sh"

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║        DEBIAN GAMING UPDATE SUITE — V2.1.0 (Modular)             ║"
    echo "  ╚════════════════════════════════════════════════════════════════════╝${NC}"
}

run_update() {
    log_init
    check_root
    
    IFS='|' read -r DISTRO_BASE DISTRO_NAME CODENAME PKG_MGR <<< "$(detect_distro)"
    IFS='|' read -r GPU_VENDOR GPU_NAME <<< "$(detect_gpu)"

    print_section "System Update"
    step "Updating host packages..."
    sudo $PKG_MGR update -qq && sudo $PKG_MGR upgrade -y -qq && ok "Host system updated"

    # Update Distrobox Arch if it exists
    if command -v distrobox &>/dev/null && distrobox list | grep -q "gaming-arch"; then
        print_section "Distrobox Update (Arch Linux)"
        step "Updating gaming container..."
        distrobox enter gaming-arch -- sudo pacman -Syu --noconfirm
        ok "Gaming container updated"
    fi

    # Update Proton/DXVK/VKD3D
    source "$MODULES_DIR/gaming/proton.sh"
    install_ge_proton
    install_dxvk_vkd3d

    print_section "Update Summary"
    ok "All systems up to date!"
}

print_banner
run_update
