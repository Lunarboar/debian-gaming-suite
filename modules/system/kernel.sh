#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

install_liquorix_kernel() {
    print_section "Liquorix Gaming Kernel"

    if uname -r | grep -q "liquorix"; then
        ok "Liquorix kernel already running: $(uname -r)"
        return 0
    fi

    step "Adding Liquorix repository..."
    # Liquorix provides a simple script or we can add the repo manually
    # For Debian/Ubuntu, it's often easiest via their script or manual apt
    if curl -s 'https://liquorix.net/install-liquorix.sh' | sudo bash; then
        ok "Liquorix kernel installed — active after reboot"
    else
        fail "Liquorix kernel installation failed"
    fi
}
