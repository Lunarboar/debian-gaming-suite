#!/bin/bash

# ════════════════════════════════════════════════════════════════════════════
# DEBIAN GAMING SETUP (Modular)
# ════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
MODULES_DIR="$SCRIPT_DIR/modules"

# Source Foundations
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/hardware.sh"
source "$UTILS_DIR/rollback.sh"

# Global State
ADVANCED_MODE=false
GAMING_MODE="container" # container or native

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║        DEBIAN GAMING OPTIMISATION SUITE (Modular)          ║"
    echo "  ║             Universal Support: AMD • NVIDIA • Intel              ║"
    echo -e "  ╚════════════════════════════════════════════════════════════════════╝${NC}"
}

main_menu() {
    print_banner
    
    # 1. Hardware Detection
    print_section "System Detection"
    
    IFS='|' read -r DISTRO_BASE DISTRO_NAME CODENAME PKG_MGR <<< "$(detect_distro)"
    IFS='|' read -r GPU_VENDOR GPU_NAME <<< "$(detect_gpu)"
    IFS='|' read -r CPU_VENDOR CPU_NAME <<< "$(detect_cpu)"
    TOTAL_RAM=$(get_total_ram_gb)

    echo -e "  ${CYAN}OS      :${NC} $DISTRO_NAME ($CODENAME)"
    echo -e "  ${CYAN}GPU     :${NC} $GPU_NAME ($GPU_VENDOR)"
    echo -e "  ${CYAN}CPU     :${NC} $CPU_NAME ($CPU_VENDOR)"
    echo -e "  ${CYAN}RAM     :${NC} ${TOTAL_RAM}GB"
    echo -e "  ${CYAN}Pkg Mgr :${NC} $PKG_MGR"

    # Check for PikaOS
    if [[ "$DISTRO_BASE" == "pikaos" ]]; then
        ok "PikaOS detected: System is already optimized. Exiting."
        exit 0
    fi

    # 2. Gaming Setup Choice
    echo -e "\n  ${WHITE}${BOLD}1. Select Gaming Environment:${NC}"
    echo -e "  1) ${GREEN}CONTAINERIZED${NC} (Distrobox + Arch Linux) - Recommended"
    echo -e "  2) ${YELLOW}NATIVE${NC}        (Debian APT)"
    
    read -p "  Choice [1]: " gaming_choice
    [[ "$gaming_choice" == "2" ]] && GAMING_MODE="native" || GAMING_MODE="container"

    # 3. Mode Selection (Performance)
    echo -e "\n  ${WHITE}${BOLD}2. Select Optimization Level:${NC}"
    echo -e "  1) ${GREEN}SAFE${NC}"
    echo -e "  2) ${RED}ADVANCED${NC} (Liquorix Kernel, No Mitigations)"
    
    read -p "  Choice [1]: " mode_choice
    [[ "$mode_choice" == "2" ]] && ADVANCED_MODE=true || ADVANCED_MODE=false

    # 4. Confirmation
    if ! confirm "Proceed with installation?"; then
        echo "Exiting..."
        exit 0
    fi
}

run_setup() {
    log_init
    check_root
    check_internet
    
    # Load Modules
    source "$MODULES_DIR/repos/debian.sh"
    source "$MODULES_DIR/drivers/amd.sh"
    source "$MODULES_DIR/drivers/nvidia.sh"
    source "$MODULES_DIR/drivers/intel.sh"
    source "$MODULES_DIR/system/kernel.sh"
    source "$MODULES_DIR/system/grub.sh"
    source "$MODULES_DIR/system/zram.sh"
    source "$MODULES_DIR/system/sysctl.sh"
    source "$MODULES_DIR/gaming/distrobox.sh"
    source "$MODULES_DIR/gaming/proton.sh"
    source "$MODULES_DIR/gaming/tools.sh"
    source "$MODULES_DIR/gaming/upscaling.sh"

    # Start Setup
    create_restore_script

    # ── Repos ────────────────────────────────────────────────────────
    setup_repos "$DISTRO_BASE" "$CODENAME" "$PKG_MGR"

    # ── Drivers (Host) ───────────────────────────────────────────────
    case "$GPU_VENDOR" in
        amd) install_amd_drivers "$DISTRO_BASE" ;;
        nvidia*) install_nvidia_drivers "$DISTRO_BASE" ;;
        intel_arc) install_intel_arc_drivers "$DISTRO_BASE" "$CODENAME" ;;
        intel_igp) install_intel_igp_drivers ;;
        hybrid*) install_intel_igp_drivers; install_nvidia_drivers "$DISTRO_BASE" ;;
    esac

    # ── System Tweaks ────────────────────────────────────────────────
    setup_zram "$TOTAL_RAM"
    apply_sysctl_tweaks "$CPU_VENDOR" "$GPU_VENDOR"
    
    if [[ "$ADVANCED_MODE" == "true" ]]; then
        install_liquorix_kernel
        apply_grub_tweaks "$CPU_VENDOR" "$GPU_VENDOR" "true"
    else
        apply_grub_tweaks "$CPU_VENDOR" "$GPU_VENDOR" "false"
    fi

    # ── Gaming Stack ─────────────────────────────────────────────────
    # Install GameMode on host anyway (needed for hardware access)
    sudo $PKG_MGR install -y gamemode
    setup_gamemode_config

    if [[ "$GAMING_MODE" == "container" ]]; then
        setup_distrobox_gaming
    else
        install_native_gaming_stack
    fi
    
    # Host-side helpers
    install_dxvk_vkd3d
    setup_upscaling "$GPU_VENDOR"

    print_section "Installation Summary"
    ok "Setup complete!"
    info "Gaming Environment: ${BOLD}$GAMING_MODE${NC}"
    info "Rollback script: $BACKUP_DIR/restore.sh"
    warn "Please REBOOT to apply all changes (Kernel, Group, Drivers)."
}

# Run
main_menu
run_setup
