#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

get_latest_github_tag() {
    local tag=$(curl -s "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
    if [[ -z "$tag" ]]; then
        warn "Could not fetch latest tag for $1"
        return 1
    fi
    echo "$tag"
}

install_ge_proton() {
    print_section "GE-Proton (GloriousEggroll)"

    local PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$PROTON_DIR" || { fail "Cannot create directory $PROTON_DIR"; return 1; }

    step "Fetching latest GE-Proton..."
    local LATEST_GE=$(get_latest_github_tag "GloriousEggroll/proton-ge-custom")
    [[ -z "$LATEST_GE" ]] && return 1

    if [[ -d "$PROTON_DIR/$LATEST_GE" ]]; then
        ok "GE-Proton $LATEST_GE already installed"
        return 0
    fi

    step "Downloading GE-Proton $LATEST_GE..."
    if curl -L --progress-bar \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_GE/$LATEST_GE.tar.gz" \
        -o "/tmp/$LATEST_GE.tar.gz"; then
        
        step "Extracting GE-Proton..."
        tar -xzf "/tmp/$LATEST_GE.tar.gz" -C "$PROTON_DIR" || { fail "Extraction failed"; return 1; }
        rm -f "/tmp/$LATEST_GE.tar.gz"
        ok "GE-Proton $LATEST_GE installed"
    else
        fail "GE-Proton download failed"
        return 1
    fi
}

install_dxvk_vkd3d() {
    print_section "DXVK & VKD3D-Proton"

    local DXVK_DIR="$HOME/.local/share/dxvk"
    local VKD3D_DIR="$HOME/.local/share/vkd3d"
    mkdir -p "$DXVK_DIR" "$VKD3D_DIR" || return 1

    step "Updating DXVK..."
    local LATEST_DXVK=$(get_latest_github_tag "doitsujin/dxvk")
    if [[ -n "$LATEST_DXVK" && ! -d "$DXVK_DIR/$LATEST_DXVK" ]]; then
        local DXVK_URL=$(curl -s "https://api.github.com/repos/doitsujin/dxvk/releases/latest" | grep '"browser_download_url"' | grep ".tar.gz" | cut -d'"' -f4 | head -1)
        if curl -L -s "$DXVK_URL" -o "/tmp/dxvk.tar.gz"; then
            mkdir -p "$DXVK_DIR/$LATEST_DXVK"
            tar -xzf "/tmp/dxvk.tar.gz" -C "$DXVK_DIR/$LATEST_DXVK" --strip-components=1 || return 1
            rm -f "/tmp/dxvk.tar.gz"
            ok "DXVK $LATEST_DXVK installed"
        fi
    fi
}
