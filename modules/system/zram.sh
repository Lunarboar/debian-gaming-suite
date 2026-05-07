#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

setup_zram() {
    local TOTAL_RAM_GB="$1"
    
    print_section "ZRAM (Compressed Swap)"

    if swapon --show 2>/dev/null | grep -q "zram"; then
        ok "ZRAM already active"
        return 0
    fi

    local PERCENTAGE=50
    if [[ "$TOTAL_RAM_GB" -lt 8 ]]; then
        PERCENTAGE=25
    elif [[ "$TOTAL_RAM_GB" -lt 16 ]]; then
        PERCENTAGE=33
    fi

    info "System RAM: ${TOTAL_RAM_GB}GB → Configuring ZRAM at ${PERCENTAGE}%"

    step "Installing ZRAM..."
    if sudo apt install -y -qq zram-config 2>/dev/null; then
        sudo systemctl enable zram-config --now 2>/dev/null || true
        ok "ZRAM installed and enabled"
    else
        warn "ZRAM install failed — skipping"
    fi
}
