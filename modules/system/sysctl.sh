#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

apply_sysctl_tweaks() {
    local CPU_LABEL="$1"
    local GPU_LABEL="$2"

    print_section "System Gaming Tweaks (sysctl)"

    local FILE="/etc/sysctl.d/99-gaming-universal.conf"
    backup_file "$FILE"

    step "Writing universal gaming sysctl config..."
    sudo tee "$FILE" > /dev/null << EOF
# ═══════════════════════════════════════════════════
# Universal Debian Gaming Tweaks
# CPU: $CPU_LABEL | GPU: $GPU_LABEL
# ═══════════════════════════════════════════════════

# ── Memory ────────────────────────────────────────
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.nr_hugepages=128
vm.compaction_proactiveness=0

# ── Network (BBR — lower ping in online games) ────
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3

# ── CPU & Scheduler ───────────────────────────────
kernel.sched_autogroup_enabled=1
kernel.numa_balancing=0
kernel.perf_event_paranoid=-1

# ── Filesystem ────────────────────────────────────
fs.inotify.max_user_watches=524288
fs.file-max=2097152
EOF

    sudo sysctl -p "$FILE" > /dev/null 2>&1
    ok "Gaming sysctl tweaks applied in $FILE"
}
