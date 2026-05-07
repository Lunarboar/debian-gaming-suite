#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

install_nvidia_drivers() {
    local DISTRO_BASE="$1"
    
    print_section "NVIDIA Proprietary Drivers"

    if [[ "$DISTRO_BASE" == "ubuntu" ]]; then
        if ! grep -ri "graphics-drivers" /etc/apt/sources.list.d/ &>/dev/null; then
            step "Adding NVIDIA graphics PPA..."
            sudo add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null
            sudo apt update -qq 2>/dev/null
            ok "NVIDIA PPA added"
        fi
    fi

    step "Detecting recommended NVIDIA driver..."
    local RECOMMENDED=""
    if command -v ubuntu-drivers &>/dev/null; then
        RECOMMENDED=$(ubuntu-drivers devices 2>/dev/null | grep "recommended" | awk '{print $3}')
    fi
    [[ -z "$RECOMMENDED" ]] && RECOMMENDED="nvidia-driver-570"
    info "Installing: $RECOMMENDED"

    if sudo apt install -y "$RECOMMENDED" nvidia-settings 2>/dev/null; then
        ok "NVIDIA driver installed: $RECOMMENDED"
    else
        fail "NVIDIA driver install failed"
        return 1
    fi

    step "Installing NVIDIA Vulkan support..."
    sudo apt install -y -qq libvulkan1 vulkan-tools nvidia-vulkan-icd 2>/dev/null
    ok "NVIDIA Vulkan configured"

    step "Enabling nvidia-persistenced..."
    sudo systemctl enable nvidia-persistenced --now 2>/dev/null && \
        ok "nvidia-persistenced enabled" || \
        warn "nvidia-persistenced unavailable — enable after reboot"

    step "Setting NVIDIA performance environment variables..."
    local ENV_FILE="/etc/environment.d/99-nvidia-gaming.conf"
    backup_file "$ENV_FILE"
    sudo mkdir -p /etc/environment.d/
    sudo tee "$ENV_FILE" > /dev/null << 'EOF'
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SIZE=10737418240
__GL_THREADED_OPTIMIZATIONS=1
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
EOF
    ok "NVIDIA environment variables set in $ENV_FILE"
}
