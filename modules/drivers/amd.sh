#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

install_amd_drivers() {
    local DISTRO_BASE="$1"
    print_section "AMD GPU Drivers"

    step "Installing Mesa & Vulkan drivers..."
    local PKGS=(
        mesa-vulkan-drivers libvulkan1 vulkan-tools 
        mesa-utils libgl1-mesa-dri xserver-xorg-video-amdgpu
        mesa-va-drivers mesa-vdpau-drivers linux-firmware
    )
    
    sudo apt install -y "${PKGS[@]}" || {
        fail "Failed to install AMD drivers. Please check your internet connection and APT sources."
        return 1
    }

    step "Configuring AMDGPU performance..."
    local MODPROBE_FILE="/etc/modprobe.d/amdgpu-gaming.conf"
    if [[ ! -f "$MODPROBE_FILE" ]]; then
        sudo tee "$MODPROBE_FILE" > /dev/null << 'EOF'
options amdgpu ppfeaturemask=0xffffffff
options amdgpu runpm=0
EOF
        [[ $? -ne 0 ]] && warn "Could not write $MODPROBE_FILE"
    fi

    ok "AMD drivers and performance tweaks applied"
}
