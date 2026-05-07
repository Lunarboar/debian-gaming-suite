#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

install_gaming_tools() {
    print_section "Gaming Stack (GameMode, MangoHud, Lutris)"

    local PKGS=(gamemode mangohud lutris heroic-games-launcher-bin)
    
    for pkg in "${PKGS[@]}"; do
        if dpkg -l "$pkg" &>/dev/null; then
            info "$pkg already installed"
        else
            step "Installing $pkg..."
            if sudo apt install -y -qq "$pkg" 2>/dev/null; then
                ok "$pkg installed"
            else
                warn "$pkg not found in APT — please install manually or via Flatpak"
            fi
        fi
    done

    # MangoHud config
    step "Setting up MangoHud config..."
    local MANGOHUD_DIR="$HOME/.config/MangoHud"
    mkdir -p "$MANGOHUD_DIR"
    if [[ ! -f "$MANGOHUD_DIR/MangoHud.conf" ]]; then
        cat > "$MANGOHUD_DIR/MangoHud.conf" << 'EOF'
fps
frametime
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
cpu_stats
cpu_temp
ram
vram
wine
vulkan_driver
arch
EOF
        ok "MangoHud config created"
    fi
}
