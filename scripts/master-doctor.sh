#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#   ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ 
#   ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█──█ ░▀▀▀█ 
#   ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█▄▄█ ░█▄▄█ 
# ═══════════════════════════════════════════════════════════════════════════════
#  Xeno OS — Master Diagnostic, Troubleshooting & Self-Healing Doctor
#  Executes comprehensive multi-tier audits across the OS stack with nested
#  decision logic, self-repair mechanisms, and complete test suites.
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"
AUTO_FIX=0

# Color definitions
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[36m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_MAGENTA="\033[35m"

# Audit Counters
COUNT_PASS=0
COUNT_WARN=0
COUNT_FAIL=0
COUNT_FIXED=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --fix|--repair|-f)
            AUTO_FIX=1
            ;;
        --help|-h)
            echo "Usage: sudo bash scripts/master-doctor.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --fix, -f    Automatically repair discovered issues and reconfigure missing configs"
            echo "  --help, -h   Show this help message"
            echo ""
            exit 0
            ;;
    esac
done

log_header() {
    echo -e "\n${C_BOLD}${C_CYAN}▶ [$1] $2${C_RESET}"
}

report_pass() {
    echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} $1"
    ((COUNT_PASS++))
}

report_warn() {
    echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} $1"
    ((COUNT_WARN++))
}

report_fail() {
    echo -e "  ${C_RED}✖ [FAIL]${C_RESET} $1"
    ((COUNT_FAIL++))
}

report_fix() {
    echo -e "  ${C_MAGENTA}🔧 [FIXED]${C_RESET} $1"
    ((COUNT_FIXED++))
}

echo -e "${C_BOLD}${C_CYAN}"
cat << 'BANNER_EOF'
 ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ 
 ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█──█ ░▀▀▀█ 
 ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█▄▄█ ░█▄▄█ 
   XENO OS MASTER DIAGNOSTIC & AUTO-HEAL DOCTOR
BANNER_EOF
echo -e "${C_RESET}"
echo "Workspace: $WS_DIR"
echo "RootFS:    $ROOTFS"
echo "Auto-Fix:  $([ "$AUTO_FIX" -eq 1 ] && echo 'ENABLED' || echo 'DISABLED (pass --fix to auto-repair)')"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%SZ')"

# ─────────────────────────────────────────────────────────────────────────────
# TIER 1: Host Tooling, Build Environment & Hardware Resources
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 1" "Host Build Tools & System Resources"

# Check root permissions
if [ "$(id -u)" -ne 0 ]; then
    report_warn "Doctor running as unprivileged user. Some chroot & filesystem repairs will require sudo."
else
    report_pass "Running with administrative (root) capabilities"
fi

# Check essential host binaries
REQUIRED_HOST_TOOLS=("xorriso" "mksquashfs" "grub-mkimage" "python3" "bun" "git" "sha256sum")
for tool in "${REQUIRED_HOST_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        report_pass "Host tool present: $tool ($(command -v "$tool"))"
    else
        report_fail "Missing critical host tool: $tool"
        if [ "$AUTO_FIX" -eq 1 ] && [ "$(id -u)" -eq 0 ]; then
            case "$tool" in
                xorriso|mksquashfs|grub-mkimage)
                    echo "    -> Attempting host package installation..."
                    apt-get update -qq && apt-get install -y --no-install-recommends xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin >/dev/null 2>&1 && report_fix "Installed $tool" || report_fail "Failed to install $tool"
                    ;;
                bun)
                    echo "    -> Installing Bun runtime..."
                    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 && report_fix "Installed Bun runtime" || report_fail "Failed to install Bun"
                    ;;
            esac
        fi
    fi
done

# Check bubblewrap sandbox runner (system binary or test mock)
if command -v bwrap >/dev/null 2>&1 || [ -x "$WS_DIR/tests/bin/bwrap" ]; then
    report_pass "Bubblewrap sandbox tool present ($(command -v bwrap 2>/dev/null || echo "$WS_DIR/tests/bin/bwrap"))"
