#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

install_intel_arc_drivers() {
    local DISTRO_BASE="$1"
    local CODENAME="$2"

    print_section "Intel Arc GPU Drivers"

    if [[ "$DISTRO_BASE" == "ubuntu" ]]; then
        if [[ ! -f /etc/apt/sources.list.d/intel-graphics.list ]]; then
            step "Adding Intel graphics repository..."
            wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
                sudo gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg 2>/dev/null || {
                    fail "Failed to download Intel key"
                    return 1
                }

            echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
https://repositories.intel.com/gpu/ubuntu ${CODENAME} client" | \
                sudo tee /etc/apt/sources.list.d/intel-graphics.list > /dev/null

            sudo apt update -qq || warn "Intel repo added but apt update failed"
        fi
    fi

    step "Installing Intel Arc Mesa & Vulkan drivers..."
    local PKGS=(
        intel-media-va-driver-non-free intel-opencl-icd
        mesa-vulkan-drivers libvulkan1 mesa-utils
        libgl1-mesa-dri libdrm2 vainfo linux-firmware
    )
    sudo apt install -y "${PKGS[@]}" || {
        fail "Failed to install Intel Arc drivers"
        return 1
    }

    step "Enabling Intel GuC/HuC firmware..."
    local MODPROBE="/etc/modprobe.d/intel-arc-gaming.conf"
    if [[ ! -f "$MODPROBE" ]]; then
        sudo tee "$MODPROBE" > /dev/null << 'EOF'
options i915 enable_guc=3
options i915 enable_fbc=1
EOF
        if [[ $? -eq 0 ]]; then
            sudo update-initramfs -u || warn "Initramfs update failed"
        else
            warn "Could not write $MODPROBE"
        fi
    fi
    ok "Intel Arc drivers installed"
}

install_intel_igp_drivers() {
    print_section "Intel Integrated Graphics Drivers"
    local PKGS=(
        intel-media-va-driver mesa-vulkan-drivers
        libvulkan1 mesa-utils libgl1-mesa-dri vainfo
    )
    sudo apt install -y "${PKGS[@]}" || {
        fail "Failed to install Intel IGP drivers"
        return 1
    }
    ok "Intel IGP drivers installed"
}
