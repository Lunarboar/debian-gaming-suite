#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

apply_grub_tweaks() {
    local CHOSEN_CPU="$1"
    local CHOSEN_GPU="$2"
    local ADVANCED_MODE="$3"

    print_section "GRUB Boot Parameters"

    local GRUB_FILE="/etc/default/grub"
    backup_file "$GRUB_FILE"

    # Base parameters
    local PARAMS="quiet splash nowatchdog"
    
    if [[ "$ADVANCED_MODE" == "true" ]]; then
        info "Advanced mode: disabling CPU mitigations for maximum performance"
        PARAMS="$PARAMS mitigations=off nohz_full=all rcu_nocbs=all threadirqs"
    else
        info "Safe mode: keeping CPU mitigations active"
    fi

    # CPU-specific
    if [[ "$CHOSEN_CPU" == "amd" ]]; then
        PARAMS="$PARAMS amd_pstate=active"
    else
        PARAMS="$PARAMS intel_pstate=active"
    fi

    # GPU-specific
    if [[ "$CHOSEN_GPU" == "nvidia" ]] || [[ "$CHOSEN_GPU" == *"nvidia"* ]]; then
        PARAMS="$PARAMS nvidia-drm.modeset=1"
    elif [[ "$CHOSEN_GPU" == "intel_arc" ]]; then
        PARAMS="$PARAMS i915.enable_guc=3"
    fi

    # Clean double spaces
    PARAMS=$(echo "$PARAMS" | tr -s ' ')

    step "Updating $GRUB_FILE..."
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$PARAMS\"|" "$GRUB_FILE"

    if sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
        ok "GRUB updated with gaming parameters"
    else
        fail "GRUB update failed — please check $GRUB_FILE manually"
    fi
}