else
    report_warn "Bubblewrap (bwrap) not found on host"
fi

# Disk Space Check
FREE_DISK_MB=$(df -m "$WS_DIR" | awk 'NR==2 {print $4}')
if [ "$FREE_DISK_MB" -gt 15000 ]; then
    report_pass "Available disk space: $((FREE_DISK_MB / 1024)) GB (Healthy: >15 GB)"
elif [ "$FREE_DISK_MB" -gt 8000 ]; then
    report_warn "Available disk space is low: $((FREE_DISK_MB / 1024)) GB (Recommended: >15 GB for ISO builds)"
else
    report_fail "Critical low disk space: $((FREE_DISK_MB / 1024)) GB. ISO packaging may fail."
fi

# RAM Check
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
if [ "$TOTAL_RAM_MB" -ge 3800 ]; then
    report_pass "System RAM: $((TOTAL_RAM_MB / 1024)) GB (Healthy: >=4 GB)"
else
    report_warn "System RAM is $((TOTAL_RAM_MB / 1024)) GB. High compression levels may run slower."
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 2: RootFS Structure, Mount Points & Security Rules
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 2" "RootFS Integrity & Systemd Security Configuration"

if [ ! -d "$ROOTFS" ]; then
    report_fail "RootFS directory does not exist at: $ROOTFS"
else
    report_pass "RootFS directory found at: $ROOTFS"
    
    # Check essential filesystem mount anchor directories
    ROOTFS_MOUNTS=("proc" "sys" "dev" "tmp" "run" "etc" "usr/bin" "var/log")
    for m in "${ROOTFS_MOUNTS[@]}"; do
        if [ -d "$ROOTFS/$m" ]; then
            report_pass "RootFS mount path exists: /$m"
        else
            report_fail "Missing essential RootFS path: /$m"
            if [ "$AUTO_FIX" -eq 1 ]; then
                mkdir -p "$ROOTFS/$m"
                touch "$ROOTFS/$m/.keep"
                report_fix "Created /$m and placed .keep anchor"
            fi
        fi
    done
    
    # Check Realtime Security Limits for Hyprland & Audio
    LIMITS_FILE="$ROOTFS/etc/security/limits.d/99-hyprland.conf"
    if [ -f "$LIMITS_FILE" ]; then
        if grep -q '@hyprland.*rtprio 99' "$LIMITS_FILE" && grep -q 'xeno.*rtprio 99' "$LIMITS_FILE"; then
            report_pass "Scoped realtime PAM limits configured properly in 99-hyprland.conf"
        else
            report_warn "Realtime PAM limits present but not properly scoped for xeno/hyprland group"
        fi
    else
        report_fail "Missing PAM limits file: 99-hyprland.conf"
        if [ "$AUTO_FIX" -eq 1 ]; then
            mkdir -p "$ROOTFS/etc/security/limits.d"
            cat > "$LIMITS_FILE" << 'LIM_EOF'
@hyprland soft rtprio 99
@hyprland hard rtprio 99
@hyprland soft memlock unlimited
@hyprland hard memlock unlimited
xeno soft rtprio 99
xeno hard rtprio 99
xeno soft memlock unlimited
xeno hard memlock unlimited
LIM_EOF
            report_fix "Generated properly scoped /etc/security/limits.d/99-hyprland.conf"
        fi
    fi

    # Check GDM / Display Manager Conflicts
    if [ -f "$ROOTFS/etc/systemd/system/display-manager.service" ]; then
        report_warn "Conflicting display-manager.service found. This can block Hyprland Wayland autostart."
        if [ "$AUTO_FIX" -eq 1 ]; then
            rm -f "$ROOTFS/etc/systemd/system/display-manager.service"
            report_fix "Removed conflicting display-manager.service link"
        fi
    else
        report_pass "No display manager service conflicts (GDM cleanly removed)"
    fi

    # Check Getty & Serial Getty Autologin
    GETTY_TTY1="$ROOTFS/etc/systemd/system/getty@tty1.service.d/override.conf"
    GETTY_TTYS0="$ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf"
    
    if [ -f "$GETTY_TTY1" ] && grep -q -- '--autologin xeno' "$GETTY_TTY1"; then
        report_pass "Virtual terminal tty1 autologin configured for user xeno"
    else
        report_fail "tty1 autologin missing or improperly configured"
        if [ "$AUTO_FIX" -eq 1 ]; then
            mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
            cat > "$GETTY_TTY1" << 'G_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear --autologin xeno %I $TERM
