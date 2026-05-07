#!/bin/bash

# ════════════════════════════════════════════════════════════════════════════
# DEBIAN GAMING REVERT — BACK TO STOCK
# ════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; NC='\033[0m'

# ── Error Handling ───────────────────────────────────────────────────────────
error_handler() {
    local exit_code=$1
    local line_no=$2
    local command="$3"
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}${BOLD}  ❌ REVERT ERROR: Command failed at line $line_no${NC}"
        echo -e "  ${RED}Command: ${NC} $command"
        exit "$exit_code"
    fi
}
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
trap 'echo -e "\n${YELLOW}  ⚠ Revert interrupted.${NC}"; exit 1' SIGINT SIGTERM

ok()    { echo -e "  ${GREEN}✓${NC}  $1"; }
info()  { echo -e "  ${CYAN}→${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "  ${RED}✗${NC}  $1"; }
step()  { echo -e "\n  ${MAGENTA}▶${NC}  $1"; }

confirm() {
    echo -ne "\n  ${YELLOW}$1 ${WHITE}[y/N]${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ── Check Root ───────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then fail "Don't run as root"; exit 1; fi

echo -e "${BLUE}Starting system revert...${NC}"

# 1. Restore system files from latest backup
BACKUP_BASE="$HOME/.local/share/debian-gaming-backups"
if [[ -d "$BACKUP_BASE" ]]; then
    step "Checking for backups..."
    LATEST_BACKUP=$(ls -td "$BACKUP_BASE"/*/ 2>/dev/null | head -1)
    if [[ -n "$LATEST_BACKUP" ]]; then
        info "Found latest backup in $LATEST_BACKUP"
        if [[ -f "$LATEST_BACKUP/restore.sh" ]]; then
            if confirm "Run the restore script from this backup?"; then
                sudo bash "$LATEST_BACKUP/restore.sh" || fail "Restoration failed"
            fi
        fi
    else
        warn "No backups found in $BACKUP_BASE"
    fi
fi

# 2. Kernel Management (Interactive)
if uname -r | grep -q "liquorix"; then
    step "Kernel Management"
    if confirm "Liquorix kernel detected. Switch back to stock Debian kernel by default?"; then
        info "Updating GRUB to prioritize stock kernel..."
        if [[ -f /etc/default/grub ]]; then
            sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub
            sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || warn "GRUB update failed"
            ok "GRUB default entry reset."
        fi
    fi
fi

# 3. Remove added configuration files
step "Removing custom configuration files..."
FILES_TO_REMOVE=(
    "/etc/sysctl.d/99-gaming.conf"
    "/etc/modprobe.d/amdgpu-gaming.conf"
    "/etc/modprobe.d/nvidia-gaming.conf"
    "/etc/modprobe.d/intel-arc-gaming.conf"
    "/etc/environment.d/99-nvidia-gaming.conf"
    "/etc/environment.d/99-gaming-upscaling.conf"
    "/etc/environment.d/99-anticheat.conf"
    "$HOME/.config/gamemode.ini"
    "$HOME/.config/MangoHud/MangoHud.conf"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$file" ]]; then
        info "Removing $file"
        sudo rm -f "$file" || warn "Could not remove $file"
    fi
done

# 4. Remove Distrobox container
if command -v distrobox &>/dev/null; then
    if distrobox list 2>/dev/null | grep -q "gaming-arch"; then
        step "Removing Distrobox container 'gaming-arch'..."
        distrobox rm -f gaming-arch || warn "Could not remove distrobox container"
        if [[ -d "$HOME/.local/share/distrobox/gaming-home" ]]; then
            rm -rf "$HOME/.local/share/distrobox/gaming-home" || warn "Could not remove container home"
        fi
    fi
fi

echo -e "\n${GREEN}${BOLD}  ✓ Revert process finished.${NC}"
echo -e "${RED}${BOLD}  ⚠ Please REBOOT now to apply the changes.${NC}\n"
