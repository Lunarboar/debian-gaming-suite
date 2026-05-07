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
                sudo gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg 2>/dev/null

            echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
https://repositories.intel.com/gpu/ubuntu ${CODENAME} client" | \
                sudo tee /etc/apt/sources.list.d/intel-graphics.list > /dev/null

            sudo apt update -qq 2>/dev/null && ok "Intel graphics repo added" || \
                warn "Could not add Intel repo — using distro drivers"
        fi
    fi

    step "Installing Intel Arc Mesa & Vulkan drivers..."
    local PKGS=(
        intel-media-va-driver-non-free intel-opencl-icd
        mesa-vulkan-drivers libvulkan1 mesa-utils
        libgl1-mesa-dri libdrm2 libdrm-intel1 vainfo linux-firmware
    )
    sudo apt install -y -qq "${PKGS[@]}" 2>/dev/null && ok "Intel Arc drivers installed"

    step "Enabling Intel GuC/HuC firmware (Arc performance)..."
    local MODPROBE="/etc/modprobe.d/intel-arc-gaming.conf"
    if [[ ! -f "$MODPROBE" ]]; then
        backup_file "$MODPROBE"
        sudo tee "$MODPROBE" > /dev/null << 'EOF'
# Intel Arc Gaming Optimisation
options i915 enable_guc=3
options i915 enable_fbc=1
EOF
        sudo update-initramfs -u 2>/dev/null
        ok "Intel GuC/HuC enabled — active after reboot"
    fi
}

install_intel_igp_drivers() {
    print_section "Intel Integrated Graphics Drivers"
    local PKGS=(
        intel-media-va-driver mesa-vulkan-drivers
        libvulkan1 mesa-utils libgl1-mesa-dri libdrm-intel1 vainfo
    )
    sudo apt install -y -qq "${PKGS[@]}" 2>/dev/null && ok "Intel IGP drivers installed"
}
