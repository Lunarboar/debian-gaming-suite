#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

install_amd_drivers() {
    local DISTRO_BASE="$1"
    
    print_section "AMD GPU Drivers (Mesa/RADV)"

    # Add kisak bleeding-edge Mesa PPA (Ubuntu-based only)
    if [[ "$DISTRO_BASE" == "ubuntu" ]]; then
        # This function should be in repos module but I can call it if I source it
        # Or just do it here for now to keep it self-contained
        if ! grep -ri "kisak-mesa" /etc/apt/sources.list.d/ &>/dev/null; then
            step "Adding kisak bleeding-edge Mesa PPA..."
            sudo add-apt-repository -y ppa:kisak/kisak-mesa 2>/dev/null && \
                sudo apt update -qq 2>/dev/null && ok "kisak-mesa PPA added" || \
                warn "Could not add kisak PPA — using distro Mesa"
        fi
    fi

    step "Installing AMD Mesa & Vulkan packages..."
    local PKGS=(
        mesa-vulkan-drivers libvulkan1 mesa-utils
        libgl1-mesa-dri libglx-mesa0 mesa-vdpau-drivers
        mesa-va-drivers libdrm-amdgpu1 libdrm-radeon1
        libdrm2 radeontop linux-firmware
    )

    sudo apt install -y -qq "${PKGS[@]}" 2>/dev/null && ok "AMD Mesa drivers installed" || fail "Failed to install some AMD packages"

    step "Updating AMDGPU firmware..."
    sudo apt install --only-upgrade -y -qq linux-firmware 2>/dev/null && \
        ok "AMDGPU firmware updated" || warn "Firmware update skipped"
}
