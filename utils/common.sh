#!/bin/bash

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';        BOLD='\033[1m';  NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
LOG_FILE="$HOME/debian-gaming-setup-$(date +%Y%m%d-%H%M%S).log"

log_init() {
    # If LOG_FILE is already defined and redirected, this might be a sub-module
    # We want to ensure we append to the main log.
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# ── Helpers ───────────────────────────────────────────────────────────────────
ok()    { echo -e "  ${GREEN}✓${NC}  $1"; }
info()  { echo -e "  ${CYAN}→${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "  ${RED}✗${NC}  $1"; }
step()  { echo -e "\n  ${MAGENTA}▶${NC}  ${BOLD}$1${NC}"; }
title() { echo -e "\n  ${WHITE}${BOLD}$1${NC}"; }

print_section() {
    echo -e "\n${BLUE}  ┌───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC}  ${YELLOW}${BOLD}$1${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────────────────────┘${NC}"
}

confirm() {
    echo -ne "\n  ${YELLOW}$1 ${WHITE}[y/N]${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        fail "Do not run as root. Run as your normal user — sudo will be called when needed."
        exit 1
    fi
}

check_internet() {
    step "Checking internet connection..."
    if ! curl -s --max-time 8 https://google.com > /dev/null; then
        fail "No internet connection detected. Connect and try again."
        exit 1
    fi
    ok "Internet confirmed"
}
