#!/bin/bash

[[ -z "$NC" ]] && source "$(dirname "$0")/../../utils/common.sh"
[[ -z "$BACKUP_DIR" ]] && source "$(dirname "$0")/../../utils/rollback.sh"

apply_grub_tweaks() {
    local CHOSEN_CPU="$1"
    local CHOSEN_GPU="$2"
    local ADVANCED_MODE="$3"

    print_section "GRUB Boot Parameters"

    local GRUB_FILE="/etc/default/grub"
    if [[ ! -f "$GRUB_FILE" ]]; then
        fail "$GRUB_FILE not found. Cannot apply GRUB tweaks."
        return 1
    fi
    
    backup_file "$GRUB_FILE"

    # Default performance params
    local PARAMS="quiet splash nowatchdog split_lock_detect=off"
    
    if [[ "$ADVANCED_MODE" == "true" ]]; then
        PARAMS="$PARAMS mitigations=off nohz_full=all rcu_nocbs=all threadirqs"
    fi

    if [[ "$CHOSEN_CPU" == "amd" ]]; then
        PARAMS="$PARAMS amd_pstate=active"
    else
        PARAMS="$PARAMS intel_pstate=active"
    fi

    if [[ "$CHOSEN_GPU" == "nvidia" ]] || [[ "$CHOSEN_GPU" == *"nvidia"* ]]; then
        PARAMS="$PARAMS nvidia-drm.modeset=1"
    fi

    # Clean up double spaces
    PARAMS=$(echo "$PARAMS" | tr -s ' ')

    step "Updating $GRUB_FILE..."
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$PARAMS\"|" "$GRUB_FILE" || {
        fail "Failed to modify $GRUB_FILE"
        return 1
    }

    step "Regenerating GRUB config..."
    if sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
        ok "GRUB updated"
    else
        fail "GRUB regeneration failed"
        return 1
    fi
}