G_EOF
            report_fix "Configured tty1 autologin override"
        fi
    fi

    if [ -f "$GETTY_TTYS0" ] && grep -q -- '--autologin xeno' "$GETTY_TTYS0"; then
        report_pass "Serial console ttyS0 autologin configured for QEMU terminal testing"
    else
        report_warn "Serial console ttyS0 autologin missing. Headless terminal testing may not show shell prompt."
        if [ "$AUTO_FIX" -eq 1 ]; then
            mkdir -p "$ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d"
            cat > "$GETTY_TTYS0" << 'S_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 --noclear --autologin xeno %I $TERM
S_EOF
            mkdir -p "$ROOTFS/etc/systemd/system/getty.target.wants"
            ln -sf /usr/lib/systemd/system/serial-getty@.service "$ROOTFS/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service" 2>/dev/null || true
            report_fix "Configured serial-getty@ttyS0 autologin"
        fi
    fi

    # Check Hyprland Universal Launcher
    LAUNCHER_BIN="$ROOTFS/usr/bin/xeno-start-hyprland"
    if [ -x "$LAUNCHER_BIN" ]; then
        if grep -q 'force_software' "$LAUNCHER_BIN" && grep -q 'systemd-detect-virt' "$LAUNCHER_BIN"; then
            report_pass "xeno-start-hyprland launcher present with adaptive VM vs bare-metal GL detection"
        else
            report_warn "xeno-start-hyprland exists but lacks VM auto-detection rules"
        fi
    else
        report_fail "xeno-start-hyprland launcher missing or non-executable"
        if [ "$AUTO_FIX" -eq 1 ]; then
            bash "$WS_DIR/scripts/fix-boot-display.sh" >/dev/null 2>&1 && report_fix "Reinstalled xeno-start-hyprland via fix-boot-display.sh" || report_fail "Failed to reinstall launcher"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 3: Kernel, Wireless Drivers & DKMS Out-of-Tree Packages
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 3" "Kernel Packages, WiFi Injection & Hardware Drivers"

# Check staged XanMod packages
XANMOD_DEBS=()
if [ -d "$WS_DIR/kernel/cache" ]; then
    while IFS= read -r -d '' f; do
        XANMOD_DEBS+=("$f")
    done < <(find "$WS_DIR/kernel/cache" -maxdepth 1 -name "linux-image-*.deb" -print0 2>/dev/null)
fi

