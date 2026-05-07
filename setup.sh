#!/bin/bash

# ════════════════════════════════════════════════════════════════════════════
# DEBIAN GAMING SETUP — MODULAR EDITION (2.1.0)
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

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║        DEBIAN GAMING OPTIMISATION SUITE — V2.1.0 (Modular)       ║"
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
        ok "PikaOS detected: System is already optimized for gaming. Exiting."
        exit 0
    fi

    # 2. Mode Selection
    echo -e "\n  ${WHITE}${BOLD}Select Setup Mode:${NC}"
    echo -e "  ${GREEN}1)${NC} ${BOLD}SAFE${NC}     - Drivers, Distrobox Arch (Gaming), basic tweaks"
    echo -e "  ${RED}2)${NC} ${BOLD}ADVANCED${NC} - High-perf tweaks: Liquorix Kernel, GRUB, No Mitigations"
    echo -e "  ${DIM}q) Quit${NC}"
    
    read -p "  Choice [1]: " mode_choice
    case "$mode_choice" in
        2) ADVANCED_MODE=true; ok "Advanced mode selected" ;;
        q) exit 0 ;;
        *) ADVANCED_MODE=false; ok "Safe mode selected" ;;
    esac

    # 3. Confirmation
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
    source "$MODULES_DIR/gaming/upscaling.sh"
    source "$MODULES_DIR/gaming/anticheat.sh"

    # Start Setup
    create_restore_script

    # Repos
    setup_repos "$DISTRO_BASE" "$CODENAME" "$PKG_MGR"

    # Drivers (Host side for Vulkan/Mesa basics)
    case "$GPU_VENDOR" in
        amd) install_amd_drivers "$DISTRO_BASE" ;;
        nvidia*) install_nvidia_drivers "$DISTRO_BASE" ;;
        intel_arc) install_intel_arc_drivers "$DISTRO_BASE" "$CODENAME" ;;
        intel_igp) install_intel_igp_drivers ;;
        hybrid*) 
            install_intel_igp_drivers
            install_nvidia_drivers "$DISTRO_BASE"
            ;;
    esac

    # System Tweaks
    setup_zram "$TOTAL_RAM"
    apply_sysctl_tweaks "$CPU_VENDOR" "$GPU_VENDOR"
    
    if [[ "$ADVANCED_MODE" == "true" ]]; then
        install_liquorix_kernel
        apply_grub_tweaks "$CPU_VENDOR" "$GPU_VENDOR" "true"
    else
        apply_grub_tweaks "$CPU_VENDOR" "$GPU_VENDOR" "false"
    fi

    # Gaming Stack via Distrobox (Arch Linux)
    setup_distrobox_gaming
    
    # These might still be useful on host for some native apps
    install_dxvk_vkd3d
    setup_upscaling "$GPU_VENDOR"
    setup_anticheat

    print_section "Installation Summary"
    ok "Setup complete!"
    info "A rollback script has been created at: $BACKUP_DIR/restore.sh"
    warn "Please REBOOT your system to apply all changes."
}

# Run
main_menu
run_setup
