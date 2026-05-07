#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

setup_distrobox_gaming() {
    print_section "Distrobox Arch Linux Gaming Environment"

    # 1. Install Distrobox and Podman/Docker
    step "Checking Distrobox dependencies..."
    if ! command -v distrobox &>/dev/null; then
        step "Installing Distrobox..."
        sudo apt install -y distrobox podman 2>/dev/null || apx install -y distrobox podman 2>/dev/null
    fi

    # 2. Create Arch container with custom home
    local CONTAINER_NAME="gaming-arch"
    local CUSTOM_HOME="$HOME/.local/share/distrobox/gaming-home"
    mkdir -p "$CUSTOM_HOME"

    if distrobox list | grep -q "$CONTAINER_NAME"; then
        ok "Distrobox container '$CONTAINER_NAME' already exists"
    else
        step "Creating Arch Linux container (this may take a while)..."
        distrobox create --name "$CONTAINER_NAME" --image archlinux:latest --home "$CUSTOM_HOME" --yes
        ok "Container '$CONTAINER_NAME' created"
    fi

    # 3. Setup Gaming Stack inside Arch
    step "Initializing gaming stack inside Arch container..."
    distrobox enter "$CONTAINER_NAME" -- sudo pacman -Syu --noconfirm
    distrobox enter "$CONTAINER_NAME" -- sudo pacman -S --noconfirm \
        steam mangohud gamemode lib32-mangohud lib32-gamemode \
        wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap \
        gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils \
        lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error \
        alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo \
        lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite \
        libxinerama lib32-libxinerama ncurses lib32-ncurses ocl-icd lib32-ocl-icd \
        libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs \
        lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader

    # 4. Export Steam to host desktop
    step "Exporting Steam to host desktop..."
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --app steam
    
    ok "Arch Linux gaming environment ready!"
    info "You can now launch Steam from your menu (it runs inside Arch)."
}
