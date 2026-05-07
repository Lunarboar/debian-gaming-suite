#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

setup_anticheat() {
    print_section "Anti-Cheat Support (EAC + BattlEye)"

    local ENV_FILE="/etc/environment.d/99-anticheat.conf"
    backup_file "$ENV_FILE"
    
    sudo tee "$ENV_FILE" > /dev/null << 'EOF'
# Anti-Cheat Linux Support via Proton
PROTON_EAC_RUNTIME=/run/pressure-vessel/mnt/steamrt
PROTON_BATTLEYE_RUNTIME=/run/pressure-vessel/mnt/steamrt
WINE_LARGE_ADDRESS_AWARE=1
PROTON_USE_SECCOMP=1
EOF
    
    step "Setting kernel parameter for EAC compatibility..."
    sudo sysctl -w kernel.perf_event_paranoid=-1 > /dev/null 2>&1
    ok "Anti-cheat environment and kernel parameters configured"
}
