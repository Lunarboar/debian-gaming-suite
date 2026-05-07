#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

setup_upscaling() {
    local GPU_VENDOR="$1"
    
    print_section "Upscaling Technologies (FSR/DLSS/XeSS)"

    local ENV_FILE="/etc/environment.d/99-gaming-upscaling.conf"
    backup_file "$ENV_FILE"
    sudo mkdir -p /etc/environment.d/

    case "$GPU_VENDOR" in
        amd)
            sudo tee "$ENV_FILE" > /dev/null << 'EOF'
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "AMD FSR configured" ;;
        nvidia|hybrid*)
            sudo tee "$ENV_FILE" > /dev/null << 'EOF'
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1
WINE_FULLSCREEN_FSR=1
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "NVIDIA DLSS + FSR fallback configured" ;;
        intel_arc)
            sudo tee "$ENV_FILE" > /dev/null << 'EOF'
ANV_ENABLE_PIPELINE_CACHE=1
WINE_FULLSCREEN_FSR=1
mesa_glthread=true
MESA_VK_WSI_PRESENT_MODE=mailbox
EOF
            ok "Intel XeSS + FSR configured" ;;
    esac
}
