#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

get_latest_github_tag() {
    curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name"' | cut -d'"' -f4
}

install_ge_proton() {
    print_section "GE-Proton (GloriousEggroll)"

    local PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$PROTON_DIR"

    step "Fetching latest GE-Proton..."
    local LATEST_GE=$(get_latest_github_tag "GloriousEggroll/proton-ge-custom")
    [[ -z "$LATEST_GE" ]] && { fail "Could not fetch GE-Proton info"; return 1; }

    if [[ -d "$PROTON_DIR/$LATEST_GE" ]]; then
        ok "GE-Proton $LATEST_GE already installed"
        return 0
    fi

    step "Downloading GE-Proton $LATEST_GE..."
    if curl -L --progress-bar \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_GE/$LATEST_GE.tar.gz" \
        -o "/tmp/$LATEST_GE.tar.gz"; then
        tar -xzf "/tmp/$LATEST_GE.tar.gz" -C "$PROTON_DIR"
        rm -f "/tmp/$LATEST_GE.tar.gz"
        ok "GE-Proton $LATEST_GE installed"
    else
        fail "GE-Proton download failed"
    fi
}

install_dxvk_vkd3d() {
    print_section "DXVK & VKD3D-Proton"

    local DXVK_DIR="$HOME/.local/share/dxvk"
    local VKD3D_DIR="$HOME/.local/share/vkd3d"
    mkdir -p "$DXVK_DIR" "$VKD3D_DIR"

    step "Updating DXVK..."
    local LATEST_DXVK=$(get_latest_github_tag "doitsujin/dxvk")
    if [[ -n "$LATEST_DXVK" && ! -d "$DXVK_DIR/$LATEST_DXVK" ]]; then
        local DXVK_URL=$(curl -s "https://api.github.com/repos/doitsujin/dxvk/releases/latest" | grep '"browser_download_url"' | grep ".tar.gz" | cut -d'"' -f4 | head -1)
        curl -L -s "$DXVK_URL" -o "/tmp/dxvk.tar.gz"
        mkdir -p "$DXVK_DIR/$LATEST_DXVK"
        tar -xzf "/tmp/dxvk.tar.gz" -C "$DXVK_DIR/$LATEST_DXVK" --strip-components=1
        rm -f "/tmp/dxvk.tar.gz"
        ok "DXVK $LATEST_DXVK installed"
    else
        info "DXVK up to date"
    fi

    step "Updating VKD3D-Proton..."
    local LATEST_VKD3D=$(get_latest_github_tag "HansKristian-Work/vkd3d-proton")
    if [[ -n "$LATEST_VKD3D" && ! -d "$VKD3D_DIR/$LATEST_VKD3D" ]]; then
        local VKD3D_URL=$(curl -s "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases/latest" | grep '"browser_download_url"' | grep "tar.zst" | cut -d'"' -f4 | head -1)
        curl -L -s "$VKD3D_URL" -o "/tmp/vkd3d.tar.zst"
        mkdir -p "$VKD3D_DIR/$LATEST_VKD3D"
        tar -xf "/tmp/vkd3d.tar.zst" -C "$VKD3D_DIR/$LATEST_VKD3D" --strip-components=1 2>/dev/null
        rm -f "/tmp/vkd3d.tar.zst"
        ok "VKD3D-Proton $LATEST_VKD3D installed"
    else
        info "VKD3D-Proton up to date"
    fi
}
