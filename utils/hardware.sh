#!/bin/bash

detect_gpu() {
    local GPU_LIST=$(lspci 2>/dev/null | grep -iE "vga|3d|display")
    local VENDOR="unknown"
    local NAME="Unknown GPU"

    if echo "$GPU_LIST" | grep -qi "nvidia"; then
        NAME=$(echo "$GPU_LIST" | grep -i nvidia | head -1 | sed 's/.*: //')
        VENDOR="nvidia"
    elif echo "$GPU_LIST" | grep -qi "amd\|radeon\|advanced micro"; then
        NAME=$(echo "$GPU_LIST" | grep -iE "amd|radeon" | head -1 | sed 's/.*: //')
        VENDOR="amd"
    elif echo "$GPU_LIST" | grep -qi "intel.*arc\|intel.*xe\|intel.*alchemist"; then
        NAME=$(echo "$GPU_LIST" | grep -i intel | head -1 | sed 's/.*: //')
        VENDOR="intel_arc"
    elif echo "$GPU_LIST" | grep -qi "intel"; then
        NAME=$(echo "$GPU_LIST" | grep -i intel | head -1 | sed 's/.*: //')
        VENDOR="intel_igp"
    fi

    # Detect Hybrid
    local NVIDIA_COUNT=$(echo "$GPU_LIST" | grep -ic nvidia)
    local AMD_COUNT=$(echo "$GPU_LIST" | grep -icE "amd|radeon")
    local INTEL_COUNT=$(echo "$GPU_LIST" | grep -ic intel)

    if [[ $NVIDIA_COUNT -gt 0 ]] && [[ $AMD_COUNT -gt 0 ]]; then
        VENDOR="hybrid_amd_nvidia"
        NAME="AMD + NVIDIA Hybrid"
    elif [[ $NVIDIA_COUNT -gt 0 ]] && [[ $INTEL_COUNT -gt 0 ]]; then
        VENDOR="hybrid_intel_nvidia"
        NAME="Intel + NVIDIA Hybrid"
    fi

    echo "$VENDOR|$NAME"
}

detect_cpu() {
    local CPU_INFO=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local VENDOR="unknown"

    if echo "$CPU_INFO" | grep -qi "amd\|ryzen\|threadripper\|epyc"; then
        VENDOR="amd"
    elif echo "$CPU_INFO" | grep -qi "intel"; then
        VENDOR="intel"
    fi

    echo "$VENDOR|$CPU_INFO"
}

get_total_ram_gb() {
    local RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo "$((RAM_KB / 1024 / 1024))"
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        local NAME="${PRETTY_NAME:-Unknown}"
        local CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo 'unknown')}"
        local ID_LOWER="${ID,,}"
        local ID_LIKE_LOWER="${ID_LIKE,,}"
        local BASE="debian"
        local PKG_MGR="apt"

        # Special Distros
        if [[ "$ID_LOWER" == "pikaos" ]]; then
            BASE="pikaos"
        elif [[ "$ID_LOWER" == "vanilla" ]]; then
            BASE="vanillaos"
            PKG_MGR="apx"
        elif [[ "$ID_LOWER" == "ubuntu" ]] || echo "$ID_LIKE_LOWER" | grep -q "ubuntu"; then
            BASE="ubuntu"
        fi

        echo "$BASE|$NAME|$CODENAME|$PKG_MGR"
    else
        echo "unknown|Unknown Distro|unknown|apt"
    fi
}
