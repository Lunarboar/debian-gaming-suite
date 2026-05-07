#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

install_nvidia_drivers() {
    local DISTRO_BASE="$1"
    print_section "NVIDIA GPU Drivers"

    step "Installing proprietary NVIDIA drivers..."
    local PKGS=(
        nvidia-driver nvidia-settings nvidia-vulkan-icd 
        libvulkan1 vulkan-tools nvidia-kernel-dkms
    )

    sudo apt install -y "${PKGS[@]}" || {
        fail "Failed to install NVIDIA drivers. Ensure 'non-free' repos are enabled."
        return 1
    }

    step "Enabling NVIDIA Persistence Service..."
    sudo systemctl enable nvidia-persistenced --now || warn "Could not enable nvidia-persistenced"

    step "Configuring NVIDIA DRM (Modesetting)..."
    local MODPROBE_FILE="/etc/modprobe.d/nvidia-gaming.conf"
    if [[ ! -f "$MODPROBE_FILE" ]]; then
        sudo tee "$MODPROBE_FILE" > /dev/null << 'EOF'
options nvidia-drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x1; PowerMizerLevelAC=0x1"
EOF
        [[ $? -ne 0 ]] && warn "Could not write $MODPROBE_FILE"
    fi

    step "Setting up environment variables for NVIDIA..."
    local ENV_FILE="/etc/environment.d/99-nvidia-gaming.conf"
    sudo mkdir -p /etc/environment.d/
    sudo tee "$ENV_FILE" > /dev/null << 'EOF'
__GL_GSYNC_ALLOWED=1
__GL_VRR_ALLOWED=1
__GL_THREADED_OPTIMIZATIONS=1
EOF
    [[ $? -ne 0 ]] && warn "Could not write $ENV_FILE"

    ok "NVIDIA drivers and environment configured"
}
