#!/bin/bash

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';        BOLD='\033[1m';  NC='\033[0m'

# ── Log Setup ────────────────────────────────────────────────────────────────
LOG_FILE="$HOME/debian-gaming-$(date +%Y%m%d-%H%M%S).log"

# ── Helpers ──────────────────────────────────────────────────────────────────
ok()    { echo -e "  ${GREEN}✓${NC}  $1"; }
info()  { echo -e "  ${CYAN}→${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "  ${RED}✗${NC}  $1"; }
step()  { echo -e "\n  ${MAGENTA}▶${NC}  ${BOLD}$1${NC}"; }

print_section() {
    echo -e "\n${BLUE}  ┌───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}  │${NC}  ${YELLOW}${BOLD}$1${NC}"
    echo -e "${BLUE}  └───────────────────────────────────────────────────────────────┘${NC}"
}

# ── Robust Error Handling ────────────────────────────────────────────────────
error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_command="$3"
    local func_stack="${FUNCNAME[*]}"
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}${BOLD}  ❌ CRITICAL ERROR DETECTED${NC}"
        echo -e "  ${RED}Command   :${NC} $bash_command"
        echo -e "  ${RED}Line      :${NC} $line_no"
        echo -e "  ${RED}Exit Code :${NC} $exit_code"
        echo -e "  ${RED}Trace     :${NC} ${func_stack:-main}"
        echo -e "\n  ${YELLOW}Check the log for details: $LOG_FILE${NC}"
        exit "$exit_code"
    fi
}

# Trap errors and call error_handler
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
trap 'echo -e "\n${YELLOW}  ⚠ Script interrupted by user.${NC}"; exit 1' SIGINT SIGTERM

log_init() {
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "Logging started: $LOG_FILE"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        fail "Do not run as root. Run as your normal user."
        exit 1
    fi
}

check_internet() {
    step "Checking internet connection..."
    if ! curl -s --max-time 10 https://google.com > /dev/null; then
        fail "No internet connection. Please check your network."
        exit 1
    fi
    ok "Internet confirmed"
}

confirm() {
    echo -ne "\n  ${YELLOW}$1 ${WHITE}[y/N]${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}
