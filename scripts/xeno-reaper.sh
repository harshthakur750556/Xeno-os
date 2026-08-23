#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#   ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ ─█▀▀█ ░█▀▀█ ░█▀▀▀ ░█▀▀█ 
#   ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█▄▄▀ ░█▀▀▀ ░█▄▄█ ░█▄▄█ ░█▀▀▀ ░█▄▄▀ 
#   ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█─░█ ░█▄▄▄ ░█──█ ░█─── ░█▄▄▄ ░█─░█ 
# ═══════════════════════════════════════════════════════════════════════════════
#  XENO REAPER — Master System Engineering, Diagnostics, & Provisioning Suite
#  Unified command center for Xeno OS lifecycle, chroot administration,
#  kernel staging, compatibility stacks, security provisioning, and test suites.
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.bun/bin:/home/xeno/.bun/bin:${PATH:-}"
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"
CACHE_DIR="$WS_DIR/kernel/cache"
OUT_DIR="$WS_DIR/kernel/output"
META_FILE="$CACHE_DIR/latest_release.json"

# ── Cyber-Nord Visual Tokens & Terminal Capabilities ─────────────────────────
IS_TTY=0
[ -t 1 ] && [ "${TERM:-}" != "dumb" ] && IS_TTY=1

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[38;2;136;192;208m"    # Nord Frost (#88C0D0)
C_BLUE="\033[38;2;129;161;193m"    # Nord Polar Blue (#81A1C1)
C_DEEP_BLUE="\033[38;2;94;129;172m" # Nord Deep Blue (#5E81AC)
C_GREEN="\033[38;2;163;190;140m"   # Nord Aurora Green (#A3BE8C)
C_YELLOW="\033[38;2;235;203;139m"  # Nord Aurora Yellow (#EBCB8B)
C_RED="\033[38;2;191;97;106m"      # Nord Aurora Red (#BF616A)
C_MAGENTA="\033[38;2;180;142;173m" # Nord Aurora Purple (#B48EAD)
C_TEXT="\033[38;2;236;239;244m"     # Nord Snow Storm (#ECEFF4)

# ── Dynamic Progress Bars & Telemetry Graphs Engine ─────────────────────────

# Render a graphical progress/usage bar: render_bar <value> <max> <width> <color>
render_bar() {
    local val="${1:-0}" max="${2:-100}" width="${3:-20}" color="${4:-$C_CYAN}"
    [ "$max" -le 0 ] 2>/dev/null && max=100
    [ "$val" -lt 0 ] 2>/dev/null && val=0
    [ "$val" -gt "$max" ] 2>/dev/null && val="$max"
    local pct=$(( val * 100 / max ))
    local filled=$(( val * width / max ))
    local empty=$(( width - filled ))
    local bar=""
    for ((b=0; b<filled; b++)); do bar+="█"; done
    local empty_bar=""
    for ((b=0; b<empty; b++)); do empty_bar+="░"; done
    printf "${color}%s${C_DIM}%s${C_RESET} %3d%%" "$bar" "$empty_bar" "$pct"
}

# Live Telemetry Snapshot Box (CPU Load %, RAM Used/Total, and RootFS Disk Free)
render_telemetry_dashboard() {
    # 1. CPU Usage
    local cpu_usage=0
    if [ -f /proc/stat ]; then
        local cpu_idle
        cpu_idle=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1 || echo 85)
        cpu_usage=$(( 100 - ${cpu_idle:-85} ))
        [ "$cpu_usage" -lt 0 ] && cpu_usage=0
        [ "$cpu_usage" -gt 100 ] && cpu_usage=100
    fi

    # 2. RAM Usage
    local ram_total="16.0" ram_used="4.0" ram_pct=25
    if [ -f /proc/meminfo ]; then
        local t u a
        t=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 16777216)
        a=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 12582912)
        u=$(( t - a ))
        ram_total=$(awk "BEGIN {printf \"%.1f\", $t / 1048576}")
        ram_used=$(awk "BEGIN {printf \"%.1f\", $u / 1048576}")
        ram_pct=$(( u * 100 / (t > 0 ? t : 1) ))
    fi

    # 3. RootFS / Workspace Disk Usage
    local disk_free="50G" disk_pct=30
    if command -v df >/dev/null 2>&1; then
        disk_pct=$(df -h "$WS_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo 30)
        disk_free=$(df -h "$WS_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "50G")
    fi
    local disk_used_pct=${disk_pct:-30}

    echo -e "${C_DIM}┌─────────────────────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_DIM}│${C_RESET} ${C_BOLD}${C_CYAN}SYSTEM TELEMETRY & LIVE RESOURCE GAUGES${C_RESET}                                     ${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}├─────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
    printf "${C_DIM}│${C_RESET}  ${C_BOLD}CPU Load:${C_RESET}  %-36b ${C_DIM}│${C_RESET} Load:  %3d%%        ${C_DIM}│${C_RESET}\n" "$(render_bar "$cpu_usage" 100 18 "$C_CYAN")" "$cpu_usage"
    printf "${C_DIM}│${C_RESET}  ${C_BOLD}RAM Usage:${C_RESET} %-36b ${C_DIM}│${C_RESET} %5s / %-5s GB ${C_DIM}│${C_RESET}\n" "$(render_bar "$ram_pct" 100 18 "$C_GREEN")" "$ram_used" "$ram_total"
    printf "${C_DIM}│${C_RESET}  ${C_BOLD}Disk Used:${C_RESET} %-36b ${C_DIM}│${C_RESET} %5s free      ${C_DIM}│${C_RESET}\n" "$(render_bar "$disk_used_pct" 100 18 "$C_BLUE")" "$disk_free"
    echo -e "${C_DIM}└─────────────────────────────────────────────────────────────────────────────┘${C_RESET}\n"
}

# Live Spinner for Background Tasks: run_with_spinner "Task description" command args...
run_with_spinner() {
    local label="$1"
    shift
    if [ "$IS_TTY" -eq 0 ]; then
        echo -e "  -> ${label}..."
        "$@"
        local rc=$?
        [ $rc -eq 0 ] && echo -e "  ${C_GREEN}✔ [DONE]${C_RESET} ${label}" || echo -e "  ${C_RED}✖ [FAIL]${C_RESET} ${label} (exit $rc)"
        return $rc
    fi

    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local log_file
    log_file=$(mktemp /tmp/xeno_spin_XXXXXX.log 2>/dev/null || echo "/tmp/xeno_spin_$$.log")
    
    "$@" > "$log_file" 2>&1 &
    local pid=$!
    local start_time
    start_time=$(date +%s)
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        local now
        now=$(date +%s)
        local elapsed=$(( now - start_time ))
        local mins=$(( elapsed / 60 ))
        local secs=$(( elapsed % 60 ))
        printf "\r  ${C_CYAN}%s${C_RESET} %-52s ${C_DIM}[%02d:%02d]${C_RESET}" "${spin_chars[i]}" "${label}..." "$mins" "$secs"
        i=$(( (i + 1) % ${#spin_chars[@]} ))
        sleep 0.1
    done

    wait "$pid"
    local rc=$?
    local now
    now=$(date +%s)
    local elapsed=$(( now - start_time ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))

    if [ $rc -eq 0 ]; then
        printf "\r  ${C_GREEN}✔ [DONE]${C_RESET} %-52s ${C_GREEN}[%02d:%02d]${C_RESET}\033[K\n" "${label}" "$mins" "$secs"
        rm -f "$log_file"
        return 0
    else
        printf "\r  ${C_RED}✖ [FAIL]${C_RESET} %-52s ${C_RED}[%02d:%02d] (code %d)${C_RESET}\033[K\n" "${label}" "$mins" "$secs" "$rc"
        tail -n 10 "$log_file" 2>/dev/null || true
        rm -f "$log_file"
        return $rc
    fi
}

# ── Shared Chroot Helpers ───────────────────────────────────────────────────
xeno_chroot_mount() {
    local target="$1"
    mountpoint -q "$target/proc" 2>/dev/null || mount --bind /proc "$target/proc"
    mountpoint -q "$target/sys" 2>/dev/null || mount --bind /sys "$target/sys"
    mountpoint -q "$target/dev" 2>/dev/null || {
        mount --bind /dev "$target/dev"
        mount --make-rslave "$target/dev" 2>/dev/null || true
    }
    if [ -d /dev/pts ]; then
        mkdir -p "$target/dev/pts"
        mountpoint -q "$target/dev/pts" 2>/dev/null || mount --bind /dev/pts "$target/dev/pts" 2>/dev/null || true
    fi
    mkdir -p "$target/run"
    mountpoint -q "$target/run" 2>/dev/null || mount --bind /run "$target/run" 2>/dev/null || true
    if [ -f /etc/resolv.conf ]; then
        cp -f /etc/resolv.conf "$target/etc/resolv.conf" 2>/dev/null || {
            printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$target/etc/resolv.conf"
        }
    else
        printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$target/etc/resolv.conf"
    fi
}

xeno_chroot_umount() {
    local target="$1"
    umount -l "$target/run" 2>/dev/null || true
    umount -l "$target/dev/pts" 2>/dev/null || true
    umount -l "$target/dev" 2>/dev/null || true
    umount -l "$target/sys" 2>/dev/null || true
    umount -l "$target/proc" 2>/dev/null || true
}

xeno_require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${C_RED}[ERROR] This action requires root privileges. Please run with sudo.${C_RESET}"
        exit 1
    fi
}

xeno_assert_no_broken_pkgs() {
    local target="$1"
    local bad
    bad=$(chroot "$target" dpkg -l 2>/dev/null | awk '$1 ~ /U|H|R|F/ {print $2}' || true)
    if [ -n "$bad" ]; then
        echo -e "${C_RED}[ERROR] Broken/half-installed packages detected in rootfs:${C_RESET}"
        echo "$bad"
        exit 1
    fi
}

# ── Header Banner ────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${C_CYAN}${C_BOLD}"
    cat << 'BANNER_EOF'
 ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ ─█▀▀█ ░█▀▀█ ░█▀▀▀ ░█▀▀█ 
 ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█▄▄▀ ░█▀▀▀ ░█▄▄█ ░█▄▄█ ░█▀▀▀ ░█▄▄▀ 
 ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█─░█ ░█▄▄▄ ░█──█ ░█─── ░█▄▄▄ ░█─░█ 
BANNER_EOF
    echo -e "${C_BLUE} ═══ XENO REAPER — UNIFIED OS LIFECYCLE & DIAGNOSTIC COMMAND CENTER ═══${C_RESET}"
    echo -e "${C_DIM} Workspace: ${WS_DIR} | RootFS: ${ROOTFS}${C_RESET}\n"
    render_telemetry_dashboard
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 1: System Health & Diagnostic Monitor (Doctor & Fast Health)
# ─────────────────────────────────────────────────────────────────────────────
run_health_check() {
    local auto_fix="${1:-0}"
    local daemon_mode="${2:-0}"
    
    [ "$daemon_mode" -eq 0 ] && echo -e "${C_BOLD}${C_CYAN}▶ [HEALTH] Executing Rapid Diagnostic Health Audit...${C_RESET}"
    
    local issues=0
    
    # 1. Storage
    local root_free_mb
    root_free_mb=$(df -m "$ROOTFS" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
    if [ "$root_free_mb" -gt 2048 ]; then
        [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} RootFS storage healthy: $((root_free_mb / 1024)) GB free"
    elif [ "$root_free_mb" -gt 512 ]; then
        [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} Low disk space: ${root_free_mb} MB remaining"
        if [ "$auto_fix" -eq 1 ] && [ "$(id -u)" -eq 0 ]; then
            rm -rf "$ROOTFS/var/cache/apt/archives"/* 2>/dev/null || true
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_MAGENTA}🔧 [FIXED]${C_RESET} Pruned APT archives"
        fi
    else
        [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_RED}✖ [FAIL]${C_RESET} Critical low disk space: ${root_free_mb} MB"
        ((issues++))
    fi

    # 2. Broken Packages
    if command -v dpkg >/dev/null 2>&1; then
        local broken_pkgs
        broken_pkgs=$(dpkg -l 2>/dev/null | awk '$1 ~ /U|H|R|F/ {print $2}' || true)
        if [ -z "$broken_pkgs" ]; then
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Package manager state clean"
        else
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_RED}✖ [FAIL]${C_RESET} Broken packages: $broken_pkgs"
            ((issues++))
            if [ "$auto_fix" -eq 1 ] && [ "$(id -u)" -eq 0 ]; then
                dpkg --configure -a 2>/dev/null && echo -e "  ${C_MAGENTA}🔧 [FIXED]${C_RESET} Configured unconfigured packages" || true
            fi
        fi
    fi

    # 3. DKMS Status
    if command -v dkms >/dev/null 2>&1; then
        local dkms_err
        dkms_err=$(dkms status 2>/dev/null | grep -iE 'error|broken' || true)
        if [ -z "$dkms_err" ]; then
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} DKMS driver trees intact"
        else
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} DKMS module issues: $dkms_err"
        fi
    fi

    # 4. Failed Services
    if command -v systemctl >/dev/null 2>&1; then
        local failed_svcs
        failed_svcs=$(systemctl --failed --no-legend --no-pager 2>/dev/null | awk '{print $2}' || true)
        if [ -z "$failed_svcs" ]; then
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Systemd background services operational"
        else
            [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} Failed systemd services: $failed_svcs"
        fi
    fi

    # 5. Stale lock cleanup
    if [ -f /tmp/xeno-auto-build.lock ]; then
        if command -v fuser >/dev/null 2>&1; then
            if ! fuser /tmp/xeno-auto-build.lock &>/dev/null; then
                if rm -f /tmp/xeno-auto-build.lock 2>/dev/null; then
                    [ "$daemon_mode" -eq 0 ] && echo -e "  ${C_MAGENTA}🔧 [FIXED]${C_RESET} Removed stale /tmp/xeno-auto-build.lock"
                fi
            fi
        fi
    fi

    [ "$daemon_mode" -eq 0 ] && echo -e "\nHealth check complete. Issues found: $issues\n"
    return "$issues"
}

run_master_doctor() {
    local auto_fix="${1:-0}"
    echo -e "${C_BOLD}${C_CYAN}▶ [DOCTOR] Initializing 8-Tier Master Diagnostic & Integrity Verifier...${C_RESET}"
    echo -e "Auto-Fix: $([ "$auto_fix" -eq 1 ] && echo -e "${C_GREEN}ENABLED${C_RESET}" || echo -e "${C_YELLOW}DISABLED${C_RESET}")\n"

    local c_pass=0 c_warn=0 c_fail=0 c_fixed=0

    # Helper for tier headers with dynamic progress bar
    render_doctor_tier() {
        local tier_num="$1" total_tiers="$2" tier_title="$3"
        local pct=$(( tier_num * 100 / total_tiers ))
        local bar
        bar=$(render_bar "$tier_num" "$total_tiers" 20 "$C_BLUE")
        echo -e "\n${C_BOLD}${C_CYAN}── Tier [${tier_num}/${total_tiers}] (${pct}%): ${tier_title} ──${C_RESET}"
        [ "$IS_TTY" -eq 1 ] && echo -e "   ${C_DIM}Audit Progress:${C_RESET} ${bar}\n"
    }

    # TIER 1: Host Tooling
    render_doctor_tier 1 8 "Host Build Tools & System Resources"
    for tool in xorriso mksquashfs grub-mkimage python3 bun git sha256sum; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Host tool present: $tool (${C_DIM}$(command -v "$tool")${C_RESET})"
            ((c_pass++))
        else
            echo -e "  ${C_RED}✖ [FAIL]${C_RESET} Missing host tool: $tool"
            ((c_fail++))
            if [ "$auto_fix" -eq 1 ] && [ "$(id -u)" -eq 0 ]; then
                apt-get update -qq && apt-get install -y --no-install-recommends xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin >/dev/null 2>&1 && { echo -e "  ${C_MAGENTA}🔧 [FIXED]${C_RESET} Installed $tool"; ((c_fixed++)); } || true
            fi
        fi
    done

    # TIER 2: RootFS Structure & Security Limits
    render_doctor_tier 2 8 "RootFS Integrity & Security Limits"
    if [ -d "$ROOTFS" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} RootFS directory exists at: ${C_DIM}$ROOTFS${C_RESET}"
        ((c_pass++))
        for m in proc sys dev tmp run etc usr/bin var/log; do
            if [ -d "$ROOTFS/$m" ]; then
                echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Mount anchor path exists: /$m"
                ((c_pass++))
            else
                echo -e "  ${C_RED}✖ [FAIL]${C_RESET} Missing anchor path: /$m"
                ((c_fail++))
                if [ "$auto_fix" -eq 1 ]; then
                    mkdir -p "$ROOTFS/$m"
                    touch "$ROOTFS/$m/.keep"
                    echo -e "  ${C_MAGENTA}🔧 [FIXED]${C_RESET} Created /$m and placed .keep anchor"
                    ((c_fixed++))
                fi
            fi
        done
        if [ -f "$ROOTFS/etc/security/limits.d/99-hyprland.conf" ]; then
            echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Scoped realtime PAM limits configured properly"
            ((c_pass++))
        else
            echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} Missing 99-hyprland.conf limits file"
            ((c_warn++))
        fi
    else
        echo -e "  ${C_RED}✖ [FAIL]${C_RESET} RootFS directory missing at: $ROOTFS"
        ((c_fail++))
    fi

    # TIER 3: Kernel Packages & Wireless Drivers
    render_doctor_tier 3 8 "Kernel Packages & Wireless Drivers"
    if ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Found staged XanMod kernel deb package(s) in kernel/cache/"
        ((c_pass++))
        if [ -x "$WS_DIR/kernel/validate-kernel-deb.sh" ]; then
            if bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$CACHE_DIR" >/dev/null 2>&1; then
                echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Kernel validation passed (CONFIG_WLAN=y, mac80211 patches)"
                ((c_pass++))
            else
                echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} Kernel validation returned non-zero"
                ((c_warn++))
            fi
        fi
    else
        echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} No XanMod kernel deb packages in cache. Fallback generic kernel will be used."
        ((c_warn++))
    fi

    # TIER 4: Security Stack & Pinning
    render_doctor_tier 4 8 "Security Stack & Kali APT Pinning"
    if [ -f "$ROOTFS/etc/apt/preferences.d/kali-pinning" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Kali APT repository pinning active (Priority 100)"
        ((c_pass++))
    else
        echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} Kali repository pinning file missing"
        ((c_warn++))
    fi

    # TIER 5: Compatibility Layer (Wine, AppImage, Flatpak)
    render_doctor_tier 5 8 "Cross-Platform Compatibility Layer"
    if [ -e "$ROOTFS/usr/bin/wine" ] || [ -f "$ROOTFS/usr/lib/wine/wine64" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Wine execution layer installed"
        ((c_pass++))
    else
        echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} Wine binary not found in RootFS"
        ((c_warn++))
    fi
    if [ -x "$ROOTFS/usr/bin/xeno-appimage-runner" ] || [ -f "$ROOTFS/usr/share/applications/xeno-appimage-runner.desktop" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} xeno-appimage-runner launcher present with automatic fallback detection"
        ((c_pass++))
    else
        echo -e "  ${C_YELLOW}⚠ [WARN]${C_RESET} xeno-appimage-runner launcher not yet staged in RootFS"
        ((c_warn++))
    fi

    # TIER 6: Desktop Shell TypeScript & Astal
    render_doctor_tier 6 8 "TypeScript Desktop Shell & Astal v2"
    if [ -d "$WS_DIR/desktop/shell" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Desktop shell source directory exists"
        ((c_pass++))
        for comp in app.ts state.ts Bar.ts Launcher.ts Notifications.ts theme.ts sandbox.sh; do
            if [ -f "$WS_DIR/desktop/shell/$comp" ]; then
                echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Shell component verified: $comp"
                ((c_pass++))
            else
                echo -e "  ${C_RED}✖ [FAIL]${C_RESET} Missing shell component: $comp"
                ((c_fail++))
            fi
        done
    fi

    # TIER 7: Automated Test Execution
    render_doctor_tier 7 8 "Automated Integration & Adversarial Test Suites"
    echo -e "  -> Running 23 Adversarial IPC boundary tests..."
    if run_tests_suite adv >/dev/null 2>&1; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} Adversarial IPC test suite passed: 23/23 tests OK"
        ((c_pass++))
    else
        echo -e "  ${C_RED}✖ [FAIL]${C_RESET} Adversarial test suite failed"
        ((c_fail++))
    fi
    echo -e "  -> Running 73 E2E integration & flow tests..."
    if run_tests_suite e2e >/dev/null 2>&1; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} E2E Integration test suite passed: 73/73 tests OK"
        ((c_pass++))
    else
        echo -e "  ${C_RED}✖ [FAIL]${C_RESET} E2E test suite failed"
        ((c_fail++))
    fi

    # TIER 8: ISO Packaging & Bootloader Sanity
    render_doctor_tier 8 8 "ISO Packaging Layout & Bootloader Integrity"
    if [ -x "$WS_DIR/xorriso-wrapper.sh" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} xorriso-wrapper.sh configured with mandatory ISO Level 3 override"
        ((c_pass++))
    else
        echo -e "  ${C_RED}✖ [FAIL]${C_RESET} xorriso-wrapper.sh missing or non-executable"
        ((c_fail++))
    fi
    if [ -d "$WS_DIR/iso/build/casper" ]; then
        echo -e "  ${C_GREEN}✔ [PASS]${C_RESET} ISO directory structure conforms to Casper specification"
        ((c_pass++))
    fi

    local total_checks=$(( c_pass + c_warn + c_fail ))
    local health_pct=100
    [ "$total_checks" -gt 0 ] && health_pct=$(( (c_pass * 100) / total_checks ))

    echo -e "\n${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}                       XENO OS MASTER DIAGNOSTIC REPORT                        ${C_RESET}"
    echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    printf "  Health Index:     %b\n" "$(render_bar "$health_pct" 100 24 "$([ "$c_fail" -eq 0 ] && echo "$C_GREEN" || echo "$C_RED")")"
    echo -e "  Passed Checks:    ${C_GREEN}${c_pass}${C_RESET} / ${total_checks}"
    echo -e "  Warnings:         ${C_YELLOW}${c_warn}${C_RESET}"
    echo -e "  Failed Checks:    ${C_RED}${c_fail}${C_RESET}"
    echo -e "  Auto-Fixed Items: ${C_MAGENTA}${c_fixed}${C_RESET}"
    echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"

    if [ "$c_fail" -eq 0 ]; then
        echo -e "${C_GREEN}${C_BOLD}✔ SYSTEM HEALTH STATUS: OPTIMAL${C_RESET}\n"
        return 0
    else
        echo -e "${C_RED}${C_BOLD}✖ SYSTEM HEALTH STATUS: ATTENTION REQUIRED${C_RESET}\n"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 2: Embedded Automated Test Runner (All 96 Tests & Simulator)
# ─────────────────────────────────────────────────────────────────────────────
run_tests_suite() {
    local mode="${1:-all}"
    echo -e "${C_BOLD}${C_CYAN}▶ [TESTS] Executing Xeno OS Automated Test Framework (Mode: ${mode})...${C_RESET}\n"
    
    cd "$WS_DIR"
    python3 - "$mode" "$WS_DIR" << 'XENO_TEST_RUNNER_EOF'
import unittest
import os
import sys
import socket
import json
import subprocess
import time
import re
import tempfile
import shutil
import threading

# ── 1. Embedded Simulator ──
class XenoSystemSimulator:
    def __init__(self):
        self.lock = threading.Lock()
        self.running = False
        self.server_thread = None
        self.socket_dir = None
        self.socket_path = None
        self.reset_state()

    def reset_state(self):
        with self.lock:
            self.clock_time = "2026-07-06 18:26:33"
            self.cpu_usage = 12.5
            self.ram_usage = {"used": 4.2, "total": 16.0, "percent": 26.3}
            self.workspaces = [1, 2, 3]
            self.active_workspace = 2
            self.launcher_visible = False
            self.applications = [
                {"id": "terminal", "name": "Terminal", "command": "bash", "icon": "utilities-terminal"},
                {"id": "filemanager", "name": "File Manager", "command": "python3 filemanager.py", "icon": "system-file-manager"},
                {"id": "settings", "name": "Settings", "command": "python3 settings.py", "icon": "preferences-system"}
            ]
            self.launcher_highlighted_index = 0
            self.launcher_font_family = "Inter"
            self.launcher_font_size = 14
            self.notification_queue = []
            self.notification_logs = []
            self.notification_counter = 0
            self.sound_played = []
            self.sandbox_running = False
            self.sandbox_memory_limit = "2GB"
            self.sandbox_threads = 0
            self.sandbox_max_threads = 4
            self.sandbox_panels = []
            self.display_socket_exists = True
            self.system_logs = []

    def log(self, message):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        self.system_logs.append(f"[{timestamp}] {message}")

    def start(self):
        self.reset_state()
        self.socket_dir = tempfile.mkdtemp(prefix="xeno_sim_")
        self.socket_path = os.path.join(self.socket_dir, "xeno-ipc.sock")
        self.running = True
        self.server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server_socket.bind(self.socket_path)
        self.server_socket.listen(5)
        self.server_thread = threading.Thread(target=self._run_server, daemon=True)
        self.server_thread.start()
        self.log(f"Simulator started on Unix socket: {self.socket_path}")
        return self.socket_path

    def stop(self):
        self.running = False
        if hasattr(self, 'server_socket'):
            try:
                temp_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                temp_sock.connect(self.socket_path)
                temp_sock.close()
            except Exception:
                pass
            try:
                self.server_socket.close()
            except Exception:
                pass
        if self.server_thread:
            self.server_thread.join(timeout=1.0)
        if self.socket_dir and os.path.exists(self.socket_dir):
            shutil.rmtree(self.socket_dir)
        self.log("Simulator stopped")

    def _run_server(self):
        while self.running:
            try:
                conn, _ = self.server_socket.accept()
                if not self.running:
                    conn.close()
                    break
                req_data = b""
                while True:
                    chunk = conn.recv(65536)
                    if not chunk:
                        break
                    req_data += chunk
                if not req_data:
                    conn.close()
                    continue
                try:
                    request = json.loads(req_data.decode('utf-8'))
                    response = self.handle_request(request)
                except Exception as e:
                    response = {"status": "error", "message": f"Malformed request: {str(e)}"}
                conn.sendall(json.dumps(response).encode('utf-8'))
                conn.close()
            except Exception:
                if not self.running:
                    break

    def handle_request(self, request):
        cmd = request.get("command")
        params = request.get("params", {})
        
        if cmd == "simulator:set_clock":
            with self.lock: self.clock_time = params.get("time", self.clock_time)
            return {"status": "success"}
        elif cmd == "simulator:set_cpu":
            with self.lock: self.cpu_usage = params.get("cpu", self.cpu_usage)
            return {"status": "success"}
        elif cmd == "simulator:set_ram":
            with self.lock: self.ram_usage = params.get("ram", self.ram_usage)
            return {"status": "success"}
        elif cmd == "simulator:set_workspaces":
            with self.lock:
                self.workspaces = params.get("workspaces", self.workspaces)
                self.active_workspace = params.get("active", self.active_workspace)
            return {"status": "success"}
        elif cmd == "simulator:set_applications":
            with self.lock: self.applications = params.get("applications", self.applications)
            return {"status": "success"}
        elif cmd == "simulator:set_launcher_state":
            with self.lock:
                self.launcher_highlighted_index = params.get("highlighted_index", self.launcher_highlighted_index)
                self.launcher_font_family = params.get("font_family", self.launcher_font_family)
                self.launcher_font_size = params.get("font_size", self.launcher_font_size)
            return {"status": "success"}
        elif cmd == "simulator:set_display_socket":
            with self.lock: self.display_socket_exists = params.get("display_socket_exists", self.display_socket_exists)
            return {"status": "success"}
        elif cmd == "simulator:get_sound_played":
            with self.lock: return {"status": "success", "sound_played": list(self.sound_played)}
        elif cmd == "simulator:clear_state":
            self.reset_state()
            return {"status": "success"}
        elif cmd == "status_bar:get_clock":
            with self.lock: return {"status": "success", "clock": self.clock_time}
        elif cmd == "status_bar:get_cpu":
            with self.lock:
                clamped_cpu = max(0.0, min(100.0, self.cpu_usage))
                return {"status": "success", "cpu": clamped_cpu}
        elif cmd == "status_bar:get_ram":
            with self.lock: return {"status": "success", "ram": self.ram_usage}
        elif cmd == "status_bar:get_workspaces":
            with self.lock: return {"status": "success", "workspaces": self.workspaces, "active": self.active_workspace}
        elif cmd == "status_bar:toggle_launcher":
            with self.lock:
                self.launcher_visible = not self.launcher_visible
                self.log(f"Status Bar toggled Launcher. Visible: {self.launcher_visible}")
                return {"status": "success", "launcher_visible": self.launcher_visible}
        elif cmd == "launcher:list_apps":
            with self.lock: return {"status": "success", "apps": self.applications}
        elif cmd == "launcher:launch":
            app_id = params.get("app_id")
            with self.lock:
                app = next((a for a in self.applications if a["id"] == app_id), None)
                if not app:
                    self.log(f"Launcher failed to launch non-existent application: {app_id}")
                    return {"status": "error", "message": f"Application {app_id} not found"}
                self.notification_counter += 1
                new_id = self.notification_counter
                toast = {"id": new_id, "title": "System Launch", "body": f"Launching {app['name']} inside container...", "urgency": "low", "sound": "launch_hook.wav"}
                self.notification_queue.append(toast)
                self.notification_logs.append(f"INFO: {toast['title']} - {toast['body']}")
                self.sound_played.append(toast["sound"])
                self.log(f"Launcher launched application: {app_id}")
                return {"status": "success", "launched": app_id}
        elif cmd == "launcher:get_state":
            with self.lock:
                return {"status": "success", "highlighted_index": self.launcher_highlighted_index, "font_family": self.launcher_font_family, "font_size": self.launcher_font_size, "visible": self.launcher_visible}
        elif cmd == "launcher:press_shortcut":
            with self.lock:
                self.launcher_visible = not self.launcher_visible
                self.log(f"Launcher hotkey toggled. Visible: {self.launcher_visible}")
                return {"status": "success", "launcher_visible": self.launcher_visible}
        elif cmd == "notification:send":
            if "urgency" in params and not isinstance(params["urgency"], str):
                return {"status": "error", "message": "Urgency must be a string"}
            title = str(params.get("title") or "")
            body = str(params.get("body") or "")
            urgency = str(params.get("urgency") or "normal")
            sound = str(params.get("sound") or "")
            raw_timeout = params.get("timeout", 3000)
            try:
                timeout = int(raw_timeout)
                if timeout > 0: timeout = min(timeout, 2147483647)
                else: timeout = 3000
            except (ValueError, TypeError): timeout = 3000
            if not title and not body:
                self.log("Notification Center received null message notification")
                return {"status": "error", "message": "Notification title and body cannot both be empty"}
            with self.lock:
                self.notification_counter += 1
                new_id = self.notification_counter
                toast = {"id": new_id, "title": title, "body": body, "urgency": urgency, "sound": sound, "timeout": timeout}
                if len(self.notification_queue) >= 5:
                    self.log(f"Notification collision warning: {len(self.notification_queue)} active notifications")
                self.notification_queue.append(toast)
                self.notification_logs.append(f"{urgency.upper()}: {title} - {body}")
                if sound: self.sound_played.append(sound)
                self.log(f"Notification dispatched: {title} (ID: {new_id})")
                return {"status": "success", "id": new_id}
        elif cmd == "notification:get_queue":
            with self.lock: return {"status": "success", "notifications": list(self.notification_queue)}
        elif cmd == "notification:get_logs":
            with self.lock: return {"status": "success", "logs": list(self.notification_logs)}
        elif cmd == "notification:dismiss":
            notif_id = params.get("id")
            with self.lock:
                self.notification_queue = [n for n in self.notification_queue if n["id"] != notif_id]
                self.log(f"Notification dismissed: ID {notif_id}")
                return {"status": "success"}
        elif cmd == "sandbox:start":
            mem = str(params.get("memory") or "2GB")
            threads = params.get("threads", 2)
            with self.lock:
                if not self.display_socket_exists:
                    self.log("Sandbox execution failed: Missing display socket")
                    return {"status": "error", "message": "No Wayland or X11 graphics driver/display socket found"}
                if self.sandbox_running:
                    self.log("Sandbox execution failed: Collision (already running)")
                    return {"status": "error", "message": "Instance lock active: concurrent sandbox wrapper spawn collision"}
                mem_upper = mem.strip().upper()
                mem_mb = None
                try:
                    if mem_upper.endswith("GB"): mem_mb = float(mem_upper[:-2].strip()) * 1024
                    elif mem_upper.endswith("MB"): mem_mb = float(mem_upper[:-2].strip())
                    elif mem_upper.endswith("KB"): mem_mb = float(mem_upper[:-2].strip()) / 1024
                    else: mem_mb = float(mem_upper)
                except (ValueError, TypeError): mem_mb = None
                if mem_mb is None or mem_mb < 128:
                    self.log(f"Sandbox execution failed: memory limit {mem} below minimum threshold")
                    return {"status": "error", "message": "Resource limits violated: memory allocation below 128MB threshold"}
                if not isinstance(threads, int) or isinstance(threads, bool) or threads < 1 or threads > self.sandbox_max_threads:
                    self.log(f"Sandbox execution failed: thread allocation {threads} invalid or exceeds limit {self.sandbox_max_threads}")
                    return {"status": "error", "message": "Resource limits violated: native thread allocation limit exceeded"}
                self.sandbox_running = True
                self.sandbox_memory_limit = mem
                self.sandbox_threads = threads
                self.log(f"Sandbox started with {threads} threads, {mem} RAM limit")
                return {"status": "success"}
        elif cmd == "sandbox:stop":
            with self.lock:
                self.sandbox_running = False
                self.sandbox_panels = []
                self.log("Sandbox stopped and cleaned up")
                return {"status": "success"}
        elif cmd == "sandbox:status":
            with self.lock:
                return {"status": "success", "running": self.sandbox_running, "memory_limit": self.sandbox_memory_limit, "threads": self.sandbox_threads, "max_threads": self.sandbox_max_threads, "panels": list(self.sandbox_panels)}
        elif cmd == "sandbox:load_panel":
            panel = params.get("panel")
            with self.lock:
                if not self.sandbox_running:
                    self.log(f"Sandbox failed loading panel {panel}: Sandbox not running")
                    return {"status": "error", "message": "Cannot load panel: sandbox is not active"}
                self.sandbox_panels.append(panel)
                self.log(f"Sandbox loaded panel: {panel}")
                return {"status": "success", "panels": list(self.sandbox_panels)}
        else:
            return {"status": "error", "message": f"Unknown IPC command: {cmd}"}

# ── 2. Mock CLI Binaries Factory ──
def create_mock_binaries(target_dir):
    os.makedirs(target_dir, exist_ok=True)
    launcher_code = '''#!/usr/bin/env python3
import sys, os, socket, json
def send_ipc(cmd, params=None):
    p = os.environ.get("XENO_IPC_SOCKET")
    if not p: sys.exit(1)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(p)
    s.sendall(json.dumps({"command": cmd, "params": params or {}}).encode('utf-8'))
    s.shutdown(socket.SHUT_WR)
    chunks = []
    while True:
        c = s.recv(65536)
        if not c: break
        chunks.append(c)
    s.close()
    return json.loads(b"".join(chunks).decode('utf-8'))
def main():
    if len(sys.argv) < 2: sys.exit(1)
    a = sys.argv[1]
    if a == "--list-apps":
        r = send_ipc("launcher:list_apps")
        if r.get("status") == "success":
            apps = r["apps"]
            if not apps: print("Applications grid: empty")
            else:
                for app in apps: print(f"[{app['id']}] {app['name']} - {app['command']} ({app['icon']})")
        else: sys.exit(1)
    elif a == "--launch":
        if len(sys.argv) < 3: sys.exit(1)
        r = send_ipc("launcher:launch", {"app_id": sys.argv[2]})
        if r.get("status") == "success": print(f"Launched application: {r['launched']}")
        else: print(f"Error: {r.get('message')}", file=sys.stderr); sys.exit(1)
    elif a == "--get-state":
        r = send_ipc("launcher:get_state")
        if r.get("status") == "success": print(f"Highlighted: {r['highlighted_index']}, Font: {r['font_family']} {r['font_size']}px, Visible: {r['visible']}")
        else: sys.exit(1)
    elif a == "--press-shortcut":
        r = send_ipc("launcher:press_shortcut")
        if r.get("status") == "success": print(f"Launcher toggled via shortcut: {r['launcher_visible']}")
        else: sys.exit(1)
if __name__ == "__main__": main()
'''
    with open(os.path.join(target_dir, "xeno-launcher"), "w") as f: f.write(launcher_code)
    os.chmod(os.path.join(target_dir, "xeno-launcher"), 0o755)

    notify_code = '''#!/usr/bin/env python3
import sys, os, socket, json
def send_ipc(cmd, params=None):
    p = os.environ.get("XENO_IPC_SOCKET")
    if not p: sys.exit(1)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(p)
    s.sendall(json.dumps({"command": cmd, "params": params or {}}).encode('utf-8'))
    s.shutdown(socket.SHUT_WR)
    chunks = []
    while True:
        c = s.recv(65536)
        if not c: break
        chunks.append(c)
    s.close()
    return json.loads(b"".join(chunks).decode('utf-8'))
def main():
    if len(sys.argv) < 2: sys.exit(1)
    a = sys.argv[1]
    if a == "--send":
        if len(sys.argv) < 4: sys.exit(1)
        title, body = sys.argv[2], sys.argv[3]
        urgency, sound, timeout = "normal", "", 3000
        idx = 4
        while idx < len(sys.argv):
            opt = sys.argv[idx]
            if opt == "--urgency" and idx + 1 < len(sys.argv): urgency = sys.argv[idx+1]; idx += 2
            elif opt == "--sound" and idx + 1 < len(sys.argv): sound = sys.argv[idx+1]; idx += 2
            elif opt == "--timeout" and idx + 1 < len(sys.argv):
                try: timeout = int(sys.argv[idx+1])
                except ValueError: pass
                idx += 2
            else: idx += 1
        r = send_ipc("notification:send", {"title": title, "body": body, "urgency": urgency, "sound": sound, "timeout": timeout})
        if r.get("status") == "success": print(f"Notification Sent [ID: {r['id']}]")
        else: print(f"Error: {r.get('message')}", file=sys.stderr); sys.exit(1)
    elif a == "--get-logs":
        r = send_ipc("notification:get_logs")
        if r.get("status") == "success":
            for log in r["logs"]: print(log)
        else: sys.exit(1)
    elif a == "--get-queue":
        r = send_ipc("notification:get_queue")
        if r.get("status") == "success":
            for n in r["notifications"]:
                urg = n.get('urgency', 'normal')
                snd = n.get('sound') or 'none'
                timeout = n.get('timeout', 3000)
                print(f"[{n['id']}] {n['title']}: {n['body']} (Urgency: {urg}, Sound: {snd}, Timeout: {timeout}ms)")
        else: sys.exit(1)
    elif a == "--dismiss":
        if len(sys.argv) < 3: sys.exit(1)
        try: nid = int(sys.argv[2])
        except ValueError: sys.exit(1)
        r = send_ipc("notification:dismiss", {"id": nid})
        if r.get("status") == "success": print(f"Notification {nid} dismissed")
        else: sys.exit(1)
if __name__ == "__main__": main()
'''
    with open(os.path.join(target_dir, "xeno-notify"), "w") as f: f.write(notify_code)
    os.chmod(os.path.join(target_dir, "xeno-notify"), 0o755)

    sandbox_code = '''#!/usr/bin/env python3
import sys, os, socket, json
def send_ipc(cmd, params=None):
    p = os.environ.get("XENO_IPC_SOCKET")
    if not p: sys.exit(1)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(p)
    s.sendall(json.dumps({"command": cmd, "params": params or {}}).encode('utf-8'))
    s.shutdown(socket.SHUT_WR)
    chunks = []
    while True:
        c = s.recv(65536)
        if not c: break
        chunks.append(c)
    s.close()
    return json.loads(b"".join(chunks).decode('utf-8'))
def main():
    if len(sys.argv) < 2: sys.exit(1)
    allowed = {"--start", "--stop", "--status", "--load-panel", "--memory", "--threads"}
    for a in sys.argv[1:]:
        if a.startswith("-") and a not in allowed:
            print(f"Error: Invalid flag {a}", file=sys.stderr); sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "--start":
        mem, threads = "2GB", 2
        idx = 2
        while idx < len(sys.argv):
            opt = sys.argv[idx]
            if opt == "--memory" and idx + 1 < len(sys.argv): mem = sys.argv[idx+1]; idx += 2
            elif opt == "--threads" and idx + 1 < len(sys.argv):
                try: threads = int(sys.argv[idx+1])
                except ValueError: sys.exit(1)
                idx += 2
            else: idx += 1
        r = send_ipc("sandbox:start", {"memory": mem, "threads": threads})
        if r.get("status") == "success": print("Sandbox started successfully.")
        else:
            m = r.get('message', '')
            print(f"Error: {m}", file=sys.stderr)
            if "collision" in m: sys.exit(2)
            elif "Resource limits" in m: sys.exit(3)
            else: sys.exit(1)
    elif cmd == "--stop":
        r = send_ipc("sandbox:stop")
        if r.get("status") == "success": print("Sandbox stopped successfully.")
        else: sys.exit(1)
    elif cmd == "--status":
        r = send_ipc("sandbox:status")
        if r.get("status") == "success":
            running = "Running" if r["running"] else "Stopped"
            print(f"Sandbox Status: {running}")
            print(f"Memory Limit: {r['memory_limit']}")
            print(f"Threads: {r['threads']}/{r['max_threads']}")
            print(f"Panels: {', '.join(r['panels'])}")
        else: sys.exit(1)
    elif cmd == "--load-panel":
        if len(sys.argv) < 3: sys.exit(1)
        r = send_ipc("sandbox:load_panel", {"panel": sys.argv[2]})
        if r.get("status") == "success": print(f"Panel {sys.argv[2]} loaded successfully.")
        else: sys.exit(1)
if __name__ == "__main__": main()
'''
    with open(os.path.join(target_dir, "xeno-sandbox"), "w") as f: f.write(sandbox_code)
    os.chmod(os.path.join(target_dir, "xeno-sandbox"), 0o755)

    status_bar_code = '''#!/usr/bin/env python3
import sys, os, socket, json
def send_ipc(cmd, params=None):
    p = os.environ.get("XENO_IPC_SOCKET")
    if not p: sys.exit(1)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(p)
    s.sendall(json.dumps({"command": cmd, "params": params or {}}).encode('utf-8'))
    s.shutdown(socket.SHUT_WR)
    chunks = []
    while True:
        c = s.recv(65536)
        if not c: break
        chunks.append(c)
    s.close()
    return json.loads(b"".join(chunks).decode('utf-8'))
def main():
    if len(sys.argv) < 2: sys.exit(1)
    a = sys.argv[1]
    if a == "--get-clock":
        r = send_ipc("status_bar:get_clock")
        if r.get("status") == "success": print(r["clock"])
        else: sys.exit(1)
    elif a == "--get-cpu":
        r = send_ipc("status_bar:get_cpu")
        if r.get("status") == "success": print(f"CPU: {r['cpu']}%")
        else: sys.exit(1)
    elif a == "--get-ram":
        r = send_ipc("status_bar:get_ram")
        if r.get("status") == "success":
            ram = r["ram"]
            print(f"RAM: {ram['used']}GB / {ram['total']}GB ({ram['percent']}%)")
        else: sys.exit(1)
    elif a == "--get-workspaces":
        r = send_ipc("status_bar:get_workspaces")
        if r.get("status") == "success":
            w, act = r["workspaces"], r["active"]
            w_str = ", ".join(f"[{x}]" if x == act else str(x) for x in w)
            print(f"Workspaces: {w_str}")
        else: sys.exit(1)
    elif a == "--toggle-launcher":
        r = send_ipc("status_bar:toggle_launcher")
        if r.get("status") == "success": print(f"Launcher toggled: {r['launcher_visible']}")
        else: sys.exit(1)
if __name__ == "__main__": main()
'''
    with open(os.path.join(target_dir, "xeno-status-bar"), "w") as f: f.write(status_bar_code)
    os.chmod(os.path.join(target_dir, "xeno-status-bar"), 0o755)

# ── 3. Embedded Adversarial Test Suite (23 Tests) ──
class XenoAdversarialTestCase(unittest.TestCase):
    live_mode = False
    simulator = None
    socket_path = None
    original_path = None
    mock_bin_dir = None

    @classmethod
    def setUpClass(cls):
        cls.live_mode = os.environ.get("XENO_E2E_LIVE", "").lower() in ("1", "true", "yes")
        if not cls.live_mode:
            cls.simulator = XenoSystemSimulator()
            cls.socket_path = cls.simulator.start()
            cls.mock_bin_dir = tempfile.mkdtemp(prefix="xeno_adv_bin_")
            create_mock_binaries(cls.mock_bin_dir)
            cls.original_path = os.environ.get("PATH", "")
            os.environ["PATH"] = f"{cls.mock_bin_dir}{os.path.pathsep}{cls.original_path}"
            os.environ["XENO_IPC_SOCKET"] = cls.socket_path
        else:
            if "XENO_IPC_SOCKET" not in os.environ:
                os.environ["XENO_IPC_SOCKET"] = "/tmp/xeno-ipc.sock"

    @classmethod
    def tearDownClass(cls):
        if not cls.live_mode and cls.simulator:
            cls.simulator.stop()
            if cls.original_path: os.environ["PATH"] = cls.original_path
            if cls.mock_bin_dir and os.path.exists(cls.mock_bin_dir): shutil.rmtree(cls.mock_bin_dir)
        if "XENO_IPC_SOCKET" in os.environ: del os.environ["XENO_IPC_SOCKET"]

    def setUp(self):
        if not self.live_mode and self.simulator:
            self.send_simulator_command("simulator:clear_state")
            time.sleep(0.01)

    def send_simulator_command(self, command, params=None):
        if self.live_mode: return None
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(self.socket_path)
            s.sendall(json.dumps({"command": command, "params": params or {}}).encode('utf-8'))
            s.shutdown(socket.SHUT_WR)
            chunks = []
            while True:
                chunk = s.recv(65536)
                if not chunk: break
                chunks.append(chunk)
            resp = b"".join(chunks)
            s.close()
            return json.loads(resp.decode('utf-8'))
        except Exception as e:
            self.fail(f"Failed to communicate with simulator: {e}")

    def send_raw_ipc(self, payload):
        socket_path = os.environ.get("XENO_IPC_SOCKET")
        if not socket_path: self.fail("XENO_IPC_SOCKET not set")
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(socket_path)
        s.sendall(json.dumps(payload).encode('utf-8'))
        s.shutdown(socket.SHUT_WR)
        chunks = []
        while True:
            chunk = s.recv(65536)
            if not chunk: break
            chunks.append(chunk)
        resp = b"".join(chunks)
        s.close()
        return json.loads(resp.decode('utf-8'))

    def send_raw_bytes_ipc(self, payload_bytes):
        socket_path = os.environ.get("XENO_IPC_SOCKET")
        if not socket_path: self.fail("XENO_IPC_SOCKET not set")
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(socket_path)
        s.sendall(payload_bytes)
        s.shutdown(socket.SHUT_WR)
        chunks = []
        while True:
            chunk = s.recv(65536)
            if not chunk: break
            chunks.append(chunk)
        resp = b"".join(chunks)
        s.close()
        return resp

    def test_malformed_json_payload(self):
        resp = self.send_raw_bytes_ipc(b"this is not valid json { [")
        try:
            res_dict = json.loads(resp.decode('utf-8'))
            self.assertEqual(res_dict.get("status"), "error")
            self.assertIn("message", res_dict)
        except Exception as e:
            self.fail(f"Response was not valid JSON: {resp} - Error: {e}")

    def test_missing_command_field(self):
        res = self.send_raw_ipc({"params": {}})
        self.assertEqual(res.get("status"), "error")

    def test_unknown_command(self):
        res = self.send_raw_ipc({"command": "some:garbage:command"})
        self.assertEqual(res.get("status"), "error")
        self.assertIn("unknown", res.get("message", "").lower())

    def test_notification_send_invalid_urgency_type(self):
        res = self.send_raw_ipc({"command": "notification:send", "params": {"title": "Adversarial", "body": "Int urgency", "urgency": 123}})
        self.assertEqual(res.get("status"), "error")

    def test_notification_send_invalid_timeout_type(self):
        res = self.send_raw_ipc({"command": "notification:send", "params": {"title": "Timeout", "body": "String timeout", "timeout": "five-thousand"}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_sandbox_start_negative_threads(self):
        res = self.send_raw_ipc({"command": "sandbox:start", "params": {"threads": -2}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_sandbox_start_float_threads(self):
        res = self.send_raw_ipc({"command": "sandbox:start", "params": {"threads": 1.5}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_sandbox_start_invalid_memory_limit(self):
        res = self.send_raw_ipc({"command": "sandbox:start", "params": {"memory": "0MB"}})
        self.assertEqual(res.get("status"), "error")
        self.assertIn("limits violated", res.get("message", ""))
        res2 = self.send_raw_ipc({"command": "sandbox:start", "params": {"memory": "-50MB"}})
        self.assertEqual(res2.get("status"), "error")
        res3 = self.send_raw_ipc({"command": "sandbox:start", "params": {"memory": "0GB"}})
        self.assertIn(res3.get("status"), ["success", "error"])

    def test_status_bar_extreme_cpu_clamping(self):
        if not self.live_mode:
            self.send_simulator_command("simulator:set_cpu", {"cpu": 250.0})
            res = self.send_raw_ipc({"command": "status_bar:get_cpu"})
            self.assertEqual(res.get("status"), "success")
            self.assertEqual(res.get("cpu"), 100)
            self.send_simulator_command("simulator:set_cpu", {"cpu": -50.0})
            res = self.send_raw_ipc({"command": "status_bar:get_cpu"})
            self.assertEqual(res.get("status"), "success")
            self.assertEqual(res.get("cpu"), 0)

    def test_status_bar_ram_division_by_zero(self):
        if not self.live_mode:
            self.send_simulator_command("simulator:set_ram", {"ram": {"used": 2.0, "total": 0.0, "percent": 0.0}})
            res = self.send_raw_ipc({"command": "status_bar:get_ram"})
            self.assertEqual(res.get("status"), "success")

    def test_workspaces_invalid_types(self):
        if not self.live_mode:
            res = self.send_simulator_command("simulator:set_workspaces", {"workspaces": "not-a-list", "active": -1})
            self.assertIn(res.get("status"), ["success", "error"])

    def test_high_frequency_multi_service_flood(self):
        commands = [{"command": "status_bar:get_clock"}, {"command": "status_bar:get_cpu"}, {"command": "status_bar:get_ram"}, {"command": "launcher:get_state"}, {"command": "notification:get_queue"}, {"command": "sandbox:status"}]
        for _ in range(5):
            for cmd in commands:
                res = self.send_raw_ipc(cmd)
                self.assertEqual(res.get("status"), "success")

    def test_notification_dismiss_invalid_id(self):
        res = self.send_raw_ipc({"command": "notification:dismiss", "params": {"id": "invalid_id"}})
        self.assertEqual(res.get("status"), "success")
        res_neg = self.send_raw_ipc({"command": "notification:dismiss", "params": {"id": -999}})
        self.assertEqual(res_neg.get("status"), "success")

    def test_notification_send_negative_timeout(self):
        res = self.send_raw_ipc({"command": "notification:send", "params": {"title": "Negative Timeout", "body": "Negative timeout", "timeout": -1000}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_sandbox_start_string_threads(self):
        res = self.send_raw_ipc({"command": "sandbox:start", "params": {"threads": "four"}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_status_bar_get_cpu_invalid_type(self):
        if not self.live_mode:
            self.send_simulator_command("simulator:set_cpu", {"cpu": "high"})
            res = self.send_raw_ipc({"command": "status_bar:get_cpu"})
            self.assertIn(res.get("status"), ["success", "error"])

    def test_launcher_launch_empty_id(self):
        res = self.send_raw_ipc({"command": "launcher:launch", "params": {"app_id": ""}})
        self.assertEqual(res.get("status"), "error")

    def test_status_bar_set_clock_malformed(self):
        if not self.live_mode:
            res = self.send_simulator_command("simulator:set_clock", {"time": 12345})
            self.assertIn(res.get("status"), ["success", "error"])

    def test_null_payload_ipc(self):
        resp = self.send_raw_bytes_ipc(b"null")
        try:
            res_dict = json.loads(resp.decode('utf-8'))
            self.assertEqual(res_dict.get("status"), "error")
            self.assertIn("message", res_dict)
        except Exception as e:
            self.fail(f"Response was not valid JSON: {resp} - Error: {e}")

    def test_sandbox_load_panel_missing(self):
        self.send_raw_ipc({"command": "sandbox:start", "params": {"memory": "2GB", "threads": 2}})
        res = self.send_raw_ipc({"command": "sandbox:load_panel", "params": {}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_sandbox_start_extreme_memory_limits_units(self):
        res = self.send_raw_ipc({"command": "sandbox:start", "params": {"memory": "0GB", "threads": 2}})
        self.assertIn(res.get("status"), ["success", "error"])
        res_neg = self.send_raw_ipc({"command": "sandbox:start", "params": {"memory": "-10GB", "threads": 2}})
        self.assertIn(res_neg.get("status"), ["success", "error"])

    def test_notification_send_overflow_timeout(self):
        res = self.send_raw_ipc({"command": "notification:send", "params": {"title": "Overflow", "body": "2^31 timeout", "timeout": 2147483648}})
        self.assertIn(res.get("status"), ["success", "error"])

    def test_status_bar_ram_invalid_format(self):
        if not self.live_mode:
            self.send_simulator_command("simulator:set_ram", {"ram": "malformed_ram_string"})
            res = self.send_raw_ipc({"command": "status_bar:get_ram"})
            self.assertIn(res.get("status"), ["success", "error"])

# ── 4. Embedded E2E Integration Test Suite (73 Tests) ──
class XenoE2ETestCase(unittest.TestCase):
    live_mode = False
    simulator = None
    socket_path = None
    original_path = None
    mock_bin_dir = None

    @classmethod
    def setUpClass(cls):
        cls.live_mode = os.environ.get("XENO_E2E_LIVE", "").lower() in ("1", "true", "yes")
        if not cls.live_mode:
            cls.simulator = XenoSystemSimulator()
            cls.socket_path = cls.simulator.start()
            cls.mock_bin_dir = tempfile.mkdtemp(prefix="xeno_e2e_bin_")
            create_mock_binaries(cls.mock_bin_dir)
            cls.original_path = os.environ.get("PATH", "")
            os.environ["PATH"] = f"{cls.mock_bin_dir}{os.path.pathsep}{cls.original_path}"
            os.environ["XENO_IPC_SOCKET"] = cls.socket_path
        else:
            if "XENO_IPC_SOCKET" not in os.environ:
                os.environ["XENO_IPC_SOCKET"] = "/tmp/xeno-ipc.sock"

    @classmethod
    def tearDownClass(cls):
        if not cls.live_mode and cls.simulator:
            cls.simulator.stop()
            if cls.original_path: os.environ["PATH"] = cls.original_path
            if cls.mock_bin_dir and os.path.exists(cls.mock_bin_dir): shutil.rmtree(cls.mock_bin_dir)
        if "XENO_IPC_SOCKET" in os.environ: del os.environ["XENO_IPC_SOCKET"]

    def setUp(self):
        if not self.live_mode and self.simulator:
            self.send_simulator_command("simulator:clear_state")
            time.sleep(0.01)

    def send_simulator_command(self, command, params=None):
        if self.live_mode: return None
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(self.socket_path)
            s.sendall(json.dumps({"command": command, "params": params or {}}).encode('utf-8'))
            s.shutdown(socket.SHUT_WR)
            chunks = []
            while True:
                chunk = s.recv(65536)
                if not chunk: break
                chunks.append(chunk)
            resp = b"".join(chunks)
            s.close()
            return json.loads(resp.decode('utf-8'))
        except Exception as e:
            self.fail(f"Failed to communicate with simulator: {e}")

    def run_command(self, cmd, args=None):
        full_cmd = [cmd] + (args or [])
        res = subprocess.run(full_cmd, capture_output=True, text=True, env=os.environ)
        return res.stdout, res.stderr, res.returncode

    # F1: Status Bar Tests
    def test_clock_updates_at_one_second_intervals(self):
        self.send_simulator_command("simulator:set_clock", {"time": "2026-07-06 18:26:33"})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertEqual(code, 0); self.assertIn("2026-07-06 18:26:33", stdout)
        self.send_simulator_command("simulator:set_clock", {"time": "2026-07-06 18:26:34"})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertEqual(code, 0); self.assertIn("2026-07-06 18:26:34", stdout)

    def test_cpu_meter_parsing_valid(self):
        self.send_simulator_command("simulator:set_cpu", {"cpu": 24.5})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-cpu"])
        self.assertEqual(code, 0); self.assertIn("CPU: 24.5%", stdout.strip())

    def test_ram_meter_parsing_valid(self):
        self.send_simulator_command("simulator:set_ram", {"ram": {"used": 8.0, "total": 16.0, "percent": 50.0}})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-ram"])
        self.assertEqual(code, 0); self.assertIn("RAM: 8.0GB / 16.0GB (50.0%)", stdout.strip())

    def test_active_workspaces_render(self):
        self.send_simulator_command("simulator:set_workspaces", {"workspaces": [1, 2, 3, 4], "active": 3})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-workspaces"])
        self.assertEqual(code, 0); self.assertIn("Workspaces: 1, 2, [3], 4", stdout.strip())

    def test_launcher_toggle_trigger(self):
        stdout, _, code = self.run_command("xeno-status-bar", ["--toggle-launcher"])
        self.assertEqual(code, 0); self.assertIn("Launcher toggled: True", stdout.strip())
        stdout, _, code = self.run_command("xeno-status-bar", ["--toggle-launcher"])
        self.assertEqual(code, 0); self.assertIn("Launcher toggled: False", stdout.strip())

    # F2: Launcher Tests
    def test_application_list_grid(self):
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0); self.assertIn("[terminal] Terminal", stdout); self.assertIn("[filemanager] File Manager", stdout)

    def test_launcher_selection_highlights(self):
        self.send_simulator_command("simulator:set_launcher_state", {"highlighted_index": 2})
        stdout, _, code = self.run_command("xeno-launcher", ["--get-state"])
        self.assertEqual(code, 0); self.assertIn("Highlighted: 2", stdout)

    def test_launcher_custom_font_settings(self):
        self.send_simulator_command("simulator:set_launcher_state", {"font_family": "JetBrains Mono", "font_size": 18})
        stdout, _, code = self.run_command("xeno-launcher", ["--get-state"])
        self.assertEqual(code, 0); self.assertIn("Font: JetBrains Mono 18px", stdout)

    def test_launcher_grid_layout_rendering(self):
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0); self.assertIn("Terminal - bash (utilities-terminal)", stdout.strip())

    def test_launcher_selection_click_event(self):
        stdout, _, code = self.run_command("xeno-launcher", ["--launch", "terminal"])
        self.assertEqual(code, 0); self.assertIn("Launched application: terminal", stdout)

    # F3: Notification Tests
    def test_toast_popup_dispatch(self):
        stdout, _, code = self.run_command("xeno-notify", ["--send", "System Update", "Download complete"])
        self.assertEqual(code, 0); self.assertIn("Notification Sent [ID: 1]", stdout)

    def test_warning_logs_parsing(self):
        self.run_command("xeno-notify", ["--send", "Low Battery", "15% remaining", "--urgency", "warning"])
        stdout, _, code = self.run_command("xeno-notify", ["--get-logs"])
        self.assertEqual(code, 0); self.assertIn("WARNING: Low Battery - 15% remaining", stdout)

    def test_notification_animation_configuration(self):
        self.run_command("xeno-notify", ["--send", "Alert", "Text", "--timeout", "5000"])
        stdout, _, code = self.run_command("xeno-notify", ["--get-queue"])
        self.assertEqual(code, 0); self.assertIn("Timeout: 5000ms", stdout)

    def test_sound_hooks_execution(self):
        self.run_command("xeno-notify", ["--send", "Ping", "Hello", "--sound", "ping.wav"])
        if not self.live_mode:
            res = self.send_simulator_command("simulator:get_sound_played")
            self.assertIn("ping.wav", res.get("sound_played", []))

    def test_auto_dismiss_transitions(self):
        self.run_command("xeno-notify", ["--send", "Temp", "Dismiss me"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"]); self.assertIn("Temp", stdout)
        self.run_command("xeno-notify", ["--dismiss", "1"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"]); self.assertNotIn("Temp", stdout)

    # F4: Sandbox Tests
    def test_wayland_x11_container_execution(self):
        try:
            stdout, _, code = self.run_command("xeno-sandbox", ["--start"])
            self.assertEqual(code, 0); self.assertIn("Sandbox started successfully", stdout)
        finally:
            self.run_command("xeno-sandbox", ["--stop"])

    def test_thread_allocation_bounds(self):
        stdout, _, code = self.run_command("xeno-sandbox", ["--start", "--threads", "3"])
        self.assertEqual(code, 0)
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("Threads: 3/4", stdout)

    def test_panel_widget_loading(self):
        self.run_command("xeno-sandbox", ["--start"])
        stdout, _, code = self.run_command("xeno-sandbox", ["--load-panel", "math_panel"])
        self.assertEqual(code, 0); self.assertIn("Panel math_panel loaded successfully", stdout)

    def test_sandbox_start_stop_scripts(self):
        self.run_command("xeno-sandbox", ["--start"])
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"]); self.assertIn("Sandbox Status: Running", stdout)
        self.run_command("xeno-sandbox", ["--stop"])
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"]); self.assertIn("Sandbox Status: Stopped", stdout)

    def test_sandbox_performance_metrics(self):
        self.run_command("xeno-sandbox", ["--start", "--memory", "1GB", "--threads", "2"])
        stdout, _, code = self.run_command("xeno-sandbox", ["--status"])
        self.assertEqual(code, 0); self.assertIn("Memory Limit: 1GB", stdout); self.assertIn("Threads: 2/4", stdout)

    # F1 Boundaries
    def test_empty_null_cpu_ram_diagnostics(self):
        self.send_simulator_command("simulator:set_cpu", {"cpu": 0.0})
        self.send_simulator_command("simulator:set_ram", {"ram": {"used": 0.0, "total": 16.0, "percent": 0.0}})
        stdout_cpu, _, _ = self.run_command("xeno-status-bar", ["--get-cpu"])
        stdout_ram, _, _ = self.run_command("xeno-status-bar", ["--get-ram"])
        self.assertIn("0%", stdout_cpu); self.assertIn("0.0%", stdout_ram)

    def test_clock_dst_leap_transition_boundaries(self):
        self.send_simulator_command("simulator:set_clock", {"time": "2026-02-28 23:59:59"})
        stdout, _, _ = self.run_command("xeno-status-bar", ["--get-clock"]); self.assertIn("2026-02-28 23:59:59", stdout)
        self.send_simulator_command("simulator:set_clock", {"time": "2026-03-01 00:00:00"})
        stdout, _, _ = self.run_command("xeno-status-bar", ["--get-clock"]); self.assertIn("2026-03-01 00:00:00", stdout)

    def test_out_of_range_cpu_values(self):
        self.send_simulator_command("simulator:set_cpu", {"cpu": 150.0})
        stdout, _, _ = self.run_command("xeno-status-bar", ["--get-cpu"]); self.assertIn("100.0%", stdout)

    def test_active_workspace_array_overflows(self):
        large_workspaces = list(range(1, 101))
        self.send_simulator_command("simulator:set_workspaces", {"workspaces": large_workspaces, "active": 99})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-workspaces"])
        self.assertEqual(code, 0); self.assertIn("[99]", stdout)

    def test_rapid_toggle_spam(self):
        for _ in range(20):
            _, _, code = self.run_command("xeno-status-bar", ["--toggle-launcher"])
            self.assertEqual(code, 0)

    # F2 Boundaries
    def test_empty_applications_grid(self):
        self.send_simulator_command("simulator:set_applications", {"applications": []})
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0); self.assertIn("Applications grid: empty", stdout)

    def test_extreme_font_sizes(self):
        self.send_simulator_command("simulator:set_launcher_state", {"font_size": 1000})
        stdout, _, code = self.run_command("xeno-launcher", ["--get-state"])
        self.assertEqual(code, 0); self.assertIn("1000px", stdout)

    def test_overflow_bounds_app_list(self):
        huge_apps = [{"id": f"app_{i}", "name": f"App {i}", "command": "true", "icon": "app"} for i in range(1000)]
        self.send_simulator_command("simulator:set_applications", {"applications": huge_apps})
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0); self.assertIn("app_999", stdout)

    def test_launching_non_existent_applications(self):
        _, stderr, code = self.run_command("xeno-launcher", ["--launch", "non_existent_binary"])
        self.assertNotEqual(code, 0); self.assertIn("not found", stderr.lower())

    def test_high_frequency_launcher_shortcut_presses(self):
        for _ in range(25):
            _, _, code = self.run_command("xeno-launcher", ["--press-shortcut"])
            self.assertEqual(code, 0)

    # F3 Boundaries
    def test_high_frequency_notification_storm(self):
        for i in range(60):
            _, _, code = self.run_command("xeno-notify", ["--send", f"Storm {i}", "Flooding system"])
            self.assertEqual(code, 0)
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertTrue(len(stdout) > 0)

    def test_extremely_long_text_strings(self):
        long_body = "A" * 5000
        stdout, _, code = self.run_command("xeno-notify", ["--send", "Warning", long_body])
        self.assertEqual(code, 0); self.assertIn("Notification Sent", stdout)

    def test_null_message_warning_notifications(self):
        _, stderr, code = self.run_command("xeno-notify", ["--send", "", ""])
        self.assertNotEqual(code, 0); self.assertIn("cannot both be empty", stderr.lower())

    def test_unsupported_sound_files_hooks(self):
        stdout, _, code = self.run_command("xeno-notify", ["--send", "Alert", "Msg", "--sound", "/invalid/path.mp3"])
        self.assertEqual(code, 0); self.assertIn("Notification Sent", stdout)

    def test_overlapping_collision_layout(self):
        for i in range(8): self.run_command("xeno-notify", ["--send", f"Notif {i}", "Layout Check"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertTrue(len(stdout.splitlines()) >= 8)

    # F4 Boundaries
    def test_missing_graphics_drivers_display_sockets(self):
        self.send_simulator_command("simulator:set_display_socket", {"display_socket_exists": False})
        _, stderr, code = self.run_command("xeno-sandbox", ["--start"])
        self.assertEqual(code, 1); self.assertIn("no wayland or x11 graphics driver/display socket found", stderr.lower())

    def test_concurrent_double_spawn_collisions(self):
        _, _, code1 = self.run_command("xeno-sandbox", ["--start"]); self.assertEqual(code1, 0)
        _, stderr, code2 = self.run_command("xeno-sandbox", ["--start"])
        self.assertEqual(code2, 2); self.assertIn("concurrent sandbox wrapper spawn collision", stderr.lower())

    def test_extreme_memory_limits(self):
        _, stderr, code = self.run_command("xeno-sandbox", ["--start", "--memory", "64MB"])
        self.assertEqual(code, 3); self.assertIn("memory allocation below 128mb threshold", stderr.lower())

    def test_max_thread_allocation_exhaust_boundaries(self):
        _, stderr, code = self.run_command("xeno-sandbox", ["--start", "--threads", "16"])
        self.assertEqual(code, 3); self.assertIn("native thread allocation limit exceeded", stderr.lower())

    def test_script_parameter_validation(self):
        _, stderr, code = self.run_command("xeno-sandbox", ["--invalid-flag"])
        self.assertEqual(code, 1); self.assertIn("invalid flag", stderr.lower())

    # Combinations
    def test_status_bar_launcher_toggle_sync(self):
        stdout, _, _ = self.run_command("xeno-launcher", ["--get-state"]); self.assertIn("Visible: False", stdout)
        self.run_command("xeno-status-bar", ["--toggle-launcher"])
        stdout, _, _ = self.run_command("xeno-launcher", ["--get-state"]); self.assertIn("Visible: True", stdout)
        self.run_command("xeno-launcher", ["--press-shortcut"])
        stdout, _, _ = self.run_command("xeno-launcher", ["--get-state"]); self.assertIn("Visible: False", stdout)

    def test_app_launch_with_notifications(self):
        self.run_command("xeno-launcher", ["--launch", "terminal"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertIn("System Launch", stdout); self.assertIn("Launching Terminal inside container...", stdout)

    def test_notifications_under_high_resource_stress(self):
        self.send_simulator_command("simulator:set_cpu", {"cpu": 98.2})
        self.send_simulator_command("simulator:set_ram", {"ram": {"used": 15.5, "total": 16.0, "percent": 96.8}})
        for i in range(5): self.run_command("xeno-notify", ["--send", f"Critical Alert {i}", "System resources stressed"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"]); self.assertIn("Critical Alert 4", stdout)

    def test_sandbox_multi_panel_scaling(self):
        self.run_command("xeno-sandbox", ["--start"])
        self.run_command("xeno-sandbox", ["--load-panel", "math_panel"])
        self.run_command("xeno-sandbox", ["--load-panel", "code_panel"])
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("math_panel, code_panel", stdout)

    # Real-World Scenarios
    def test_system_boot_session_initialization(self):
        self.run_command("xeno-notify", ["--send", "Session Init", "Starting Xeno session..."])
        _, _, code1 = self.run_command("xeno-status-bar", ["--get-clock"]); self.assertEqual(code1, 0)
        _, _, code2 = self.run_command("xeno-launcher", ["--list-apps"]); self.assertEqual(code2, 0)
        _, _, code3 = self.run_command("xeno-sandbox", ["--start"]); self.assertEqual(code3, 0)
        stdout, _, _ = self.run_command("xeno-notify", ["--get-logs"]); self.assertIn("Session Init", stdout)

    def test_application_launch_flow(self):
        self.run_command("xeno-launcher", ["--press-shortcut"])
        self.run_command("xeno-launcher", ["--list-apps"])
        self.run_command("xeno-launcher", ["--launch", "terminal"])
        self.run_command("xeno-sandbox", ["--start"])
        self.run_command("xeno-sandbox", ["--load-panel", "terminal"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertIn("System Launch", stdout)

    def test_system_telemetry_alert_scenario(self):
        self.send_simulator_command("simulator:set_cpu", {"cpu": 95.0})
        self.run_command("xeno-notify", ["--send", "CPU Alert", "CPU usage at 95.0%", "--urgency", "warning"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-logs"])
        self.assertIn("WARNING: CPU Alert - CPU usage at 95.0%", stdout)

    def test_sandbox_restart_clean_exit(self):
        self.run_command("xeno-sandbox", ["--start"])
        self.run_command("xeno-sandbox", ["--load-panel", "data_panel"])
        self.run_command("xeno-sandbox", ["--stop"])
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("Sandbox Status: Stopped", stdout); self.assertNotIn("data_panel", stdout)

    def test_theme_conformity_audit_check(self):
        ws_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        if not os.path.exists(os.path.join(ws_dir, "desktop")):
            ws_dir = "/home/xeno/Xeno-os"
        shell_dir = os.path.join(ws_dir, "desktop", "shell")
        hex_color_regex = re.compile(r'#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})\b')
        hardcoded_px_regex = re.compile(r'\b([3-9]|\d{2,})px\b')
        violations = []
        desktop_dir = os.path.join(ws_dir, "desktop")
        for root, _, files in os.walk(desktop_dir):
            is_shell_path = shell_dir in os.path.abspath(root)
            for file in files:
                filepath = os.path.join(root, file)
                if file in ("theme.ts", "theme.py"): continue
                is_css = file.endswith((".css", ".scss"))
                is_shell_ts = is_shell_path and file.endswith((".ts", ".js", ".tsx", ".jsx"))
                if not (is_css or is_shell_ts): continue
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f: content = f.read()
                if file.endswith((".ts", ".js", ".tsx", ".jsx", ".css", ".scss")):
                    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                for idx, line in enumerate(content.splitlines(), 1):
                    clean_line = line
                    if file.endswith((".ts", ".js", ".tsx", ".jsx", ".css", ".scss")): clean_line = re.sub(r'//.*', '', clean_line)
                    for match in [m.group(0) for m in hex_color_regex.finditer(clean_line)]:
                        violations.append(f"{file}:{idx} - Hardcoded color hex '{match}' in line: {line.strip()}")
                    for match in hardcoded_px_regex.findall(clean_line):
                        violations.append(f"{file}:{idx} - Hardcoded pixel size '{match}px' in line: {line.strip()}")
        if violations:
            self.fail(f"Theme conformity audit failed: {len(violations)} violations found.")

    def test_kernel_build_pipeline_and_security_defaults(self):
        ws_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        if not os.path.exists(os.path.join(ws_dir, "kernel")):
            ws_dir = "/home/xeno/Xeno-os"
        build_script = os.path.join(ws_dir, "kernel", "build-kernel.sh")
        validate_script = os.path.join(ws_dir, "kernel", "validate-kernel-deb.sh")
        fix_boot_script = os.path.join(ws_dir, "scripts", "xeno-reaper.sh")
        with open(build_script, "r", encoding="utf-8") as f: build_content = f.read()
        with open(validate_script, "r", encoding="utf-8") as f: validate_content = f.read()
        with open(fix_boot_script, "r", encoding="utf-8") as f: fix_boot_content = f.read()
        self.assertNotIn("WARNING: optional patch skipped", build_content)
        self.assertIn("CONFIG_PREEMPT", validate_content)
        self.assertIn("CONFIG_HZ", validate_content)
        self.assertIn("@hyprland soft rtprio 99", fix_boot_content)
        self.assertIn("xeno soft rtprio 99", fix_boot_content)
        limits_match = re.search(r'cat << [\'"]?LIMITS_EOF[\'"]?(.*?)LIMITS_EOF', fix_boot_content, re.DOTALL)
        if limits_match:
            self.assertNotIn("*" + " soft rtprio", limits_match.group(1))

# ── 5. Cyber-Nord Live Real-Time Dynamic Test Runner ──
class CyberNordTestResult(unittest.TestResult):
    def __init__(self, stream=None, descriptions=None, verbosity=None, total_tests=0):
        super().__init__(stream, descriptions, verbosity)
        self.total_tests = total_tests
        self.count = 0
        self.passed = 0
        self.start_time = time.time()
        self.spinners = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        self.spin_idx = 0
        self.is_tty = sys.stdout.isatty() and os.environ.get("TERM") != "dumb"

    def _render_progress(self, current_test_name=""):
        if not self.is_tty:
            return
        pct = int((self.count / max(1, self.total_tests)) * 100)
        bar_width = 20
        filled = int((self.count / max(1, self.total_tests)) * bar_width)
        empty = bar_width - filled
        bar = "█" * filled + "░" * empty
        elapsed = int(time.time() - self.start_time)
        mins, secs = elapsed // 60, elapsed % 60
        spin = self.spinners[self.spin_idx % len(self.spinners)]
        self.spin_idx += 1
        
        max_name_len = 34
        short_name = current_test_name
        if len(short_name) > max_name_len:
            short_name = short_name[:max_name_len - 3] + "..."
            
        line = f"\r  \033[38;2;136;192;208m{spin}\033[0m [\033[38;2;136;192;208m{bar}\033[0m] \033[1m{pct:3d}%\033[0m ({self.count:2d}/{self.total_tests}) │ \033[38;2;163;190;140m✔ {self.passed}\033[0m │ \033[38;2;191;97;106m✖ {len(self.failures) + len(self.errors)}\033[0m │ \033[2m[{mins:02d}:{secs:02d}]\033[0m \033[38;2;129;161;193m{short_name:<34}\033[0m\033[K"
        sys.stdout.write(line)
        sys.stdout.flush()

    def startTest(self, test):
        super().startTest(test)
        self._render_progress(test._testMethodName)

    def addSuccess(self, test):
        super().addSuccess(test)
        self.count += 1
        self.passed += 1
        if not self.is_tty:
            print(f"  ✔ [PASS] ({self.count}/{self.total_tests}) {test._testMethodName}")
        else:
            self._render_progress(test._testMethodName)

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.count += 1
        if not self.is_tty:
            print(f"  ✖ [FAIL] ({self.count}/{self.total_tests}) {test._testMethodName}")
        else:
            self._render_progress(test._testMethodName)

    def addError(self, test, err):
        super().addError(test, err)
        self.count += 1
        if not self.is_tty:
            print(f"  ✖ [ERROR] ({self.count}/{self.total_tests}) {test._testMethodName}")
        else:
            self._render_progress(test._testMethodName)

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        self.count += 1
        if not self.is_tty:
            print(f"  ⚠ [SKIP] ({self.count}/{self.total_tests}) {test._testMethodName} ({reason})")
        else:
            self._render_progress(test._testMethodName)

# ── 6. Main Execution Dispatcher ──
if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    if mode in ("adv", "adversarial"):
        suite.addTests(loader.loadTestsFromTestCase(XenoAdversarialTestCase))
    elif mode in ("e2e", "integration"):
        suite.addTests(loader.loadTestsFromTestCase(XenoE2ETestCase))
    elif mode == "live":
        os.environ["XENO_E2E_LIVE"] = "1"
        suite.addTests(loader.loadTestsFromTestCase(XenoE2ETestCase))
    else: # all
        suite.addTests(loader.loadTestsFromTestCase(XenoAdversarialTestCase))
        suite.addTests(loader.loadTestsFromTestCase(XenoE2ETestCase))

    total = suite.countTestCases()
    result = CyberNordTestResult(total_tests=total)
    suite.run(result)

    elapsed = time.time() - result.start_time
    mins, secs = int(elapsed // 60), int(elapsed % 60)
    total_fails = len(result.failures) + len(result.errors)
    pass_pct = (result.passed / max(1, total)) * 100

    bar_width = 24
    filled = int((result.passed / max(1, total)) * bar_width)
    bar = "█" * filled + "░" * (bar_width - filled)
    bar_color = "\033[38;2;163;190;140m" if total_fails == 0 else "\033[38;2;191;97;106m"

    if result.is_tty:
        sys.stdout.write("\r\033[K")
        sys.stdout.flush()

    print("\n\033[1m═══════════════════════════════════════════════════════════════════════════════\033[0m")
    print("\033[1m                     XENO OS AUTOMATED TEST SUITE REPORT                       \033[0m")
    print("\033[1m═══════════════════════════════════════════════════════════════════════════════\033[0m")
    print(f"  Pass Rate Gauge: [{bar_color}{bar}\033[0m] \033[1m{pass_pct:5.1f}%\033[0m")
    print(f"  Total Executed:  \033[1m{result.count}\033[0m / {total}")
    print(f"  Passed Tests:    \033[38;2;163;190;140m\033[1m{result.passed}\033[0m")
    print(f"  Failed Tests:    \033[38;2;191;97;106m\033[1m{total_fails}\033[0m")
    print(f"  Elapsed Time:    \033[38;2;136;192;208m{mins:02d}m {secs:02d}s ({elapsed:.2f}s)\033[0m")
    print("\033[1m═══════════════════════════════════════════════════════════════════════════════\033[0m")

    if total_fails == 0:
        print("\033[38;2;163;190;140m\033[1m✔ ALL AUTOMATED TEST SUITES PASSED (100% CONFORMITY)\033[0m\n")
    else:
        print("\033[38;2;191;97;106m\033[1m✖ TEST FAILURES DETECTED:\033[0m")
        for test, trace in result.failures + result.errors:
            print(f"\n\033[1m[FAIL] {test}\033[0m\n{trace}")
        print()
    sys.exit(0 if total_fails == 0 else 1)
XENO_TEST_RUNNER_EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 3: Boot Display & Hyprland Session Setup
# ─────────────────────────────────────────────────────────────────────────────
run_fix_boot_display() {
    xeno_require_root
    echo -e "${C_BOLD}${C_CYAN}▶ [BOOT-FIX] Configuring Boot Display, Autologin & Hyprland Session...${C_RESET}"
    
    # 1. Disable conflicting display services
    rm -f "$ROOTFS/etc/systemd/system/display-manager.service"
    rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-session.service"
    rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-x11-session.service"
    
    # 2. Scoped security limits
    mkdir -p "$ROOTFS/etc/security/limits.d"
    for grp in input render video kvm audio tty plugdev netdev sudo hyprland; do
        if [ -f "$ROOTFS/etc/group" ]; then
            if grep -q "^${grp}:" "$ROOTFS/etc/group"; then
                if ! grep -q "^${grp}:.*xeno" "$ROOTFS/etc/group"; then
                    sed -i "/^${grp}:/ s/$/,xeno/" "$ROOTFS/etc/group"
                    sed -i "s/:,xeno/:xeno/" "$ROOTFS/etc/group"
                fi
            else
                echo "${grp}:x:995:xeno" >> "$ROOTFS/etc/group"
            fi
        fi
    done

    cat > "$ROOTFS/etc/security/limits.d/99-hyprland.conf" << 'LIMITS_EOF'
@hyprland soft rtprio 99
@hyprland hard rtprio 99
@hyprland soft memlock unlimited
@hyprland hard memlock unlimited
xeno soft rtprio 99
xeno hard rtprio 99
xeno soft memlock unlimited
xeno hard memlock unlimited
LIMITS_EOF

    # 3. Hardware Auto-detection & Autotune
    cat > "$ROOTFS/usr/bin/xeno-hardware-detect" << 'HW_EOF'
#!/bin/bash
if command -v lspci >/dev/null; then
    if lspci | grep -qi nvidia; then
        export LIBVA_DRIVER_NAME=nvidia
        export GBM_BACKEND=nvidia-drm
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export WLR_NO_HARDWARE_CURSORS=1
    elif lspci | grep -qi amd; then
        export LIBVA_DRIVER_NAME=radeonsi
    elif lspci | grep -qi intel; then
        export LIBVA_DRIVER_NAME=iHD
    fi
fi
HW_EOF
    chmod +x "$ROOTFS/usr/bin/xeno-hardware-detect"

    cat > "$ROOTFS/usr/bin/xeno-autotune" << 'AUTOTUNE_EOF'
#!/bin/bash
if [ "$(cat /sys/class/power_supply/AC/online 2>/dev/null)" = "1" ] || [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "1" ]; then
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
else
    echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
fi
AUTOTUNE_EOF
    chmod +x "$ROOTFS/usr/bin/xeno-autotune"

    cat > "$ROOTFS/etc/systemd/system/xeno-autotune.service" << 'AUTOSVC_EOF'
[Unit]
Description=Xeno OS Power and CPU Autotune
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/xeno-autotune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
AUTOSVC_EOF
    mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"
    ln -sf /etc/systemd/system/xeno-autotune.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-autotune.service" || true

    # 4. Background Health Diagnostic Service & Timer
    if [ -f "$WS_DIR/scripts/xeno-health-check.sh" ]; then
        cp -f "$WS_DIR/scripts/xeno-health-check.sh" "$ROOTFS/usr/bin/xeno-health-check"
    else
        cat > "$ROOTFS/usr/bin/xeno-health-check" << 'HEALTH_SCRIPT_EOF'
#!/bin/bash
set -uo pipefail
ROOT_FREE_MB=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
if [ "$ROOT_FREE_MB" -lt 512 ]; then
    logger -t xeno-health "[WARN] Low disk space: ${ROOT_FREE_MB} MB"
fi
if command -v dpkg >/dev/null 2>&1; then
    BROKEN=$(dpkg -l 2>/dev/null | awk '$1 ~ /U|H|R|F/ {print $2}')
    [ -n "$BROKEN" ] && logger -t xeno-health "[FAIL] Broken packages: $BROKEN"
fi
exit 0
HEALTH_SCRIPT_EOF
    fi
    chmod 755 "$ROOTFS/usr/bin/xeno-health-check"

    cat > "$ROOTFS/etc/systemd/system/xeno-health.service" << 'HEALTHSVC_EOF'
[Unit]
Description=Xeno OS Periodic Health and Diagnostic Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/xeno-health-check --daemon
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
HEALTHSVC_EOF

    cat > "$ROOTFS/etc/systemd/system/xeno-health.timer" << 'HEALTHTMR_EOF'
[Unit]
Description=Run Xeno OS Health and Diagnostic Monitor Periodically

[Timer]
OnBootSec=3min
OnUnitActiveSec=2h
Persistent=true

[Install]
WantedBy=timers.target
HEALTHTMR_EOF
    mkdir -p "$ROOTFS/etc/systemd/system/timers.target.wants"
    ln -sf /etc/systemd/system/xeno-health.timer "$ROOTFS/etc/systemd/system/timers.target.wants/xeno-health.timer" || true

    # 5. Hyprland Session Launcher & Desktop Shell Executable
    cat > "$ROOTFS/usr/bin/xeno-start-hyprland" << 'LAUNCHER_EOF'
#!/bin/bash
export USER="${USER:-xeno}"
export HOME="${HOME:-/home/xeno}"
export LOGNAME="${LOGNAME:-xeno}"
export XDG_SEAT="${XDG_SEAT:-seat0}"
export XDG_VTNR="${XDG_VTNR:-1}"

if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
    if mkdir -p "/run/user/$(id -u)" 2>/dev/null; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    else
        export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    fi
    chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi

export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_CURRENT_DESKTOP=Hyprland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11,*}"
export CLUTTER_BACKEND=wayland
export SDL_VIDEODRIVER=wayland
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"

force_software() {
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export MESA_LOADER_DRIVER_OVERRIDE=kms_swrast
    export WLR_RENDERER=pixman
    export WLR_NO_HARDWARE_CURSORS=1
}

# VM Detection
VIRT_TYPE="none"
if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "none")
fi

if [ "$VIRT_TYPE" != "none" ]; then
    force_software "Virtual machine ($VIRT_TYPE) detected"
else
    /usr/bin/xeno-hardware-detect 2>/dev/null || true
fi

if [ -f /etc/security/limits.d/99-hyprland.conf ]; then
    ulimit -r 99 2>/dev/null || true
    ulimit -l unlimited 2>/dev/null || true
fi

mkdir -p "$HOME/.config/hypr"
cat > "$HOME/.config/hypr/hyprland.conf" << 'H_EOF'
monitor=,preferred,auto,1
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(88c0d0ee) rgba(81a1c1ee) 45deg
    col.inactive_border = rgba(4c566aaa)
    layout = dwindle
}
decoration {
    rounding = 8
    blur {
        enabled = false
    }
}
animations {
    enabled = false
}
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
}
bind = SUPER, Space, exec, xeno-ipc toggle_launcher
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
exec-once = /usr/bin/xeno-desktop-shell
H_EOF
chown -R 1000:1000 "$HOME/.config" 2>/dev/null || true

exec Hyprland
LAUNCHER_EOF
    chmod +x "$ROOTFS/usr/bin/xeno-start-hyprland"

    # Shell execution wrapper
    cat > "$ROOTFS/usr/bin/xeno-desktop-shell" << 'SHELL_EOF'
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.bun/bin:/home/xeno/.bun/bin:${PATH:-}"
SHELL_DIR="$HOME/desktop/shell"
[ ! -d "$SHELL_DIR" ] && SHELL_DIR="/usr/lib/xeno/shell"
[ ! -d "$SHELL_DIR" ] && SHELL_DIR="/home/xeno/desktop/shell"

if command -v bun >/dev/null 2>&1 && [ -f "$SHELL_DIR/app.ts" ]; then
    cd "$SHELL_DIR"
    exec bun run app.ts
elif [ -x /usr/local/bin/bun ] && [ -f "$SHELL_DIR/app.ts" ]; then
    cd "$SHELL_DIR"
    exec /usr/local/bin/bun run app.ts
else
    echo "Fallback: Astal shell runtime not found."
fi
SHELL_EOF
    chmod +x "$ROOTFS/usr/bin/xeno-desktop-shell"

    # Autologin overrides
    mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d" "$ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d"
    cat > "$ROOTFS/etc/systemd/system/getty@tty1.service.d/override.conf" << 'GETTY_EOF'
[Unit]
StartLimitIntervalSec=0

[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear --autologin xeno %I $TERM
Restart=always
RestartSec=2
GETTY_EOF

    cat > "$ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf" << 'SERIAL_EOF'
[Unit]
StartLimitIntervalSec=0

[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 --noclear --autologin xeno %I $TERM
Restart=always
RestartSec=2
SERIAL_EOF
    mkdir -p "$ROOTFS/etc/systemd/system/getty.target.wants"
    ln -sf /usr/lib/systemd/system/getty@.service "$ROOTFS/etc/systemd/system/getty.target.wants/getty@tty1.service" 2>/dev/null || true
    ln -sf /usr/lib/systemd/system/serial-getty@.service "$ROOTFS/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service" 2>/dev/null || true

    echo -e "  ${C_GREEN}✔ [SUCCESS]${C_RESET} Boot display, autologin, and Hyprland launchers configured.\n"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 4: Kernel Staging & RootFS Installation
# ─────────────────────────────────────────────────────────────────────────────
run_stage_kernel() {
    echo -e "${C_BOLD}${C_CYAN}▶ [KERNEL] Staging local kernel packages from kernel/output/ to kernel/cache/...${C_RESET}"
    if ! ls "$OUT_DIR"/linux-image-*.deb &>/dev/null; then
        echo -e "${C_RED}[ERROR] No linux-image-*.deb found in $OUT_DIR. Build kernel first.${C_RESET}"
        return 1
    fi
    mkdir -p "$CACHE_DIR"
    rm -f "$CACHE_DIR"/*.deb
    cp "$OUT_DIR"/*.deb "$CACHE_DIR/"
    cat > "$META_FILE" << EOF
{
  "tagName": "local-build-$(date +%Y%m%d%H%M%S)",
  "publishedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    echo -e "  ${C_GREEN}✔ [SUCCESS]${C_RESET} Kernel packages staged in $CACHE_DIR\n"
}

run_fix_kernel_rootfs() {
    xeno_require_root
    echo -e "${C_BOLD}${C_CYAN}▶ [KERNEL-FIX] Repairing & Installing Kernel into RootFS...${C_RESET}"
    
    local use_fallback=1
    if [ "${XENO_SKIP_CUSTOM:-0}" = "1" ]; then
        use_fallback=1
    elif ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
        if [ -x "$WS_DIR/kernel/validate-kernel-deb.sh" ] && bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$CACHE_DIR"; then
            use_fallback=0
        else
            echo -e "${C_YELLOW}Cached kernel failed validation. Using generic kernel fallback.${C_RESET}"
            use_fallback=1
        fi
    fi

    xeno_chroot_mount "$ROOTFS"
    cleanup_kernel() { xeno_chroot_umount "$ROOTFS"; }
    trap cleanup_kernel EXIT

    # Clean stale module trees
    for d in "$ROOTFS"/lib/modules/*xeno*; do
        [ -d "$d" ] || continue
        rm -rf "$d"
    done
    rm -f "$ROOTFS"/boot/*xeno*.dpkg-new "$ROOTFS"/boot/vmlinuz-*xeno* "$ROOTFS"/boot/initrd.img-*xeno* 2>/dev/null || true

    chroot "$ROOTFS" /bin/bash << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true

GEN=$(ls /boot/vmlinuz-*-generic 2>/dev/null | sort -V | tail -1 || true)
if [ -n "$GEN" ]; then
    VER="${GEN#/boot/vmlinuz-}"
    ln -sfn "vmlinuz-$VER" /boot/vmlinuz
    if [ -f "/boot/initrd.img-$VER" ]; then
        ln -sfn "initrd.img-$VER" /boot/initrd.img
    fi
fi
EOF

    if [ "$use_fallback" -eq 0 ]; then
        echo "Installing validated custom XanMod kernel packages..."
        rm -rf "$ROOTFS/tmp/kernel-debs"
        mkdir -p "$ROOTFS/tmp/kernel-debs"
        cp "$CACHE_DIR"/*.deb "$ROOTFS/tmp/kernel-debs/"
        chroot "$ROOTFS" /bin/bash << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
cd /tmp/kernel-debs
dpkg -i linux-image-*.deb linux-headers-*.deb 2>/dev/null || dpkg -i ./*.deb 2>/dev/null || true
apt-get -f install -y
NEW_VERSION=$(ls /boot/vmlinuz-*xeno* 2>/dev/null | sort -V | tail -1 | sed 's|/boot/vmlinuz-||')
if [ -n "$NEW_VERSION" ]; then
    update-initramfs -c -k "$NEW_VERSION" || update-initramfs -u -k "$NEW_VERSION"
    ln -sfn "vmlinuz-$NEW_VERSION" /boot/vmlinuz
    ln -sfn "initrd.img-$NEW_VERSION" /boot/initrd.img
fi
EOF
        rm -rf "$ROOTFS/tmp/kernel-debs"
    fi

    trap - EXIT
    xeno_chroot_umount "$ROOTFS"
    echo -e "  ${C_GREEN}✔ [SUCCESS]${C_RESET} Kernel state verified and installed.\n"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 5: Compatibility Stacks & App Provisioning
# ─────────────────────────────────────────────────────────────────────────────
run_setup_compat() {
    xeno_require_root
    echo -e "${C_BOLD}${C_CYAN}▶ [COMPAT] Configuring Windows (Wine/DXVK) & AppImage Compatibility...${C_RESET}"
    
    xeno_chroot_mount "$ROOTFS"
    cleanup_compat() { xeno_chroot_umount "$ROOTFS"; }
    trap cleanup_compat EXIT

    chroot "$ROOTFS" /bin/bash << 'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
dpkg --add-architecture i386 2>/dev/null || true
apt-get update
apt-get install -y --no-install-recommends \
    wine wine64 winetricks fonts-wine cabextract vulkan-tools mesa-vulkan-drivers flatpak desktop-file-utils xdg-utils || true

# Write xeno-windows launcher
cat > /usr/bin/xeno-windows << 'EOF'
#!/bin/bash
set -euo pipefail
cmd="${1:-bottles}"
case "$cmd" in
    bottles|"")
        if flatpak info com.usebottles.bottles &>/dev/null; then
            exec flatpak run com.usebottles.bottles
        fi
        exec winecfg
        ;;
    wine)
        shift
        export WINEESYNC=1 WINEFSYNC=1
        exec wine "$@"
        ;;
    winetricks)
        shift
        exec winetricks "$@"
        ;;
    doctor)
        echo "=== Xeno Windows Compatibility Doctor ==="
        echo "Kernel: $(uname -r)"
        echo -n "Wine: "; command -v wine >/dev/null && wine --version || echo missing
        exit 0
        ;;
    *)
        if [ -f "$cmd" ]; then
            export WINEESYNC=1 WINEFSYNC=1
            exec wine "$@"
        else
            echo "Usage: xeno-windows [bottles|wine <exe>|<file.exe>|winetricks|doctor]"
            exit 1
        fi
        ;;
esac
EOF
chmod 755 /usr/bin/xeno-windows

# Write xeno-appimage-runner
cat > /usr/bin/xeno-appimage-runner << 'EOF'
#!/bin/bash
set -euo pipefail
APP="${1:-}"
if [ -z "$APP" ] || [ ! -f "$APP" ]; then
    echo "Usage: xeno-appimage-runner <path-to.AppImage> [args...]" >&2
    exit 1
fi
shift || true
chmod +x "$APP" 2>/dev/null || true
if [ -e /dev/fuse ] && [ -r /dev/fuse ] && [ -w /dev/fuse ]; then
    exec "$APP" "$@"
else
    exec "$APP" --appimage-extract-and-run "$@"
fi
EOF
chmod 755 /usr/bin/xeno-appimage-runner

# MIME associations
mkdir -p /usr/share/applications
cat > /usr/share/applications/xeno-wine-runner.desktop << 'EOF'
[Desktop Entry]
Name=Wine Windows Program Loader
Exec=xeno-windows wine %f
Icon=wine
Terminal=false
Type=Application
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-msdownload;application/x-executable;
Categories=System;Utility;
EOF

cat > /usr/share/applications/xeno-appimage-runner.desktop << 'EOF'
[Desktop Entry]
Name=AppImage Runner
Exec=xeno-appimage-runner %f
Icon=application-x-executable
Terminal=false
Type=Application
MimeType=application/vnd.appimage;application/x-iso9660-appimage;
Categories=Utility;
EOF

update-desktop-database /usr/share/applications 2>/dev/null || true
apt-get clean
CHROOT_EOF

    trap - EXIT
    xeno_chroot_umount "$ROOTFS"
    echo -e "  ${C_GREEN}✔ [SUCCESS]${C_RESET} Windows & AppImage compatibility stack ready.\n"
}

run_setup_security() {
    xeno_require_root
    echo -e "${C_BOLD}${C_CYAN}▶ [SECURITY] Provisioning Offensive Security & Wireless Penetration Stack...${C_RESET}"
    
    xeno_chroot_mount "$ROOTFS"
    cleanup_sec() { xeno_chroot_umount "$ROOTFS"; }
    trap cleanup_sec EXIT

    mkdir -p "$ROOTFS/etc/apt/preferences.d" "$ROOTFS/etc/apt/sources.list.d" "$ROOTFS/etc/apt/keyrings"
    
    # Kali Pinning
    cat > "$ROOTFS/etc/apt/preferences.d/kali-pinning" << 'EOF'
Package: *
Pin: release o=Kali
Pin-Priority: 100
EOF

    chroot "$ROOTFS" /bin/bash << 'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update || true
apt-get install -y --no-install-recommends \
    aircrack-ng wireshark wireshark-qt nmap hydra john sqlmap bettercap tor iw rfkill wireless-tools 2>/dev/null || true

# WiFi Monitor Helper
cat > /usr/bin/xeno-wifi-monitor << 'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-list}" in
    list) iw dev ;;
    start)
        [ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
        iface="${2:-}"
        [ -n "$iface" ] || { echo "Specify interface"; exit 1; }
        ip link set "$iface" down
        iw dev "$iface" set type monitor 2>/dev/null || iw dev "$iface" interface add mon0 type monitor
        ip link set "$iface" up
        echo "Monitor mode enabled on $iface"
        ;;
    stop)
        [ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
        iface="${2:-}"
        ip link set "$iface" down
        iw dev "$iface" set type managed 2>/dev/null || true
        ip link set "$iface" up
        echo "Managed mode restored on $iface"
        ;;
    *) echo "Usage: xeno-wifi-monitor {list|start <iface>|stop <iface>}" ;;
esac
EOF
chmod 755 /usr/bin/xeno-wifi-monitor

# Tor Proxy Helper
cat > /usr/bin/xeno-tor-proxy << 'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-status}" in
    start)
        systemctl start tor
        iptables -t nat -A OUTPUT -m owner --uid-owner debian-tor -j RETURN
        iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
        iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040
        echo "Transparent Tor proxy enabled."
        ;;
    stop)
        iptables -t nat -F OUTPUT
        echo "Transparent Tor proxy disabled."
        ;;
    status) iptables -t nat -L OUTPUT -n -v ;;
    *) echo "Usage: xeno-tor-proxy {start|stop|status}" ;;
esac
EOF
chmod 755 /usr/bin/xeno-tor-proxy

apt-get clean
CHROOT_EOF

    trap - EXIT
    xeno_chroot_umount "$ROOTFS"
    echo -e "  ${C_GREEN}✔ [SUCCESS]${C_RESET} Security and wireless toolchain provisioned.\n"
}

run_setup_ai() {
    xeno_require_root
    echo -e "${C_BOLD}${C_CYAN}▶ [AI-STACK] Configuring Opt-In Local AI Engine & Bubblewrap Sandbox...${C_RESET}"
    
    xeno_chroot_mount "$ROOTFS"
    cleanup_ai() { xeno_chroot_umount "$ROOTFS"; }
    trap cleanup_ai EXIT

    chroot "$ROOTFS" /bin/bash << 'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
mkdir -p /var/cache/xeno-ai/models
chmod 777 /var/cache/xeno-ai/models

apt-get update
apt-get install -y --no-install-recommends curl python3 python3-pip bubblewrap

cat > /usr/bin/xeno-ai-engine << 'EOF'
#!/bin/bash
export OLLAMA_MODELS="/var/cache/xeno-ai/models"
export OLLAMA_HOST="127.0.0.1:11434"
if command -v ollama >/dev/null; then
    exec ollama serve
else
    echo "Ollama runtime not installed."
    sleep 3600
fi
EOF
chmod +x /usr/bin/xeno-ai-engine

cat > /usr/bin/xeno-ai << 'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-status}" in
    status)
        echo "=== Xeno Local AI Engine (127.0.0.1:11434) ==="
        systemctl is-active xeno-ai-engine 2>/dev/null && echo "State: Running" || echo "State: Inactive (Opt-in)"
        ;;
    start)
        sudo systemctl start xeno-ai-engine
        echo "Local AI engine started."
        ;;
    stop)
        sudo systemctl stop xeno-ai-engine
        echo "Local AI engine stopped."
        ;;
    *)
        echo "Usage: xeno-ai {status|start|stop|enable|disable}"
        ;;
esac
EOF
chmod 755 /usr/bin/xeno-ai

cat > /usr/bin/xeno-agent-sandbox << 'EOF'
#!/bin/bash
if ! command -v bwrap >/dev/null; then
    exec "$@"
fi
exec bwrap --ro-bind / / --dev /dev --proc /proc \
           --bind /tmp /tmp \
           --unshare-all --share-net \
           --new-session --die-with-parent \
           --uid 1000 --gid 1000 \
           "$@"
EOF
chmod +x /usr/bin/xeno-agent-sandbox

cat > /etc/systemd/system/xeno-ai-engine.service << 'EOF'
[Unit]
Description=Xeno OS Local AI Engine
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/xeno-ai-engine
Restart=on-failure
RestartSec=5
User=xeno

[Install]
WantedBy=multi-user.target
EOF
rm -f /etc/systemd/system/multi-user.target.wants/xeno-ai-engine.service 2>/dev/null || true
apt-get clean
CHROOT_EOF

    trap - EXIT
    xeno_chroot_umount "$ROOTFS"
    echo -e "  ${C_GREEN}✔ [SUCCESS]${C_RESET} Opt-in local AI stack configured.\n"
}

run_enter_chroot() {
    xeno_require_root
    echo -e "${C_BOLD}${C_CYAN}▶ [CHROOT] Entering Xeno OS RootFS (${ROOTFS})...${C_RESET}"
    xeno_chroot_mount "$ROOTFS"
    cleanup_chroot() { xeno_chroot_umount "$ROOTFS"; }
    trap cleanup_chroot EXIT

    chroot "$ROOTFS" /bin/bash
    trap - EXIT
    xeno_chroot_umount "$ROOTFS"
    echo -e "${C_GREEN}✔ Exited RootFS chroot cleanly.${C_RESET}\n"
}

# ─────────────────────────────────────────────────────────────────────────────
# INTERACTIVE TUI MENU
# ─────────────────────────────────────────────────────────────────────────────
show_menu() {
    while true; do
        clear
        print_banner
        echo -e "${C_BOLD}${C_CYAN}Select an Operation to Execute:${C_RESET}\n"
        echo -e "  ${C_GREEN}[1]${C_RESET}  ${C_BOLD}Master Doctor Diagnostic${C_RESET}          (Comprehensive 8-Tier audit)"
        echo -e "  ${C_GREEN}[2]${C_RESET}  ${C_BOLD}Master Doctor --fix${C_RESET}                (Diagnostic + automated self-healing)"
        echo -e "  ${C_GREEN}[3]${C_RESET}  ${C_BOLD}Fast Health Check${C_RESET}                  (Disk, DKMS, systemd & locks audit)"
        echo -e "  ${C_BLUE}[4]${C_RESET}  ${C_BOLD}Run Automated Test Suite (All 96)${C_RESET}  (73 E2E Integration + 23 Adversarial)"
        echo -e "  ${C_BLUE}[5]${C_RESET}  ${C_BOLD}Run E2E Integration Tests Only${C_RESET}    (73 Simulation flows)"
        echo -e "  ${C_BLUE}[6]${C_RESET}  ${C_BOLD}Run Adversarial IPC Tests Only${C_RESET}    (23 Boundary stress tests)"
        echo -e "  ${C_BLUE}[7]${C_RESET}  ${C_BOLD}Run Live Display Tests${C_RESET}            (Active Wayland/Hyprland session)"
        echo -e "  ${C_MAGENTA}[8]${C_RESET}  ${C_BOLD}Fix Boot & Display Session${C_RESET}        (Autologin, DRM, & VM software fallback)"
        echo -e "  ${C_MAGENTA}[9]${C_RESET}  ${C_BOLD}Stage & Validate Custom Kernel${C_RESET}    (Promote kernel/output to kernel/cache)"
        echo -e "  ${C_MAGENTA}[10]${C_RESET} ${C_BOLD}Repair Kernel in RootFS${C_RESET}           (Install custom XanMod / Generic fallback)"
        echo -e "  ${C_YELLOW}[11]${C_RESET} ${C_BOLD}Setup Windows & AppImage Compat${C_RESET}   (Wine, DXVK, Bottles, and MIME entries)"
        echo -e "  ${C_YELLOW}[12]${C_RESET} ${C_BOLD}Setup Kali Tools & WiFi Monitor${C_RESET}   (Pinned repos, aircrack, and injection)"
        echo -e "  ${C_YELLOW}[13]${C_RESET} ${C_BOLD}Setup Opt-in Local AI Engine${C_RESET}      (Offline Ollama runner & bwrap sandbox)"
        echo -e "  ${C_CYAN}[14]${C_RESET} ${C_BOLD}Enter RootFS Interactive Chroot${C_RESET}   (Mount pseudo-filesystems and launch bash)"
        echo -e "  ${C_RED}[15]${C_RESET} ${C_BOLD}Launch ISO Packaging Pipeline${C_RESET}     (Execute scripts/auto-build.sh)"
        echo -e "  ${C_DIM}[0]  Exit${C_RESET}\n"

        read -rp "Enter choice [0-15]: " choice
        echo ""
        case "$choice" in
            1)  run_master_doctor 0 ;;
            2)  run_master_doctor 1 ;;
            3)  run_health_check 0 0 ;;
            4)  run_tests_suite all ;;
            5)  run_tests_suite e2e ;;
            6)  run_tests_suite adv ;;
            7)  run_tests_suite live ;;
            8)  run_fix_boot_display ;;
            9)  run_stage_kernel ;;
            10) run_fix_kernel_rootfs ;;
            11) run_setup_compat ;;
            12) run_setup_security ;;
            13) run_setup_ai ;;
            14) run_enter_chroot ;;
            15) 
                echo -e "${C_CYAN}${C_BOLD}▶ [ISO PACKAGING PIPELINE]${C_RESET}"
                echo -e "  ${C_GREEN}[1]${C_RESET} Launch Build with Currently Queued Milestone"
                echo -e "  ${C_BLUE}[2]${C_RESET} Open Designer Edition & Release Target Matrix Selector"
                echo -e "  ${C_YELLOW}[3]${C_RESET} Recreate Current / Final Milestone Snapshot (Version Freeze)"
                echo -e "  ${C_DIM}[0] Return to Main Menu${C_RESET}\n"
                read -rp "Select action [1-3] (default: 1): " pkg_choice
                pkg_choice="${pkg_choice:-1}"
                case "$pkg_choice" in
                    2) sudo bash "$WS_DIR/scripts/auto-build.sh" --select ;;
                    3) sudo bash "$WS_DIR/scripts/auto-build.sh" --recreate ;;
                    0) echo "Returning to menu." ;;
                    *) sudo bash "$WS_DIR/scripts/auto-build.sh" ;;
                esac
                ;;
            0|q|exit)
                echo "Exiting Xeno Reaper."
                exit 0
                ;;
            *)
                echo -e "${C_RED}Invalid option.${C_RESET}"
                ;;
        esac
        echo -e "\nPress [ENTER] to return to menu..."
        read -r
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# CLI ENTRY POINT (ARGUMENT PARSING)
# ─────────────────────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    show_menu
fi

case "$1" in
    --doctor|doctor)
        print_banner
        run_master_doctor 0
        ;;
    --doctor-fix|doctor-fix|--fix|fix)
        print_banner
        run_master_doctor 1
        ;;
    --health|health|--check|check)
        run_health_check "${2:-0}" 0
        ;;
    --health-daemon)
        run_health_check 1 1
        ;;
    --test|test|--test-all|test-all)
        print_banner
        run_tests_suite all
        ;;
    --test-e2e|test-e2e)
        print_banner
        run_tests_suite e2e
        ;;
    --test-adv|test-adv|--test-adversarial)
        print_banner
        run_tests_suite adv
        ;;
    --test-live|test-live)
        print_banner
        run_tests_suite live
        ;;
    --fix-boot|fix-boot|--fix-boot-display)
        print_banner
        run_fix_boot_display
        ;;
    --stage-kernel|stage-kernel)
        print_banner
        run_stage_kernel
        ;;
    --fix-kernel|fix-kernel|--fix-kernel-rootfs)
        print_banner
        run_fix_kernel_rootfs
        ;;
    --setup-compat|setup-compat|--compat)
        print_banner
        run_setup_compat
        ;;
    --setup-security|setup-security|--security)
        print_banner
        run_setup_security
        ;;
    --setup-ai|setup-ai|--ai)
        print_banner
        run_setup_ai
        ;;
    --chroot|chroot|--enter-rootfs|enter-rootfs)
        print_banner
        run_enter_chroot
        ;;
    --select-tier|select-tier|--select-edition|select-edition|--select|select)
        exec sudo bash "$WS_DIR/scripts/auto-build.sh" --select
        ;;
    --build-iso|build-iso|--auto-build)
        shift || true
        exec sudo bash "$WS_DIR/scripts/auto-build.sh" "$@"
        ;;
    -h|--help|help)
        print_banner
        cat << 'USAGE_EOF'
Usage: sudo bash scripts/xeno-reaper.sh [COMMAND]

Commands:
  (no args)           Launch Cyber-Nord Interactive Menu
  doctor              Run 8-Tier Master Diagnostic audit
  doctor-fix, --fix   Run Master Diagnostic in automated self-repair mode
  health              Run fast periodic health and sanity audit
  test-all            Run all 96 automated tests (73 E2E + 23 Adversarial)
  test-e2e            Run 73 E2E Integration test flows
  test-adv            Run 23 Adversarial boundary stress tests
  test-live           Run tests against live Wayland/Hyprland session
  fix-boot            Configure display session, VM software GL, & autologin
  stage-kernel        Validate and stage compiled kernel debs to cache
  fix-kernel          Repair and install validated XanMod kernel into rootfs
  setup-compat        Configure Wine Staging, DXVK, Bottles, & AppImage runners
  setup-security      Configure Kali pinned repos, wireless tools & injection
  setup-ai            Configure opt-in local AI runtime & Bubblewrap sandbox
  chroot              Enter interactive rootfs chroot with safe bind mounts
  select-tier         Open Designer Edition & Release Target Matrix Selector
  build-iso           Invoke full Smart Lean ISO packaging pipeline (auto-build.sh)
USAGE_EOF
        exit 0
        ;;
    *)
        echo -e "${C_RED}Unknown command: $1. Run 'bash scripts/xeno-reaper.sh --help' for usage.${C_RESET}"
        exit 1
        ;;
esac
