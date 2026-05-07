#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

setup_repos() {
    local DISTRO_BASE="$1"
    local CODENAME="$2"
    local PKG_MGR="$3"

    print_section "Configuring Repositories"

    step "Backing up APT sources..."
    backup_file "/etc/apt/sources.list"
    if [[ -d /etc/apt/sources.list.d ]]; then
        for f in /etc/apt/sources.list.d/*.list; do
            [[ -e "$f" ]] && backup_file "$f"
        done
    fi
    ok "APT sources backed up"

    if [[ "$DISTRO_BASE" == "debian" ]]; then
        step "Enabling contrib and non-free for Debian..."
        sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
        sudo $PKG_MGR update -qq
        ok "Contrib and non-free enabled"
    fi

    # Enable 32-bit architecture
    step "Enabling 32-bit architecture..."
    if ! dpkg --print-foreign-architectures | grep -q "i386"; then
        sudo dpkg --add-architecture i386
        sudo $PKG_MGR update -qq
        ok "i386 architecture added"
    else
        info "i386 architecture already enabled"
    fi
}

add_ppa() {
    local PPA="$1"
    local NAME="$2"
    local DISTRO_BASE="$3"
    
    if [[ "$DISTRO_BASE" == "debian" ]]; then
        warn "Skipping PPA '$NAME' on Debian (unstable/unsafe)"
        return 0
    fi

    if grep -ri "$PPA" /etc/apt/sources.list.d/ &>/dev/null; then
        info "PPA $NAME already exists"
        return 0
    fi

    step "Adding $NAME PPA ($PPA)..."
    sudo add-apt-repository -y "ppa:$PPA" 2>/dev/null && ok "$NAME PPA added" || warn "Could not add $NAME PPA"
}
