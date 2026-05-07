#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"

setup_distrobox_gaming() {
    print_section "Distrobox Arch Linux Gaming Environment"

    # 1. Install Distrobox and Podman/Docker
    step "Checking Distrobox dependencies..."
    if ! command -v distrobox &>/dev/null; then
        step "Installing Distrobox & Podman..."
        # Use the detected package manager from setup.sh (passed via env or global)
        local PM=${PKG_MGR:-apt}
        sudo $PM install -y distrobox podman || {
            fail "Failed to install Distrobox/Podman via $PM."
            return 1
        }
    fi

    # 2. Create Arch container
    local CONTAINER_NAME="gaming-arch"
    local CUSTOM_HOME="$HOME/.local/share/distrobox/gaming-home"
    
    if [[ ! -d "$CUSTOM_HOME" ]]; then
        mkdir -p "$CUSTOM_HOME" || { fail "Cannot create home directory: $CUSTOM_HOME"; return 1; }
    fi

    if distrobox list | grep -q "$CONTAINER_NAME"; then
        ok "Distrobox container '$CONTAINER_NAME' already exists"
    else
        step "Creating Arch Linux container (this may take a while)..."
        distrobox create --name "$CONTAINER_NAME" --image archlinux:latest --home "$CUSTOM_HOME" --yes || {
            fail "Failed to create Arch Linux container."
            return 1
        }
        ok "Container '$CONTAINER_NAME' created"
    fi

    # 3. Setup Gaming Stack
    step "Updating container system..."
    distrobox enter "$CONTAINER_NAME" -- sudo pacman -Syu --noconfirm || {
        fail "Failed to update container system."
        return 1
    }

    step "Installing core gaming packages..."
    local ARCH_PKGS=(
        steam mangohud gamemode lib32-mangohud lib32-gamemode
        wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap
        gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils
        lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error
        alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo
        lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite
        libxinerama lib32-libxinerama ncurses lib32-ncurses ocl-icd lib32-ocl-icd
        libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs
        lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader
    )
    
    distrobox enter "$CONTAINER_NAME" -- sudo pacman -S --noconfirm "${ARCH_PKGS[@]}" || {
        fail "Failed to install gaming packages in container."
        return 1
    }

    step "Configuring container user groups..."
    distrobox enter "$CONTAINER_NAME" -- sudo usermod -aG gamemode "$USER" 2>/dev/null || true

    step "Exporting apps to host desktop..."
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --app steam || warn "Could not export Steam shortcut."
    
    # 4. Install Distroshelf (GUI Manager)
    step "Installing Distroshelf (GUI Manager)..."
    if command -v flatpak &>/dev/null; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null
        flatpak install -y flathub io.github.armijn.Distroshelf || warn "Could not install Distroshelf"
    else
        warn "Flatpak not found, skipping Distroshelf installation."
    fi

    ok "Arch Linux gaming environment ready!"
}
