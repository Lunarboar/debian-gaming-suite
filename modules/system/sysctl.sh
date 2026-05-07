#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

apply_sysctl_tweaks() {
    local CPU_VENDOR="$1"
    local GPU_VENDOR="$2"

    print_section "System Performance Tweaks (sysctl)"

    local SYS_FILE="/etc/sysctl.d/99-gaming.conf"
    backup_file "$SYS_FILE"

    sudo tee "$SYS_FILE" > /dev/null << EOF
# Networking & General
vm.swappiness=10
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Kernel / Performance
kernel.perf_event_paranoid=-1
kernel.sched_autogroup_enabled=0

# Split-Lock Mitigation
# Significant boost for Intel 12th Gen+ CPUs in games like God of War
kernel.split_lock_mitigate=0

# Increase max map count for heavy games (Starfield, etc.)
vm.max_map_count=2147483642
EOF

    step "Applying sysctl settings..."
    sudo sysctl -p "$SYS_FILE" > /dev/null 2>&1 || warn "Could not apply all sysctl tweaks"
    ok "sysctl configuration updated"
}
