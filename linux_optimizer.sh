#!/bin/bash

# =========================================
# Linux Optimizer Script
# =========================================

# Directories & Log Setup
OPT_DIR="$HOME/Downloads/LinuxOptimizer"
BACKUP_DIR="$OPT_DIR/backups"
LOG_DIR="$OPT_DIR/logs"
BROWSER_DIR="$OPT_DIR/browser_configs"
TEMP_DIR="$OPT_DIR/temp"
LOG_FILE="$LOG_DIR/linux_optimizer.log"

mkdir -p "$BACKUP_DIR" "$LOG_DIR" "$BROWSER_DIR" "$TEMP_DIR"

echo "Starting Linux Optimizer..." > "$LOG_FILE"

# Helper Functions
print_section() {
    local title="$1"
    echo -e "\n[ $title ]" | tee -a "$LOG_FILE"
}

run_cmd() {
    local cmd="$1"
    eval "$cmd" >> "$LOG_FILE" 2>&1
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    read -p "$prompt [$default]: " choice
    choice=${choice:-$default}
    [[ "$choice" =~ ^[Yy]$ ]]
}

# Detect Distribution
DISTRO=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi

SUPPORTED_DISTROS=("ubuntu" "debian" "linuxmint" "fedora" "arch" "manjaro" "opensuse" "pop" "zorin" "elementary" "linuxlite" "void" "puppy" "biebian" "rebeccablackos" "tinycore" "alpine" "slackware")

if [[ ! " ${SUPPORTED_DISTROS[@]} " =~ " ${DISTRO} " ]]; then
    echo "Warning: Your distro ($DISTRO) is not officially supported." | tee -a "$LOG_FILE"
    echo "Request support here: https://github.com/StubbledBannana/Linux-Multipurpose-Optimization-Script/issues" | tee -a "$LOG_FILE"
    if ! prompt_yes_no "Do you want to continue anyway?" "n"; then
        echo "Exiting script." | tee -a "$LOG_FILE"
        exit 1
    fi
fi

# Detect Package Manager
PKG_CMD=""
UPDATE_CMD=""
INSTALL_CMD=""

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|linuxlite)
        PKG_CMD="apt"
        UPDATE_CMD="apt update -y"
        INSTALL_CMD="apt install -y"
        ;;
    fedora)
        PKG_CMD="dnf"
        UPDATE_CMD="dnf check-update -y"
        INSTALL_CMD="dnf install -y"
        ;;
    arch|manjaro)
        PKG_CMD="pacman"
        UPDATE_CMD="pacman -Syu --noconfirm"
        INSTALL_CMD="pacman -S --noconfirm"
        ;;
    opensuse)
        PKG_CMD="zypper"
        UPDATE_CMD="zypper refresh"
        INSTALL_CMD="zypper install -y"
        ;;
    void)
        PKG_CMD="xbps"
        UPDATE_CMD="xbps-install -Su"
        INSTALL_CMD="xbps-install -y"
        ;;
    puppy|biebian|rebeccablackos)
        PKG_CMD="petget"
        UPDATE_CMD=""
        INSTALL_CMD="petget"
        ;;
    tinycore|alpine|slackware)
        PKG_CMD=""
        UPDATE_CMD=""
        INSTALL_CMD=""
        ;;
esac

# Dry-Run Checks
declare -A DRYRUN_ERRORS
print_section "Performing Dry-Run Checks"

if lspci | grep -i nvidia &>/dev/null; then
    if ! command -v nvidia-smi &>/dev/null; then
        DRYRUN_ERRORS["GPU"]="NVIDIA driver missing"
    fi
fi

# Ask User Mode
echo -e "\nChoose Optimization Mode:"
echo "1) Full Optimization"
echo "2) Step-by-Step"
read -p "Enter choice [1/2]: " MODE
MODE=${MODE:-1}

# Begin Optimizations

# 1) Battery & Power
if [ "$MODE" -eq 1 ] || prompt_yes_no "Optimize Battery & Power settings?" "Y"; then
    print_section "Battery & Power Tweaks"
    if ! command -v tlp &>/dev/null; then
        run_cmd "$INSTALL_CMD tlp"
    fi
    run_cmd "tlp start"
    if command -v powertop &>/dev/null; then
        run_cmd "powertop --auto-tune"
    fi
fi

# 2) CPU & System
if [ "$MODE" -eq 1 ] || prompt_yes_no "Optimize CPU & System Performance?" "Y"; then
    print_section "CPU & System Performance"
    run_cmd "sysctl -w vm.swappiness=10"
    run_cmd "sysctl -w vm.vfs_cache_pressure=50"
    run_cmd "cp /etc/sysctl.conf $BACKUP_DIR/sysctl.conf.bak"
fi

# 3) GPU Tweaks
if [ "$MODE" -eq 1 ] || prompt_yes_no "Apply GPU tweaks?" "Y"; then
    print_section "GPU Optimization"
    if [[ -z "${DRYRUN_ERRORS[GPU]}" ]]; then
        run_cmd "update-grub"
    else
        echo "Skipping GPU tweaks: ${DRYRUN_ERRORS[GPU]}" | tee -a "$LOG_FILE"
    fi
fi

# 4) Browser Optimizations
if [ "$MODE" -eq 1 ] || prompt_yes_no "Optimize Browsers?" "Y"; then
    print_section "Browser Speed Enhancements"
    BROWSERS=("firefox" "chromium" "google-chrome" "brave-browser")
    for b in "${BROWSERS[@]}"; do
        if command -v "$b" &>/dev/null; then
            run_cmd "cp -r ~/.${b,,} $BROWSER_DIR/${b}_backup"
            run_cmd "echo 'Enabling preload/prefetch optimizations for $b' >> $LOG_FILE"
        fi
    done
fi

# 5) Flatpak & Snap
if [ "$MODE" -eq 1 ] || prompt_yes_no "Optimize Flatpak & Snap apps?" "Y"; then
    print_section "Flatpak & Snap Cleanup"
    if command -v flatpak &>/dev/null; then
        run_cmd "flatpak uninstall --unused -y"
        run_cmd "flatpak update -y"
    fi
    if command -v snap &>/dev/null; then
        run_cmd "snap refresh"
        run_cmd "snap set system refresh.retain=2"
    fi
fi

# 6) SSD TRIM
if [ "$MODE" -eq 1 ] || prompt_yes_no "Enable SSD TRIM?" "Y"; then
    print_section "SSD Optimizations"
    if lsblk -d -o name,rota | grep -w '0' &>/dev/null; then
        run_cmd "fstrim -av"
    fi
fi

# 7) TCP BBR
if [ "$MODE" -eq 1 ] || prompt_yes_no "Enable TCP BBR?" "Y"; then
    print_section "Networking Tweaks"
    run_cmd "modprobe tcp_bbr"
    run_cmd "echo 'tcp_bbr' >> /etc/modules-load.d/tcp_bbr.conf"
    run_cmd "sysctl -w net.core.default_qdisc=fq"
    run_cmd "sysctl -w net.ipv4.tcp_congestion_control=bbr"
fi

# Final Message & Reboot Prompt
echo -e "\nLinux Mint Optimizations Complete! Check the log for details." | tee -a "$LOG_FILE"

if prompt_yes_no "Do you want to reboot now?" "y"; then
    echo "Rebooting..." | tee -a "$LOG_FILE"
    reboot
fi
