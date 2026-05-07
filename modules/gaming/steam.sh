#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

install_steam() {
    print_section "Steam Installation"

    if command -v steam &>/dev/null; then
        ok "Steam already installed"
        return 0
    fi

    step "Installing Steam..."
    if sudo apt install -y steam-installer 2>/dev/null || sudo apt install -y steam 2>/dev/null; then
        ok "Steam installed via APT"
    else
        warn "Steam APT install failed — trying Flatpak..."
        if command -v flatpak &>/dev/null; then
            flatpak install -y flathub com.valvesoftware.Steam 2>/dev/null && ok "Steam installed via Flatpak"
        else
            warn "Flatpak not found — skipping Steam"
        fi
    fi
}
