#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

install_native_gaming_stack() {
    print_section "Native Gaming Stack (Host)"

    step "Installing Steam..."
    sudo apt install -y steam-installer || sudo apt install -y steam || warn "Steam install failed"

    local PKGS=(gamemode mangohud lutris)
    for pkg in "${PKGS[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            step "Installing $pkg..."
            sudo apt install -y -qq "$pkg" || warn "Could not install $pkg"
        fi
    done

    # Heroic Fallback logic
    if ! dpkg -l "heroic-games-launcher-bin" &>/dev/null; then
        step "Installing Heroic Games Launcher..."
        if ! sudo apt install -y heroic-games-launcher-bin 2>/dev/null; then
            info "Heroic not found in APT. Trying Flatpak fallback..."
            if ! command -v flatpak &>/dev/null; then
                sudo apt install -y flatpak
                sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            fi
            sudo flatpak install -y flathub com.heroicgameslauncher.hgl || warn "Flatpak Heroic install failed"
        fi
    fi

    setup_gamemode_config
    setup_mangohud_config
}

setup_gamemode_config() {
    print_section "GameMode Configuration"
    sudo usermod -aG gamemode "$USER"
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/gamemode.ini" << EOF
[general]
reaper=yes
softrealtime=auto
renice=10
[cpu]
governor=performance
EOF
    ok "Optimised gamemode.ini created"
}

setup_mangohud_config() {
    step "Setting up MangoHud config..."
    local MANGOHUD_DIR="$HOME/.config/MangoHud"
    mkdir -p "$MANGOHUD_DIR"
    if [[ ! -f "$MANGOHUD_DIR/MangoHud.conf" ]]; then
        cat > "$MANGOHUD_DIR/MangoHud.conf" << 'EOF'
fps
frametime
gpu_stats
gpu_temp
cpu_stats
cpu_temp
ram
vram
arch
EOF
        ok "MangoHud config created"
    fi
}
