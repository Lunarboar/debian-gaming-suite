#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

install_liquorix_kernel() {
    print_section "Liquorix Gaming Kernel"

    if uname -r | grep -q "liquorix"; then
        ok "Liquorix kernel already running: $(uname -r)"
        return 0
    fi

    step "Adding Liquorix repository and installing..."
    if ! curl -s 'https://liquorix.net/install-liquorix.sh' | sudo bash; then
        fail "Liquorix kernel installation failed. Check your internet connection or try manually."
        return 1
    fi
    ok "Liquorix kernel installed successfully"
}