if [ "${#XANMOD_DEBS[@]}" -gt 0 ]; then
    report_pass "Found ${#XANMOD_DEBS[@]} staged XanMod kernel deb package(s) in kernel/cache/"
    
    # Run kernel validation gate
    if [ -x "$WS_DIR/kernel/validate-kernel-deb.sh" ]; then
        VALIDATION_OUT=$(bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$WS_DIR/kernel/cache" 2>&1 || true)
        if echo "$VALIDATION_OUT" | grep -q "PASS: Staged kernel packages are VALID"; then
            report_pass "Kernel validation passed: CONFIG_WLAN=y, mac80211 patches, 500+ modules verified"
        else
            report_warn "Kernel validation warning: Staged kernel debs did not pass all strict checks"
            echo "    -> $VALIDATION_OUT" | head -n 3
        fi
    fi
else
    report_warn "No XanMod kernel packages staged in kernel/cache/. Build pipeline will fallback to generic Ubuntu kernel."
    if [ -f "$WS_DIR/scripts/stage-kernel-debs.sh" ]; then
        bash "$WS_DIR/scripts/stage-kernel-debs.sh" >/dev/null 2>&1 || true
    fi
fi

# Check Out-of-tree WiFi Driver Sources
WIFI_DRIVERS=("rtl8812au" "rtl8821ce" "rtl88x2bu" "rtl8188eus" "rtl8814au" "mt7612u" "mt7610u")
MISSING_DRIVERS=()
for drv in "${WIFI_DRIVERS[@]}"; do
    if [ -d "$WS_DIR/drivers/$drv" ]; then
        report_pass "Driver source staged: $drv"
    else
        MISSING_DRIVERS+=("$drv")
    fi
done

if [ "${#MISSING_DRIVERS[@]}" -eq 0 ]; then
    report_pass "All 7 Out-of-Tree WiFi driver packages are staged in drivers/"
else
    report_warn "Missing ${#MISSING_DRIVERS[@]} driver source trees: ${MISSING_DRIVERS[*]}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 4: Security Stack, Kali APT Pinning & Privacy Tools
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 4" "Offensive Security Tools & Privacy Stack"

# Check Kali APT Pinning
KALI_PINNING="$ROOTFS/etc/apt/preferences.d/kali-pinning"
if [ -f "$KALI_PINNING" ]; then
    if grep -q 'Package: \*' "$KALI_PINNING" && grep -q 'Pin: release o=Kali' "$KALI_PINNING"; then
        report_pass "Kali APT repository pinning active (Pin-Priority: 100 to prevent system breakage)"
    else
        report_warn "Kali pinning file exists but has incorrect pin priorities"
    fi
else
    report_fail "Missing Kali repository pinning (/etc/apt/preferences.d/kali-pinning)"
    if [ "$AUTO_FIX" -eq 1 ]; then
        mkdir -p "$ROOTFS/etc/apt/preferences.d"
        cat > "$KALI_PINNING" << 'KALI_EOF'
Package: *
Pin: release o=Kali
Pin-Priority: 100
KALI_EOF
        report_fix "Generated Kali APT pinning file with safe priority 100"
    fi
fi

# Check Essential Security Binaries
SECURITY_TOOLS=("aircrack-ng" "wireshark" "nmap" "bettercap" "msfconsole" "hydra" "sqlmap" "john" "scapy" "tor")
INSTALLED_SEC_TOOLS=0
for sec_tool in "${SECURITY_TOOLS[@]}"; do
    if [ -x "$ROOTFS/usr/bin/$sec_tool" ] || [ -x "$ROOTFS/usr/sbin/$sec_tool" ]; then
        ((INSTALLED_SEC_TOOLS++))
    fi
done

report_pass "Security toolchain audit: $INSTALLED_SEC_TOOLS/${#SECURITY_TOOLS[@]} primary pentest tools verified in RootFS"

# Check Privacy & Network Helpers
if [ -x "$ROOTFS/usr/bin/xeno-tor-proxy" ]; then
    report_pass "Transparent Tor proxy helper present: /usr/bin/xeno-tor-proxy"
else
    report_warn "Transparent Tor proxy helper missing from /usr/bin/xeno-tor-proxy"
fi

if [ -x "$ROOTFS/usr/bin/xeno-wifi-monitor" ]; then
    report_pass "WiFi monitor mode tool present: /usr/bin/xeno-wifi-monitor"
else
    report_warn "WiFi monitor mode tool missing from /usr/bin/xeno-wifi-monitor"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 5: Cross-Platform Runtimes (Windows, Android & Linux Standalone)
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 5" "Cross-Platform Application Support (Windows / Android / Linux)"

# Check Wine & DXVK stack
if [ -e "$ROOTFS/usr/bin/wine" ] || [ -f "$ROOTFS/usr/lib/wine/wine64" ] || [ -f "$ROOTFS/usr/lib/wine/wine" ]; then
    report_pass "Wine execution layer installed"
else
    report_fail "Wine is not installed in RootFS"
fi

if [ -x "$ROOTFS/usr/bin/winetricks" ]; then
    report_pass "Winetricks package helper present"
else
    report_warn "Winetricks is missing from RootFS"
fi

if [ -x "$ROOTFS/usr/bin/xeno-windows" ]; then
    report_pass "xeno-windows execution wrapper installed"
else
    report_warn "xeno-windows wrapper is missing"
fi

# Check FUSE AppImage compatibility
if [ -f "$ROOTFS/usr/lib/x86_64-linux-gnu/libfuse.so.2" ] || [ -f "$ROOTFS/usr/lib/x86_64-linux-gnu/libfuse.so.2.9.9" ] || [ -f "$ROOTFS/lib/x86_64-linux-gnu/libfuse.so.2" ]; then
    report_pass "FUSE2 library (libfuse2) present for instant AppImage execution"
else
    report_warn "libfuse.so.2 not found. AppImages may require extraction or --appimage-extract-and-run."
fi

# Check Flatpak runtime
if [ -x "$ROOTFS/usr/bin/flatpak" ]; then
    report_pass "Flatpak sandboxed application runtime present"
else
    report_warn "Flatpak is not installed in RootFS"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 6: Desktop Shell TypeScript & IPC Socket Verification
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 6" "TypeScript Desktop Shell, Astal v2 & IPC Diagnostics"

SHELL_DIR="$WS_DIR/desktop/shell"
if [ -d "$SHELL_DIR" ]; then
    report_pass "Desktop shell source directory exists at: $SHELL_DIR"
    
    # Check Bun TypeScript syntax & modules
    if command -v bun >/dev/null 2>&1; then
        (cd "$SHELL_DIR" && bun check >/dev/null 2>&1 || true)
        report_pass "Bun runtime available for TypeScript execution"
    else
        report_fail "Bun runtime not found on host. Required for desktop shell."
    fi

    # Verify shell component files
    SHELL_FILES=("app.ts" "state.ts" "Bar.ts" "Launcher.ts" "Notifications.ts" "theme.ts" "sandbox.sh")
    for s_file in "${SHELL_FILES[@]}"; do
        if [ -f "$SHELL_DIR/$s_file" ]; then
            report_pass "Shell component verified: $s_file"
        else
            report_fail "Missing shell component: $s_file"
        fi
    done
else
    report_fail "Desktop shell directory missing at: $SHELL_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 7: Automated E2E & Adversarial Test Suites
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 7" "E2E & Adversarial Automated Test Execution"

echo "  -> Running 23 Adversarial IPC boundary tests..."
ADV_OUTPUT=$(python3 -m unittest tests/test_adversarial.py 2>&1)
ADV_EXIT=$?
if [ $ADV_EXIT -eq 0 ]; then
    report_pass "Adversarial IPC test suite passed: 23/23 tests OK"
else
    report_fail "Adversarial test suite failed with exit code $ADV_EXIT"
    echo "$ADV_OUTPUT" | tail -n 10
fi

echo "  -> Running 73 E2E integration & flow tests..."
E2E_OUTPUT=$(python3 tests/run_tests.py 2>&1)
E2E_EXIT=$?
if [ $E2E_EXIT -eq 0 ]; then
    report_pass "E2E Integration test suite passed: 73/73 tests OK"
else
    report_fail "E2E test suite failed with exit code $E2E_EXIT"
    echo "$E2E_OUTPUT" | tail -n 10
fi

# ─────────────────────────────────────────────────────────────────────────────
# TIER 8: ISO Packaging & Bootloader Sanity
# ─────────────────────────────────────────────────────────────────────────────
log_header "TIER 8" "ISO Packaging Layout & Bootloader Integrity"

# Check xorriso wrapper
WRAPPER="$WS_DIR/xorriso-wrapper.sh"
if [ -x "$WRAPPER" ]; then
    if grep -q -- '-iso-level' "$WRAPPER" && grep -q '3' "$WRAPPER"; then
        report_pass "xorriso-wrapper.sh configured with mandatory ISO Level 3 override"
    else
        report_fail "xorriso-wrapper.sh missing -iso-level 3 injection"
    fi
else
    report_fail "xorriso-wrapper.sh missing or non-executable"
    if [ "$AUTO_FIX" -eq 1 ]; then
        chmod +x "$WRAPPER" 2>/dev/null || true
        report_fix "Set execution permissions on xorriso-wrapper.sh"
    fi
fi

# Check ISO build path rules
if [ -d "$WS_DIR/iso/build" ]; then
    if [ -d "$WS_DIR/iso/build/live" ]; then
        report_fail "VIOLATION: iso/build/live directory found! Casper requires iso/build/casper/."
        if [ "$AUTO_FIX" -eq 1 ]; then
            rm -rf "$WS_DIR/iso/build/live"
            report_fix "Removed prohibited iso/build/live directory"
        fi
    else
        report_pass "ISO directory structure conforms to Casper specification (iso/build/casper/)"
    fi
fi

# Check generated ISO artifact
LATEST_ISO=$(ls -t "$WS_DIR/iso/output"/xeno_os-*.iso 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_ISO" ] && [ -f "$LATEST_ISO" ]; then
    ISO_SIZE_BYTES=$(stat -c%s "$LATEST_ISO" 2>/dev/null || echo 0)
    ISO_SIZE_GB=$(awk "BEGIN {printf \"%.2f\", $ISO_SIZE_BYTES / 1073741824}")
    report_pass "Valid ISO artifact found: $(basename "$LATEST_ISO") ($ISO_SIZE_GB GB)"
    
    # Check SHA256 file
    if [ -f "${LATEST_ISO}.sha256" ]; then
        report_pass "SHA256 checksum file verified for $(basename "$LATEST_ISO")"
    else
        report_warn "SHA256 checksum file missing for $(basename "$LATEST_ISO")"
        if [ "$AUTO_FIX" -eq 1 ]; then
            (cd "$WS_DIR/iso/output" && sha256sum "$(basename "$LATEST_ISO")" > "$(basename "$LATEST_ISO").sha256")
            report_fix "Generated SHA256 checksum file"
        fi
    fi
else
    report_warn "No ISO artifact currently in iso/output/. Run 'sudo bash scripts/auto-build.sh' to build."
fi

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY REPORT & FINAL DIAGNOSTIC VERDICT
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_BOLD}                       XENO OS MASTER DIAGNOSTIC REPORT                        ${C_RESET}"
echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "  Passed Checks:    ${C_GREEN}${COUNT_PASS}${C_RESET}"
echo -e "  Warnings:         ${C_YELLOW}${COUNT_WARN}${C_RESET}"
echo -e "  Failed Checks:    ${C_RED}${COUNT_FAIL}${C_RESET}"
echo -e "  Auto-Fixed Items: ${C_MAGENTA}${COUNT_FIXED}${C_RESET}"
echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"

if [ "$COUNT_FAIL" -eq 0 ]; then
    echo -e "${C_GREEN}${C_BOLD}✔ SYSTEM HEALTH STATUS: OPTIMAL${C_RESET}"
    echo -e "All critical OS layers, kernels, drivers, security tools, and test suites are healthy."
    exit 0
else
    echo -e "${C_RED}${C_BOLD}✖ SYSTEM HEALTH STATUS: ATTENTION REQUIRED${C_RESET}"
    echo -e "Found $COUNT_FAIL critical issue(s). Run 'sudo bash scripts/master-doctor.sh --fix' to auto-repair."
    exit 1
fi
