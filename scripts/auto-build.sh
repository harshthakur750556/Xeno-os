#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#   ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ ─█▀▀█ ░█▀▀█ ░█▀▀▀ ░█▀▀█ 
#   ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█▄▄▀ ░█▀▀▀ ░█▄▄█ ░█▄▄█ ░█▀▀▀ ░█▄▄▀ 
#   ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█─░█ ░█▄▄▄ ░█──█ ░█─── ░█▄▄▄ ░█─░█ 
# ═══════════════════════════════════════════════════════════════════════════════
#  XENO OS — Smart Lean Automated ISO Packaging & Build Pipeline
#  Dual BIOS/UEFI Level 3 GRUB Master Engine with ZSTD L19 SquashFS Compression
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.bun/bin:/home/xeno/.bun/bin:${PATH:-}"
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$WS_DIR/iso/version.txt"
mkdir -p "$WS_DIR/iso"

BUILD_VERSION="10.0-beta"
ACTIVE_TIER="BETA"

BETA_VERSION="10.0-beta"
BETA_STATUS="TARGET_READY"
BETA_BUILT=0
BETA_PROGRESS=100
BETA_LAST_BUILD="NONE"
BETA_ISO="xeno_os-10.0-beta.iso"

ALPHA_VERSION="0.0-alpha"
ALPHA_STATUS="UNINITIALIZED"
ALPHA_BUILT=0
ALPHA_PROGRESS=0
ALPHA_LAST_BUILD="NONE"
ALPHA_ISO="NONE"

OMEGA_VERSION="0.0-omega"
OMEGA_STATUS="UNINITIALIZED"
OMEGA_BUILT=0
OMEGA_PROGRESS=0
OMEGA_LAST_BUILD="NONE"
OMEGA_ISO="NONE"

LAST_BUILD_TIMESTAMP="NONE"
LAST_BUILD_TIER="NONE"
LAST_BUILD_ISO="NONE"
LAST_BUILD_SIZE="0B"
LAST_BUILD_SHA256="NONE"

WIN_HOST_DIR="/mnt/c/Users/harsh"
TIER_NAME="BETA VERSION"
ISO_NAME="xeno_os-${BUILD_VERSION}.iso"
OUTPUT_DIR="$WS_DIR/iso/output/$TIER_NAME"
TARGET_ISO="$OUTPUT_DIR/${ISO_NAME}"

load_version_manifest() {
    if [ -f "$VERSION_FILE" ]; then
        while IFS="=" read -r key val || [ -n "$key" ]; do
            key=$(echo "$key" | tr -d "[:space:]")
            val=$(echo "$val" | tr -d "[:space:]")
            [[ "$key" =~ ^#.*$ ]] && continue
            [ -z "$key" ] && continue
            case "$key" in
                ACTIVE_VERSION) BUILD_VERSION="$val" ;;
                ACTIVE_TIER) ACTIVE_TIER="$val" ;;
                BETA_VERSION) BETA_VERSION="$val" ;;
                BETA_STATUS) BETA_STATUS="$val" ;;
                BETA_BUILT) BETA_BUILT="$val" ;;
                BETA_PROGRESS) BETA_PROGRESS="$val" ;;
                ALPHA_VERSION) ALPHA_VERSION="$val" ;;
                ALPHA_STATUS) ALPHA_STATUS="$val" ;;
                ALPHA_BUILT) ALPHA_BUILT="$val" ;;
                ALPHA_PROGRESS) ALPHA_PROGRESS="$val" ;;
                OMEGA_VERSION) OMEGA_VERSION="$val" ;;
                OMEGA_STATUS) OMEGA_STATUS="$val" ;;
                OMEGA_BUILT) OMEGA_BUILT="$val" ;;
                OMEGA_PROGRESS) OMEGA_PROGRESS="$val" ;;
                LAST_BUILD_TIMESTAMP) LAST_BUILD_TIMESTAMP="$val" ;;
                LAST_BUILD_TIER) LAST_BUILD_TIER="$val" ;;
                LAST_BUILD_ISO) LAST_BUILD_ISO="$val" ;;
                LAST_BUILD_SIZE) LAST_BUILD_SIZE="$val" ;;
                LAST_BUILD_SHA256) LAST_BUILD_SHA256="$val" ;;
            esac
        done < "$VERSION_FILE"
    fi
}

save_version_manifest() {
    cat > "$VERSION_FILE" << MANIFEST_EOF
# ═══════════════════════════════════════════════════════════════════════════════
#  XENO OS — VERSION & RELEASE TARGET METADATA MANIFEST
# ═══════════════════════════════════════════════════════════════════════════════
ACTIVE_VERSION=${BUILD_VERSION}
ACTIVE_TIER=${ACTIVE_TIER}

# Tier 1: Beta Edition (Release Candidate Channel)
BETA_VERSION=${BETA_VERSION}
BETA_STATUS=${BETA_STATUS}
BETA_BUILT=${BETA_BUILT}
BETA_PROGRESS=${BETA_PROGRESS}
BETA_LAST_BUILD=${BETA_LAST_BUILD:-NONE}
BETA_ISO=${BETA_ISO:-NONE}

# Tier 2: Alpha Edition (Experimental Rolling Canary Channel)
ALPHA_VERSION=${ALPHA_VERSION}
ALPHA_STATUS=${ALPHA_STATUS}
ALPHA_BUILT=${ALPHA_BUILT}
ALPHA_PROGRESS=${ALPHA_PROGRESS}
ALPHA_LAST_BUILD=${ALPHA_LAST_BUILD:-NONE}
ALPHA_ISO=${ALPHA_ISO:-NONE}

# Tier 3: Omega Edition (Sovereign Gold Master Production Channel)
OMEGA_VERSION=${OMEGA_VERSION}
OMEGA_STATUS=${OMEGA_STATUS}
OMEGA_BUILT=${OMEGA_BUILT}
OMEGA_PROGRESS=${OMEGA_PROGRESS}
OMEGA_LAST_BUILD=${OMEGA_LAST_BUILD:-NONE}
OMEGA_ISO=${OMEGA_ISO:-NONE}

# Release Artifact Telemetry Audit
LAST_BUILD_TIMESTAMP=${LAST_BUILD_TIMESTAMP:-NONE}
LAST_BUILD_TIER=${LAST_BUILD_TIER:-NONE}
LAST_BUILD_ISO=${LAST_BUILD_ISO:-NONE}
LAST_BUILD_SIZE=${LAST_BUILD_SIZE:-0B}
LAST_BUILD_SHA256=${LAST_BUILD_SHA256:-NONE}
MANIFEST_EOF
}

audit_and_sync_manifest() {
    load_version_manifest

    # Audit on-disk ISO artifacts
    if ls "$WS_DIR/iso/output/BETA VERSION"/xeno_os-*.iso >/dev/null 2>&1; then
        BETA_BUILT=1
        BETA_STATUS="BUILT"
        BETA_PROGRESS=100
        BETA_ISO=$(basename "$(ls -t "$WS_DIR/iso/output/BETA VERSION"/xeno_os-*.iso | head -n1)")
    else
        BETA_BUILT=0
        BETA_STATUS="TARGET_READY"
        BETA_PROGRESS=100
    fi

    if ls "$WS_DIR/iso/output/ALPHA VERSION"/xeno_os-*.iso >/dev/null 2>&1; then
        ALPHA_BUILT=1
        ALPHA_STATUS="BUILT"
        ALPHA_PROGRESS=100
        ALPHA_ISO=$(basename "$(ls -t "$WS_DIR/iso/output/ALPHA VERSION"/xeno_os-*.iso | head -n1)")
    else
        ALPHA_BUILT=0
        if [ "$ALPHA_VERSION" = "0.0-alpha" ]; then
            ALPHA_STATUS="UNINITIALIZED"
            ALPHA_PROGRESS=0
        fi
    fi

    if ls "$WS_DIR/iso/output/OMEGA VERSION"/xeno_os-*.iso >/dev/null 2>&1; then
        OMEGA_BUILT=1
        OMEGA_STATUS="BUILT"
        OMEGA_PROGRESS=100
        OMEGA_ISO=$(basename "$(ls -t "$WS_DIR/iso/output/OMEGA VERSION"/xeno_os-*.iso | head -n1)")
    else
        OMEGA_BUILT=0
        if [ "$OMEGA_VERSION" = "0.0-omega" ]; then
            OMEGA_STATUS="UNINITIALIZED"
            OMEGA_PROGRESS=0
        fi
    fi
}

resolve_tier_and_iso() {
    if [[ "$BUILD_VERSION" =~ beta|BETA ]]; then
        ACTIVE_TIER="BETA"
        TIER_NAME="BETA VERSION"
        ISO_NAME="xeno_os-${BUILD_VERSION}.iso"
    elif [[ "$BUILD_VERSION" =~ omega|OMEGA ]]; then
        ACTIVE_TIER="OMEGA"
        TIER_NAME="OMEGA VERSION"
        ISO_NAME="xeno_os-${BUILD_VERSION}.iso"
    else
        ACTIVE_TIER="ALPHA"
        TIER_NAME="ALPHA VERSION"
        ISO_NAME="xeno_os-${BUILD_VERSION}-alpha.iso"
    fi
    OUTPUT_DIR="$WS_DIR/iso/output/$TIER_NAME"
    TARGET_ISO="$OUTPUT_DIR/${ISO_NAME}"
}

audit_and_sync_manifest
resolve_tier_and_iso

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

# Render graphical progress/usage bar
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

# ── Designer Edition Matrix Selector (Alpha / Beta / Omega / Recreate) ───────
render_edition_selector() {
    clear
    echo -e "${C_CYAN}${C_BOLD}"
    cat << 'SELECTOR_BANNER_EOF'
 ░█▀▀▀ ░█▀▀▄ ░█ ▀▀█▀▀ ░█ ░█▀▀█ ░█▄─░█   ░█▀▄▀█ ─█▀▀█ ▀▀█▀▀ ░█▀▀█ ░█ ░█──░█ 
 ░█▀▀▀ ░█─░█ ░█ ─░█── ░█ ░█──█ ░█░█░█   ░█░█░█ ░█▄▄█ ─░█── ░█▄▄▀ ░█ ─░█░█─ 
 ░█▄▄▄ ░█▄▄▀ ░█ ─░█── ░█ ░█▄▄█ ░█──▀█   ░█──░█ ░█──█ ─░█── ░█─░█ ░█ ░█──░█ 
SELECTOR_BANNER_EOF
    echo -e "${C_BLUE} ═══ XENO OS EDITION & RELEASE TARGET MATRIX ═══${C_RESET}\n"

    audit_and_sync_manifest
    resolve_tier_and_iso

    local current_tier_badge="$C_GREEN[ BETA ]$C_RESET"
    local current_stability="$(render_bar "$BETA_PROGRESS" 100 16 "$C_GREEN")"
    if [[ "$BUILD_VERSION" =~ omega|OMEGA ]]; then
        current_tier_badge="$C_MAGENTA[ OMEGA ]$C_RESET"
        current_stability="$(render_bar "$OMEGA_PROGRESS" 100 16 "$C_MAGENTA")"
    elif [[ "$BUILD_VERSION" =~ alpha|ALPHA ]]; then
        current_tier_badge="$C_BLUE[ ALPHA ]$C_RESET"
        current_stability="$(render_bar "$ALPHA_PROGRESS" 100 16 "$C_BLUE")"
    fi

    echo -e "${C_DIM}┌─────────────────────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_DIM}│${C_RESET} ${C_BOLD}${C_CYAN}CURRENT ACTIVE TARGET MILESTONE${C_RESET}"
    echo -e "${C_DIM}├─────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_BOLD}Active Version:${C_RESET}    ${BUILD_VERSION} ${current_tier_badge}"
    echo -e "${C_DIM}│${C_RESET}  ${C_BOLD}Milestone Scope:${C_RESET}   ${current_stability}"
    echo -e "${C_DIM}│${C_RESET}  ${C_BOLD}Release Target:${C_RESET}    ${C_DIM}iso/output/${TIER_NAME}/${ISO_NAME}${C_RESET}"
    echo -e "${C_DIM}├─────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
    echo -e "${C_DIM}│${C_RESET} ${C_BOLD}Select Release Channel or Milestone Action:${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_GREEN}[1]${C_RESET} ${C_BOLD}BETA EDITION${C_RESET}    $(render_bar "$BETA_PROGRESS" 100 14 "$C_GREEN") ${C_DIM}(v10.0-beta Target Ready)${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}      ${C_DIM}Standard Release Candidate Pipeline (Feature-Complete Channel)${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_BLUE}[2]${C_RESET} ${C_BOLD}ALPHA EDITION${C_RESET}   $(render_bar "$ALPHA_PROGRESS" 100 14 "$C_BLUE") ${C_DIM}($([ "$ALPHA_BUILT" = "1" ] && echo "Active Canary: $ALPHA_VERSION" || echo "Uninitialized - Not Started"))${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}      ${C_DIM}Experimental Rolling Canary Substrate (Cutting-Edge Development)${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_MAGENTA}[3]${C_RESET} ${C_BOLD}OMEGA EDITION${C_RESET}   $(render_bar "$OMEGA_PROGRESS" 100 14 "$C_MAGENTA") ${C_DIM}($([ "$OMEGA_BUILT" = "1" ] && echo "Production Gold Master: $OMEGA_VERSION" || echo "Uninitialized - Not Started"))${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}      ${C_DIM}Sovereign Master Production Gold Image (Ultimate Release Channel)${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_YELLOW}[4]${C_RESET} ${C_BOLD}RECREATE ISO${C_RESET}    ${C_YELLOW}[SNAPSHOT FREEZE]${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}      ${C_DIM}Re-package current milestone (${BUILD_VERSION}) without incrementing${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_CYAN}[5]${C_RESET} ${C_BOLD}CUSTOM VERSION${C_RESET}  ${C_CYAN}[MANUAL TAG]${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}      ${C_DIM}Specify manual semantic versioning string (e.g. 10.0-beta, 1.0-omega)${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_TEXT}[6] PROCEED WITH CURRENT ACTIVE (${BUILD_VERSION})${C_RESET}"
    echo -e "${C_DIM}│${C_RESET}  ${C_DIM}[0] CANCEL AND EXIT${C_RESET}"
    echo -e "${C_DIM}└─────────────────────────────────────────────────────────────────────────────┘${C_RESET}\n"

    read -rp "Enter selection [0-6] (default: 6): " ed_choice
    ed_choice="${ed_choice:-6}"
    
    case "$ed_choice" in
        1)
            BUILD_VERSION="10.0-beta"
            ACTIVE_TIER="BETA"
            BETA_VERSION="10.0-beta"
            BETA_STATUS="ACTIVE_TARGET"
            BETA_PROGRESS=100
            resolve_tier_and_iso
            save_version_manifest
            echo -e "  ${C_GREEN}✔ Shifted to Beta Edition: ${BUILD_VERSION}${C_RESET}\n"
            ;;
        2)
            if [ "$ALPHA_VERSION" = "0.0-alpha" ]; then
                ALPHA_VERSION="1.0-alpha"
                ALPHA_STATUS="INITIALIZED"
                ALPHA_PROGRESS=10
            fi
            BUILD_VERSION="$ALPHA_VERSION"
            ACTIVE_TIER="ALPHA"
            resolve_tier_and_iso
            save_version_manifest
            echo -e "  ${C_BLUE}✔ Shifted to Alpha Edition: ${BUILD_VERSION}${C_RESET}\n"
            ;;
        3)
            if [ "$OMEGA_VERSION" = "0.0-omega" ]; then
                OMEGA_VERSION="1.0-omega"
                OMEGA_STATUS="INITIALIZED"
                OMEGA_PROGRESS=100
            fi
            BUILD_VERSION="$OMEGA_VERSION"
            ACTIVE_TIER="OMEGA"
            resolve_tier_and_iso
            save_version_manifest
            echo -e "  ${C_MAGENTA}✔ Shifted to Omega Edition: ${BUILD_VERSION}${C_RESET}\n"
            ;;
        4)
            export XENO_RECREATE_ISO=1
            resolve_tier_and_iso
            echo -e "  ${C_YELLOW}✔ Recreating active milestone snapshot: ${BUILD_VERSION} (version freeze enabled)${C_RESET}\n"
            ;;
        5)
            read -rp "Enter target version string (e.g. 10.0-beta, 1.0-omega, 9.5-beta): " custom_ver
            if [ -n "$custom_ver" ]; then
                BUILD_VERSION=$(echo "$custom_ver" | tr -d '[:space:]')
                resolve_tier_and_iso
                save_version_manifest
                echo -e "  ${C_CYAN}✔ Target version set to: ${BUILD_VERSION}${C_RESET}\n"
            fi
            ;;
        6)
            resolve_tier_and_iso
            save_version_manifest
            echo -e "  ${C_GREEN}✔ Proceeding with currently active milestone: ${BUILD_VERSION}${C_RESET}\n"
            ;;
        0|q|cancel)
            echo -e "  ${C_YELLOW}Packaging cancelled by user.${C_RESET}"
            exit 0
            ;;
        *)
            resolve_tier_and_iso
            save_version_manifest
            echo -e "  ${C_YELLOW}Continuing with active milestone: ${BUILD_VERSION}${C_RESET}\n"
            ;;
    esac
}

# ── Argument Handling & Tier Configuration ──────────────────────────────────
INTERACTIVE_SELECT=1
for arg in "${@:-}"; do
    case "$arg" in
        --select|--interactive|-i)
            INTERACTIVE_SELECT=1
            ;;
        --batch|--non-interactive|-y|--yes)
            INTERACTIVE_SELECT=0
            ;;
        --beta|--tier-beta)
            BUILD_VERSION="10.0-beta"
            ACTIVE_TIER="BETA"
            resolve_tier_and_iso
            save_version_manifest
            INTERACTIVE_SELECT=0
            ;;
        --alpha|--tier-alpha)
            if [ "$ALPHA_VERSION" = "0.0-alpha" ]; then
                ALPHA_VERSION="1.0-alpha"
                ALPHA_STATUS="INITIALIZED"
                ALPHA_PROGRESS=10
            fi
            BUILD_VERSION="$ALPHA_VERSION"
            ACTIVE_TIER="ALPHA"
            resolve_tier_and_iso
            save_version_manifest
            INTERACTIVE_SELECT=0
            ;;
        --omega|--tier-omega)
            if [ "$OMEGA_VERSION" = "0.0-omega" ]; then
                OMEGA_VERSION="1.0-omega"
                OMEGA_STATUS="INITIALIZED"
                OMEGA_PROGRESS=100
            fi
            BUILD_VERSION="$OMEGA_VERSION"
            ACTIVE_TIER="OMEGA"
            resolve_tier_and_iso
            save_version_manifest
            INTERACTIVE_SELECT=0
            ;;
        --recreate|--rebuild|--recreate-beta)
            export XENO_RECREATE_ISO=1
            resolve_tier_and_iso
            INTERACTIVE_SELECT=0
            ;;
        --version=*|--ver=*)
            BUILD_VERSION="${arg#*=}"
            resolve_tier_and_iso
            save_version_manifest
            INTERACTIVE_SELECT=0
            ;;
    esac
done

if [ "$INTERACTIVE_SELECT" -eq 1 ] && [ "$IS_TTY" -eq 1 ]; then
    render_edition_selector
fi

resolve_tier_and_iso
mkdir -p "$OUTPUT_DIR" "$WS_DIR/iso/output/BETA VERSION"

# Clean up all older ISO and SHA256 versions across WSL & Windows host across all tiers
find "$WS_DIR/iso/output" -maxdepth 2 \( -name "xeno_os*.iso*" -o -name "xeno_os*.sha256" \) ! -name "${ISO_NAME}*" -delete 2>/dev/null || true
if [ -d "$WIN_HOST_DIR" ]; then
    mkdir -p "$WIN_HOST_DIR/$TIER_NAME" "$WIN_HOST_DIR/BETA VERSION" 2>/dev/null || true
    find "$WIN_HOST_DIR" -maxdepth 2 \( -name "xeno_os*.iso*" -o -name "xeno_os*.sha256" \) ! -name "${ISO_NAME}*" -delete 2>/dev/null || true
fi
ROOTFS="$WS_DIR/rootfs"
CACHE_DIR="$WS_DIR/kernel/cache"
META_FILE="$CACHE_DIR/latest_release.json"
VOLUME_ID="XENOOS"

export WS_DIR ROOTFS CACHE_DIR META_FILE VOLUME_ID OUTPUT_DIR TARGET_ISO WIN_HOST_DIR TIER_NAME ISO_NAME BUILD_VERSION
ACTUAL_USER="${SUDO_USER:-xeno}"
export ACTUAL_USER

# ── Pipeline Time Profiling & Master Progress Configuration ────────────────
TOTAL_ESTIMATED_SECS=250
CURRENT_STAGE=1

STAGE_EST_SECS=(0 6 10 6 15 25 45 90 15 38)
STAGE_CUMULATIVE_SECS=(0 0 6 16 22 37 62 107 197 212 250)
STAGE_TITLES=(
    ""
    "Boot Display & Hyprland VM Graphics Fallback"
    "GitHub Authentication & Kernel Rollout Audit"
    "Custom Kernel Package WLAN/Injection Validation Gate"
    "Custom XanMod Kernel RootFS Deployment"
    "Desktop Environment & Universal Application Stacks"
    "Casper Live Boot Stack & ZRAM Generator Setup"
    "RootFS Optimization & Smart ZSTD Level 19 SquashFS"
    "Hybrid Dual Bootloader Assembly (BIOS + UEFI)"
    "Master ISO Image Generation & Host Delivery"
)

# Live Telemetry Snapshot Box
render_telemetry_dashboard() {
    local cpu_usage=0
    if [ -f /proc/stat ]; then
        local cpu_idle
        cpu_idle=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1 || echo 85)
        cpu_usage=$(( 100 - ${cpu_idle:-85} ))
        [ "$cpu_usage" -lt 0 ] && cpu_usage=0
        [ "$cpu_usage" -gt 100 ] && cpu_usage=100
    fi

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

# Dynamic Pipeline Topology Node Graph
render_node_graph() {
    local cur_stage="$1"
    local fmt_node
    fmt_node() {
        local num="$1" name="$2"
        if [ "$num" -lt "$cur_stage" ]; then
            printf "${C_GREEN}[✔ %s]${C_RESET}" "$name"
        elif [ "$num" -eq "$cur_stage" ]; then
            printf "${C_BOLD}${C_YELLOW}[▶ %s]${C_RESET}" "$name"
        else
            printf "${C_DIM}[░ %s]${C_RESET}" "$name"
        fi
    }
    local arrow="${C_CYAN}──▶${C_RESET}"
    local n1 n2 n3 n4 n5 n6 n7 n8 n9
    n1=$(fmt_node 1 "S1:ENV")
    n2=$(fmt_node 2 "S2:ROOTFS")
    n3=$(fmt_node 3 "S3:REPOS")
    n4=$(fmt_node 4 "S4:KERNEL")
    n5=$(fmt_node 5 "S5:STACKS")
    n6=$(fmt_node 6 "S6:CASPER")
    n7=$(fmt_node 7 "S7:SQUASH")
    n8=$(fmt_node 8 "S8:BOOT")
    n9=$(fmt_node 9 "S9:ISO")

    echo -e "${C_DIM}┌─────────────────────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_DIM}│${C_RESET} ${C_BOLD}${C_CYAN}PIPELINE TOPOLOGY & REAL-TIME ACTIVE EXECUTION NODES${C_RESET}                       ${C_DIM}│${C_RESET}"
    echo -e "${C_DIM}├─────────────────────────────────────────────────────────────────────────────┤${C_RESET}"
    echo -e "  ${n1} ${arrow} ${n2} ${arrow} ${n3} ${arrow} ${n4}"
    echo -e "       ${C_CYAN}│${C_RESET}"
    echo -e "       ${C_CYAN}▼${C_RESET}"
    echo -e "  ${n5} ${arrow} ${n6} ${arrow} ${n7} ${arrow} ${n8} ${arrow} ${n9}"
    echo -e "${C_DIM}└─────────────────────────────────────────────────────────────────────────────┘${C_RESET}"
}

# Dynamic Master Progress Bar & Stage Header
render_stage_progress() {
    local stage="$1"
    CURRENT_STAGE="$stage"
    local now
    now=$(date +%s)
    local total_elapsed=$(( now - BUILD_START_TIME ))
    local total_mins=$(( total_elapsed / 60 ))
    local total_secs=$(( total_elapsed % 60 ))
    
    local est_secs_up_to_stage=${STAGE_CUMULATIVE_SECS[$stage]}
    local pct=$(( est_secs_up_to_stage * 100 / TOTAL_ESTIMATED_SECS ))
    [ "$pct" -gt 100 ] && pct=100
    [ "$pct" -lt 0 ] && pct=0
    
    local remaining_est=$(( TOTAL_ESTIMATED_SECS - total_elapsed ))
    [ "$remaining_est" -lt 0 ] && remaining_est=0
    local rem_mins=$(( remaining_est / 60 ))
    local rem_secs=$(( remaining_est % 60 ))
    
    local bar
    bar=$(render_bar "$pct" 100 28 "$C_CYAN")
    
    echo -e "\n${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}  STAGE [${stage}/9]: ${STAGE_TITLES[$stage]}${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    if [ "$IS_TTY" -eq 1 ]; then
        printf "  ${C_BOLD}Master Progress:${C_RESET} %b  ${C_DIM}│ Elapsed: [%02d:%02d] │ Est. Remaining: [%02d:%02d]${C_RESET}\n" "$bar" "$total_mins" "$total_secs" "$rem_mins" "$rem_secs"
        echo -e "  ${C_DIM}Stage Target Time: ~${STAGE_EST_SECS[$stage]}s | Total Pipeline Target: ~${TOTAL_ESTIMATED_SECS}s (~$(( TOTAL_ESTIMATED_SECS / 60 ))m $(( TOTAL_ESTIMATED_SECS % 60 ))s)${C_RESET}"
        render_node_graph "$stage"
    fi
}

# ── Real-Time Live Synchronized Output Streaming Engine ──────────────────────
run_with_spinner() {
    local label="$1"
    local stage_est="${2:-15}"
    shift 2

    local stage_num="$CURRENT_STAGE"
    local stage_base_secs=${STAGE_CUMULATIVE_SECS[$CURRENT_STAGE]}
    local build_start="$BUILD_START_TIME"
    local total_est="$TOTAL_ESTIMATED_SECS"
    local stage_start
    stage_start=$(date +%s)

    local now
    now=$(date +%s)
    local initial_master_pct=$(( stage_base_secs * 100 / total_est ))
    [ "$initial_master_pct" -gt 100 ] && initial_master_pct=100
    local m_bar
    m_bar=$(render_bar "$initial_master_pct" 100 16 "$C_CYAN")

    echo -e "\n  ${C_CYAN}──▶ [Stage ${stage_num}/9]${C_RESET} ${C_BOLD}${label}${C_RESET} ${C_DIM}(target: ~${stage_est}s)${C_RESET}"
    printf "  ${C_DIM}Master Progress: [%b] %3d%% │ Target: ~%02ds${C_RESET}\n" "$m_bar" "$initial_master_pct" "$stage_est"
    echo -e "${C_DIM}  ─────────────────────────────────────────────────────────────────────────────${C_RESET}"

    # Execute directly in bash environment, piping stdout/stderr into Python unbuffered real-time sync streamer
    local rc=0
    "$@" 2>&1 | python3 -u -c '
import sys, time, re

stage_num = int(sys.argv[1])
stage_est = int(sys.argv[2])
stage_base_secs = int(sys.argv[3])
build_start = int(sys.argv[4])
total_est = int(sys.argv[5])

stage_start = time.time()

C_RESET = "\033[0m"
C_CYAN = "\033[38;2;136;192;208m"
C_BLUE = "\033[38;2;129;161;193m"
C_GREEN = "\033[38;2;163;190;140m"
C_YELLOW = "\033[38;2;235;203;139m"
C_MAGENTA = "\033[38;2;180;142;173m"
C_DIM = "\033[2m"
C_BOLD = "\033[1m"

def render_bar(val, max_val=100, width=14, color=C_GREEN):
    val = max(0, min(max_val, val))
    filled = int(val * width / max_val) if max_val > 0 else 0
    empty = max(0, width - filled)
    return f"{color}{chr(9608)*filled}{C_DIM}{chr(9617)*empty}{C_RESET} {val:3d}%"

buf = ""
while True:
    try:
        chunk = sys.stdin.read(1)
    except Exception:
        break
    if not chunk:
        if buf.strip():
            raw = buf.strip()
            now = time.time()
            t_elapsed = int(now - build_start)
            t_min, t_sec = divmod(t_elapsed, 60)
            master_pct = min(99, int(((stage_base_secs + min(int(now - stage_start), stage_est)) / total_est) * 100)) if total_est > 0 else 0
            prefix = f"  {C_DIM}[{C_CYAN}{t_min:02d}:{t_sec:02d}{C_DIM} │ {C_BOLD}{master_pct:2d}%{C_DIM} │ {C_BLUE}S{stage_num}{C_DIM}]{C_RESET} "
            print(prefix + raw)
            sys.stdout.flush()
        break
    
    if chunk in ("\r", "\n"):
        raw = buf.strip()
        buf = ""
        if not raw:
            continue
        
        now = time.time()
        t_elapsed = int(now - build_start)
        s_elapsed = int(now - stage_start)
        t_min, t_sec = divmod(t_elapsed, 60)
        
        sq_match = re.search(r"(\d+)/(\d+)\s+(\d+)%", raw)
        xo_match = re.search(r"UPDATE\s*:\s*(\d+)\s+of\s+(\d+)\s+blocks.*?\((\d+)%\)", raw)
        
        if sq_match:
            cur_f, tot_f, sq_pct = int(sq_match.group(1)), int(sq_match.group(2)), int(sq_match.group(3))
            sub_bar = render_bar(sq_pct, 100, 14, C_GREEN)
            prefix = f"  {C_DIM}[{C_CYAN}{t_min:02d}:{t_sec:02d}{C_DIM} │ {C_BOLD}{sq_pct:2d}%{C_DIM} │ {C_BLUE}S{stage_num}{C_DIM}]{C_RESET} "
            msg = f"{C_BOLD}{C_GREEN}⟪SQUASHFS ZSTD L19⟫{C_RESET} {sub_bar} {C_DIM}({cur_f:,}/{tot_f:,} files compressed){C_RESET}"
            print(prefix + msg)
        elif xo_match:
            cur_b, tot_b, xo_pct = int(xo_match.group(1)), int(xo_match.group(2)), int(xo_match.group(3))
            sub_bar = render_bar(xo_pct, 100, 14, C_MAGENTA)
            prefix = f"  {C_DIM}[{C_CYAN}{t_min:02d}:{t_sec:02d}{C_DIM} │ {C_BOLD}{xo_pct:2d}%{C_DIM} │ {C_BLUE}S{stage_num}{C_DIM}]{C_RESET} "
            msg = f"{C_BOLD}{C_MAGENTA}⟪XORRISO ISO MASTER⟫{C_RESET} {sub_bar} {C_DIM}({cur_b:,}/{tot_b:,} blocks written){C_RESET}"
            print(prefix + msg)
        else:
            master_pct = min(99, int(((stage_base_secs + min(s_elapsed, stage_est)) / total_est) * 100)) if total_est > 0 else 0
            prefix = f"  {C_DIM}[{C_CYAN}{t_min:02d}:{t_sec:02d}{C_DIM} │ {C_BOLD}{master_pct:2d}%{C_DIM} │ {C_BLUE}S{stage_num}{C_DIM}]{C_RESET} "
            print(prefix + raw)
        sys.stdout.flush()
    else:
        buf += chunk
' "$stage_num" "$stage_est" "$stage_base_secs" "$build_start" "$total_est" || rc=${PIPESTATUS[0]}

    local end_time
    end_time=$(date +%s)
    local step_elapsed=$(( end_time - stage_start ))
    local step_mins=$(( step_elapsed / 60 ))
    local step_secs=$(( step_elapsed % 60 ))

    local sim_secs=$(( stage_base_secs + (step_elapsed > stage_est ? stage_est : step_elapsed) ))
    local end_master_pct=$(( sim_secs * 100 / TOTAL_ESTIMATED_SECS ))
    [ "$end_master_pct" -gt 100 ] && end_master_pct=100
    local end_m_bar
    end_m_bar=$(render_bar "$end_master_pct" 100 16 "$C_GREEN")

    echo -e "${C_DIM}  ─────────────────────────────────────────────────────────────────────────────${C_RESET}"
    if [ $rc -eq 0 ]; then
        printf "  ${C_GREEN}✔ [DONE]${C_RESET} ${C_BOLD}[Stage %d/9]${C_RESET} %s ${C_GREEN}[%02d:%02d / target ~%02ds]${C_RESET} │ Master: [%b] %3d%%\n\n" \
            "$CURRENT_STAGE" "$label" "$step_mins" "$step_secs" "$stage_est" "$end_m_bar" "$end_master_pct"
        return 0
    else
        printf "  ${C_RED}✖ [FAIL]${C_RESET} ${C_BOLD}[Stage %d/9]${C_RESET} %s ${C_RED}[%02d:%02d] (exit code %d)${C_RESET}\n\n" \
            "$CURRENT_STAGE" "$label" "$step_mins" "$step_secs" "$rc"
        return $rc
    fi
}

# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

cd "$WS_DIR"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${C_RED}ERROR: auto-build.sh must be run with root privileges (sudo).${C_RESET}"
    exit 1
fi

exec 9>/tmp/xeno-auto-build.lock
if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import fcntl; fcntl.fcntl(9, fcntl.F_SETFD, fcntl.FD_CLOEXEC)' 2>/dev/null || true
fi
flock -n --cloexec 9 2>/dev/null || flock -n 9 || { echo -e "${C_RED}ERROR: auto-build.sh is already actively running.${C_RESET}"; exit 1; }

BUILD_START_TIME=$(date +%s)

echo -e "${C_CYAN}${C_BOLD}"
cat << 'BANNER_EOF'
 ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ ─█▀▀█ ░█▀▀█ ░█▀▀▀ ░█▀▀█ 
 ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█▄▄▀ ░█▀▀▀ ░█▄▄█ ░█▄▄█ ░█▀▀▀ ░█▄▄▀ 
 ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█─░█ ░█▄▄▄ ░█──█ ░█─── ░█▄▄▄ ░█─░█ 
BANNER_EOF
echo -e "${C_BLUE} ═══ XENO OS SMART LEAN AUTOMATED PACKAGING PIPELINE ═══${C_RESET}"
echo -e "${C_DIM} Target: ${TARGET_ISO} | Edition: ${TIER_NAME}${C_RESET}"
echo -e "${C_DIM} Expected Pipeline Time: ~${TOTAL_ESTIMATED_SECS}s (~$(( TOTAL_ESTIMATED_SECS / 60 ))m $(( TOTAL_ESTIMATED_SECS % 60 ))s) Across 9 Major Stages${C_RESET}\n"

render_telemetry_dashboard

# ── STAGE 1: Boot display / session fixes ────────────────────
render_stage_progress 1
run_with_spinner "Applying boot display & PAM security limits" 6 bash "$WS_DIR/scripts/xeno-reaper.sh" fix-boot

# ── STAGE 2: Smart Kernel & Download Cache Synchronization ──
render_stage_progress 2
ACTUAL_USER="${SUDO_USER:-xeno}"

BACKUP_CACHE_DIR="$WS_DIR/cache/downloads"
BACKUP_KERNEL_DIR="$BACKUP_CACHE_DIR/kernel"
BACKUP_DRIVERS_DIR="$BACKUP_CACHE_DIR/drivers"
STAGING_DIR="$WS_DIR/cache/staging"
BACKUP_META_FILE="$BACKUP_KERNEL_DIR/latest_release.json"

mkdir -p "$CACHE_DIR" "$BACKUP_KERNEL_DIR" "$BACKUP_DRIVERS_DIR" "$STAGING_DIR" "$WS_DIR/iso/output"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$WS_DIR/cache" "$CACHE_DIR" 2>/dev/null || true

DETECTED_REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's#^.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$#\1#' | sed 's/\.git$//' || echo "")
REPO="${DETECTED_REPO:-harshthakur750556/Xeno-os}"
echo -e "  ${C_CYAN}Targeting Repository:${C_RESET} ${REPO}"

# 2.1 Stage locally compiled kernel if present in kernel/output
if ls "$WS_DIR/kernel/output"/linux-image-*.deb &>/dev/null; then
    run_with_spinner "Staging fresh local kernel from kernel/output" 4 bash "$WS_DIR/scripts/xeno-reaper.sh" stage-kernel || true
    cp "$CACHE_DIR"/*.deb "$BACKUP_KERNEL_DIR/" 2>/dev/null || true
    cp "$META_FILE" "$BACKUP_KERNEL_DIR/" 2>/dev/null || true
fi

# 2.2 Restore from backup store if cache/ is empty
if ! ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null && ls "$BACKUP_KERNEL_DIR"/linux-image-*.deb &>/dev/null; then
    echo -e "  ${C_BLUE}ℹ [CACHE RESTORE]${C_RESET} Restoring kernel packages from persistent backup folder..."
    cp "$BACKUP_KERNEL_DIR"/*.deb "$CACHE_DIR/" 2>/dev/null || true
    [ -f "$BACKUP_KERNEL_DIR/latest_release.json" ] && cp "$BACKUP_KERNEL_DIR/latest_release.json" "$META_FILE" 2>/dev/null || true
fi

# 2.3 Verify local cache integrity
LOCAL_KERNEL_VALID=0
if ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
    if bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$CACHE_DIR" >/dev/null 2>&1; then
        LOCAL_KERNEL_VALID=1
        cp "$CACHE_DIR"/*.deb "$BACKUP_KERNEL_DIR/" 2>/dev/null || true
        [ -f "$META_FILE" ] && cp "$META_FILE" "$BACKUP_KERNEL_DIR/" 2>/dev/null || true
    fi
fi

LOCAL_TAG=$(jq -r '.tagName // empty' "$META_FILE" 2>/dev/null || echo "unknown")
[ -z "$LOCAL_TAG" ] && LOCAL_TAG="unknown"

NEED_DOWNLOAD=false
REMOTE_TAG=""
RELEASE_INFO=""

# 2.4 Query remote release without destroying working local cache
GH_ONLINE=0
if sudo -u "$ACTUAL_USER" gh auth status &>/dev/null || gh auth status &>/dev/null; then
    RELEASE_INFO=$(sudo -u "$ACTUAL_USER" gh release view -R "$REPO" --json tagName,publishedAt 2>/dev/null || true)
    if [ -n "$RELEASE_INFO" ]; then
        REMOTE_TAG=$(echo "$RELEASE_INFO" | jq -r '.tagName // empty')
        [ -n "$REMOTE_TAG" ] && GH_ONLINE=1
    fi
fi

if [ "$LOCAL_KERNEL_VALID" -eq 1 ]; then
    if [ "$GH_ONLINE" -eq 1 ]; then
        if [[ "$LOCAL_TAG" == local-build-* ]] || [[ "$LOCAL_TAG" == local-custom-* ]]; then
            echo -e "  ${C_GREEN}✔ [LOCAL CUSTOM KERNEL]${C_RESET} Preserving fresh locally built XanMod kernel ($LOCAL_TAG, 0s download)"
            NEED_DOWNLOAD=false
        elif [ "$REMOTE_TAG" = "$LOCAL_TAG" ]; then
            echo -e "  ${C_GREEN}✔ [KERNEL CACHE VERIFIED]${C_RESET} Local kernel is up-to-date (Tag: $LOCAL_TAG, 0s download)"
            NEED_DOWNLOAD=false
        else
            echo -e "  ${C_YELLOW}⚠ [NEW RELEASE DETECTED]${C_RESET} Remote update available ($REMOTE_TAG != local $LOCAL_TAG). Staging update..."
            NEED_DOWNLOAD=true
        fi
    else
        echo -e "  ${C_GREEN}✔ [KERNEL CACHE REUSED]${C_RESET} Using verified offline/local kernel cache ($LOCAL_TAG, 0s download)"
        NEED_DOWNLOAD=false
    fi
else
    echo -e "  ${C_BLUE}ℹ [INITIAL DOWNLOAD]${C_RESET} Local kernel cache missing or invalid. Downloading latest release..."
    NEED_DOWNLOAD=true
fi

# 2.5 Safe Isolated Staging Download (never destroy working cache on download failure)
if [ "$NEED_DOWNLOAD" = true ]; then
    if [ "$GH_ONLINE" -ne 1 ]; then
        if [ "$LOCAL_KERNEL_VALID" -eq 1 ]; then
            echo -e "  ${C_YELLOW}⚠ [WARN] Cannot check remote release (GH offline/unauthenticated). Reusing local validated cache.${C_RESET}"
        else
            echo -e "${C_RED}ERROR: GitHub CLI is not authenticated and no valid local kernel cache exists. Run 'gh auth login'.${C_RESET}"
            exit 1
        fi
    else
        download_kernel_pkgs() {
            rm -rf "$STAGING_DIR/kernel"
            mkdir -p "$STAGING_DIR/kernel"
            if sudo -u "$ACTUAL_USER" gh release download -R "$REPO" --pattern "*.deb" -D "$STAGING_DIR/kernel" --clobber 2>/dev/null; then
                if bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$STAGING_DIR/kernel" >/dev/null 2>&1; then
                    rm -f "$CACHE_DIR"/*.deb
                    cp "$STAGING_DIR/kernel"/*.deb "$CACHE_DIR/"
                    cp "$STAGING_DIR/kernel"/*.deb "$BACKUP_KERNEL_DIR/"
                    [ -n "$RELEASE_INFO" ] && echo "$RELEASE_INFO" > "$META_FILE"
                    [ -n "$RELEASE_INFO" ] && echo "$RELEASE_INFO" > "$BACKUP_META_FILE"
                    rm -rf "$STAGING_DIR/kernel"
                    return 0
                else
                    echo -e "  ${C_YELLOW}⚠ Downloaded packages failed validation checks.${C_RESET}"
                    rm -rf "$STAGING_DIR/kernel"
                    return 1
                fi
            fi
            return 1
        }
        export -f download_kernel_pkgs
        run_with_spinner "Downloading & staging validated kernel packages from GitHub" 8 download_kernel_pkgs || {
            if [ "$LOCAL_KERNEL_VALID" -eq 1 ]; then
                echo -e "  ${C_YELLOW}⚠ [FALLBACK] Update download failed. Safely continuing with verified local cache.${C_RESET}"
            else
                echo -e "${C_RED}ERROR: Failed downloading kernel packages and no valid cache exists.${C_RESET}"
                exit 1
            fi
        }
    fi
fi

rm -rf "$STAGING_DIR" 2>/dev/null || true

if ! ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
    echo -e "${C_RED}ERROR: No linux-image-*.deb found in cache ($CACHE_DIR).${C_RESET}"
    exit 1
fi

# ── STAGE 3: Validate kernel debs (Show-stopper gate) ─────────
render_stage_progress 3
KERNEL_VALID=0
if bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$CACHE_DIR"; then
    KERNEL_VALID=1
    echo -e "  ${C_GREEN}✔ [PASS] Kernel packages passed WLAN, NTSYNC, and packet injection validation.${C_RESET}"
else
    echo -e "\n${C_RED}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_RED}  FATAL: Kernel packages failed validation. Refusing Wi-Fi-broken custom kernel.${C_RESET}"
    echo -e "${C_RED}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    if ! ls "$ROOTFS"/boot/vmlinuz-*-generic &>/dev/null; then
        echo -e "${C_RED}ERROR: No generic fallback kernel found in rootfs. Aborting build.${C_RESET}"
        exit 1
    fi
    echo -e "  ${C_YELLOW}⚠ Continuing with Ubuntu generic kernel fallback for this build.${C_RESET}"
    KERNEL_VALID=0
fi

# ── STAGE 4: Repair / install kernel into RootFS ─────────────
render_stage_progress 4
if [ "$KERNEL_VALID" = "1" ]; then
    run_with_spinner "Installing validated XanMod kernel into RootFS" 15 bash "$WS_DIR/scripts/xeno-reaper.sh" fix-kernel
else
    run_with_spinner "Configuring fallback generic kernel in RootFS" 15 env XENO_SKIP_CUSTOM=1 bash "$WS_DIR/scripts/xeno-reaper.sh" fix-kernel || true
fi

# ── STAGE 5: Sync desktop & install feature stacks ───────────
render_stage_progress 5
sync_desktop_env() {
    rsync -a --delete \
        --exclude='*.local' \
        --exclude='.config/' \
        --exclude='custom/' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='*.pyo' \
        --exclude='.pytest_cache' \
        --exclude='node_modules' \
        --exclude='.git' \
        "$WS_DIR/desktop/" "$ROOTFS/home/xeno/desktop/"

    rsync -a --delete \
        --exclude='*.local' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='*.pyo' \
        --exclude='.git' \
        "$WS_DIR/scripts/" "$ROOTFS/home/xeno/scripts/"
    chown -R 1000:1000 "$ROOTFS/home/xeno/desktop" "$ROOTFS/home/xeno/scripts" 2>/dev/null || true

    rm -f "$ROOTFS/home/xeno/.bash_history" "$ROOTFS/home/xeno/.lesshst" "$ROOTFS/home/xeno/.python_history" 2>/dev/null || true
    rm -f "$ROOTFS/root/.bash_history" "$ROOTFS/root/.lesshst" 2>/dev/null || true
}
export -f sync_desktop_env
run_with_spinner "Syncing desktop shell & management scripts to RootFS" 5 sync_desktop_env

if [ "${XENO_SKIP_FEATURE_SETUP:-0}" != "1" ]; then
    if [ ! -x "$ROOTFS/usr/bin/xeno-windows" ] || [ "${XENO_FORCE_FEATURE_SETUP:-0}" = "1" ]; then
        run_with_spinner "Setting up Windows compatibility stack (Wine/DXVK/Bottles)" 6 bash "$WS_DIR/scripts/xeno-reaper.sh" setup-compat
    fi
    if [ ! -x "$ROOTFS/usr/bin/xeno-wifi-monitor" ] || [ "${XENO_FORCE_FEATURE_SETUP:-0}" = "1" ]; then
        run_with_spinner "Setting up Security & wireless injection stack" 6 bash "$WS_DIR/scripts/xeno-reaper.sh" setup-security
    fi
    if [ ! -x "$ROOTFS/usr/bin/xeno-ai-engine" ] || [ "${XENO_FORCE_FEATURE_SETUP:-0}" = "1" ]; then
        run_with_spinner "Setting up Local AI Engine & Bubblewrap sandbox" 4 bash "$WS_DIR/scripts/xeno-reaper.sh" setup-ai
    fi
    if [ -x "$WS_DIR/drivers/install-oot-wifi.sh" ]; then
        run_with_spinner "Building & installing Realtek RTL8812AU OOT injection driver" 4 env XENO_ROOTFS="$ROOTFS" bash "$WS_DIR/drivers/install-oot-wifi.sh"
    fi
fi

xeno_assert_no_broken_pkgs "$ROOTFS"

# ── STAGE 6: Casper / Initramfs Live Boot Essentials ──────────
render_stage_progress 6
xeno_chroot_mount "$ROOTFS"
cleanup_mounts() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup_mounts EXIT

build_casper_initramfs() {
    chroot "$ROOTFS" /bin/bash << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y live-boot live-boot-initramfs-tools live-tools 2>/dev/null || true
dpkg -s casper &>/dev/null || apt-get install -y --no-install-recommends casper

# 6.1 ZRAM Setup
apt-get install -y --no-install-recommends systemd-zram-generator 2>/dev/null || true
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf.d/zram0.conf << 'ZRAM_EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM_EOF

# 6.3 Bloat Removal
apt-get purge -y snapd apport whoopsie cups geoclue-2.0 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

mkdir -p /etc/initramfs-tools
for m in overlay squashfs zstd nls_utf8 isofs sr_mod sd_mod ahci; do
    grep -qxF "$m" /etc/initramfs-tools/modules 2>/dev/null || echo "$m" >> /etc/initramfs-tools/modules
done

if ls /boot/vmlinuz-*xeno* >/dev/null 2>&1; then
    KIMG=$(ls /boot/vmlinuz-*xeno* 2>/dev/null | grep -v dpkg-new | sort -V | tail -1 || true)
else
    KIMG=""
fi
if [ -z "$KIMG" ]; then
    KIMG=$(ls /boot/vmlinuz-*-generic 2>/dev/null | sort -V | tail -1)
fi
if [ -z "$KIMG" ]; then
    echo "ERROR: no bootable vmlinuz found"
    exit 1
fi
NEW_VERSION="${KIMG#/boot/vmlinuz-}"
update-initramfs -u -k "$NEW_VERSION" || update-initramfs -c -k "$NEW_VERSION"

bad=$(dpkg -l | awk '$1 ~ /U|H|R|F/ {print $2}')
if [ -n "$bad" ]; then
    echo "ERROR: broken packages remain: $bad"
    exit 1
fi
if find /lib/modules -name '*.dpkg-new' 2>/dev/null | grep -q .; then
    echo "ERROR: *.dpkg-new modules present — kernel install incomplete"
    exit 1
fi
apt-get clean
echo "$NEW_VERSION" > /tmp/xeno-boot-kver
EOF
}
export -f build_casper_initramfs
run_with_spinner "Configuring Casper live initramfs, ZRAM & pruning bloat" 45 build_casper_initramfs

trap - EXIT
xeno_chroot_umount "$ROOTFS"

KVER=$(cat "$ROOTFS/tmp/xeno-boot-kver")
echo -e "  ${C_GREEN}✔ [BOOT KERNEL]${C_RESET} Using kernel: ${C_BOLD}$KVER${C_RESET}"

# Assemble bootloader files
rm -rf "$WS_DIR/iso/build"/*
mkdir -p "$WS_DIR/iso/build/casper" "$WS_DIR/iso/build/boot/grub/i386-pc"

KERNEL_SRC="$ROOTFS/boot/vmlinuz-$KVER"
INITRD_SRC="$ROOTFS/boot/initrd.img-$KVER"
if [ ! -f "$KERNEL_SRC" ] || [ ! -f "$INITRD_SRC" ]; then
    echo -e "${C_RED}ERROR: Missing $KERNEL_SRC or $INITRD_SRC.${C_RESET}"
    exit 1
fi
cp "$KERNEL_SRC" "$WS_DIR/iso/build/casper/vmlinuz"
cp "$INITRD_SRC" "$WS_DIR/iso/build/casper/initrd"
chroot "$ROOTFS" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WS_DIR/iso/build/casper/filesystem.manifest"

cat > "$WS_DIR/iso/build/boot/grub/grub.cfg" << 'EOF'
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input serial console
terminal_output serial console

set timeout=0
set default=0
menuentry "Xeno OS (Universal)" {
    linux /casper/vmlinuz boot=casper console=ttyS0,115200n8 console=tty1 username=xeno hostname=xeno-os ---
    initrd /casper/initrd
}
EOF

# ── STAGE 7: Optimization & Smart SquashFS Compression ───────
render_stage_progress 7
optimize_rootfs_caches() {
    rm -rf "$ROOTFS/root/.cache" "$ROOTFS/root/.npm" "$ROOTFS/root/.cargo/registry" 2>/dev/null || true
    rm -rf "$ROOTFS/var/cache/apt/archives"/* "$ROOTFS/var/lib/apt/lists"/* 2>/dev/null || true
    rm -rf "$ROOTFS/tmp"/* "$ROOTFS/var/tmp"/* "$ROOTFS/var/log"/* 2>/dev/null || true
    rm -rf "$ROOTFS/usr/src/linux-headers-"* 2>/dev/null || true
    rm -rf "$ROOTFS/usr/local/lib/ollama/cuda_v12" "$ROOTFS/usr/local/lib/ollama/cuda_v13" 2>/dev/null || true
    find "$ROOTFS/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
    rm -rf "$ROOTFS/var/lib/flatpak/runtime"/*/*.Locale 2>/dev/null || true
    find "$ROOTFS/usr" "$ROOTFS/home" "$ROOTFS/var" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$ROOTFS/usr" "$ROOTFS/home" "$ROOTFS/var" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

    # Clean temporary staging directory & partial downloads
    rm -rf "$WS_DIR/cache/staging" 2>/dev/null || true
    find "$WS_DIR/cache" "$WS_DIR/kernel/cache" -maxdepth 2 -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.dpkg-new" \) -delete 2>/dev/null || true

    mkdir -p "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev" "$ROOTFS/tmp" "$ROOTFS/run"
    touch "$ROOTFS/proc/.keep" "$ROOTFS/sys/.keep" "$ROOTFS/dev/.keep" "$ROOTFS/tmp/.keep" "$ROOTFS/run/.keep"
}
export -f optimize_rootfs_caches
run_with_spinner "Purging temporary build caches, bytecode, and CUDA runtimes" 10 optimize_rootfs_caches

build_squashfs_image() {
    mksquashfs "$ROOTFS" "$WS_DIR/iso/build/casper/filesystem.squashfs" \
        -comp zstd -Xcompression-level 19 -b 1M -noappend -progress \
        -wildcards \
        -e "proc/*" "sys/*" "dev/*" "tmp/*" "run/*" \
        -e "var/cache/apt/archives/*" "var/lib/apt/lists/*" "var/cache/*" \
        -e "root/.cache/*" "root/.npm/*" "root/.cargo/registry/*" \
        -e "home/*/.cache/*" \
        -e "usr/share/doc/*" "usr/share/man/*" "usr/share/info/*" "usr/share/help/*" \
        -e "usr/include/*" "usr/src/*" \
        -e "usr/local/lib/ollama/cuda_*" \
        -e "var/lib/flatpak/runtime/*/*.Locale/*" \
        -e "**/__pycache__/*" "**/*.pyc" "**/*.pyo" \
        -e "proc/.*" "sys/.*" "dev/.*" "tmp/.*" "run/.*"
}
export -f build_squashfs_image
run_with_spinner "Compressing RootFS into SquashFS (ZSTD L19, 1MB blocks)" 80 build_squashfs_image
printf "%s\n" "$(du -sx --block-size=1 "$ROOTFS" | cut -f1)" > "$WS_DIR/iso/build/casper/filesystem.size"

# ── STAGE 8: GRUB Bootloaders Assembly (Dual BIOS + UEFI) ────
render_stage_progress 8
assemble_bootloaders() {
    mkdir -p "$WS_DIR/iso/build/boot/grub/i386-pc" "$WS_DIR/iso/build/boot/grub/x86_64-efi" "$WS_DIR/iso/build/EFI/BOOT"
    cp -r /usr/lib/grub/i386-pc/* "$WS_DIR/iso/build/boot/grub/i386-pc/" 2>/dev/null || true

    grub-mkimage -O i386-pc -o "$WS_DIR/iso/build/boot/grub/i386-pc/eltorito.img" \
        -p '(cd0)/boot/grub' iso9660 biosdisk normal

    if [ -d "/usr/lib/grub/x86_64-efi" ]; then
        cp -r /usr/lib/grub/x86_64-efi/* "$WS_DIR/iso/build/boot/grub/x86_64-efi/" 2>/dev/null || true
        
        grub-mkimage -O x86_64-efi -o "$WS_DIR/iso/build/EFI/BOOT/BOOTX64.EFI" \
            -p '/boot/grub' iso9660 fat part_gpt part_msdos normal boot linux configfile tar search search_fs_file search_label search_fs_uuid efi_gop efi_uga gfxterm gfxmenu
        
        dd if=/dev/zero of="$WS_DIR/iso/build/boot/grub/efi.img" bs=1k count=4096 2>/dev/null || true
        mkfs.vfat "$WS_DIR/iso/build/boot/grub/efi.img" 2>/dev/null || true
        if command -v mcopy >/dev/null 2>&1; then
            mmd -i "$WS_DIR/iso/build/boot/grub/efi.img" ::EFI ::EFI/BOOT 2>/dev/null || true
            mcopy -i "$WS_DIR/iso/build/boot/grub/efi.img" "$WS_DIR/iso/build/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
        fi
    fi
}
export -f assemble_bootloaders
run_with_spinner "Generating BIOS & UEFI boot images (BOOTX64.EFI & efi.img)" 15 assemble_bootloaders

# ── STAGE 9: ISO Generation & Verification ───────────────────
render_stage_progress 9
LOCAL_ISO_PATH="$OUTPUT_DIR/${ISO_NAME}"

generate_iso_master() {
    grub-mkrescue --xorriso="$WS_DIR/xorriso-wrapper.sh" \
        -volid "$VOLUME_ID" \
        -o "$LOCAL_ISO_PATH" "$WS_DIR/iso/build/"
}
export -f generate_iso_master
run_with_spinner "Building bootable ISO image via xorriso-wrapper (Level 3)" 30 generate_iso_master

(cd "$OUTPUT_DIR" && sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256")
ln -sf "$LOCAL_ISO_PATH" "$WS_DIR/iso/output/${ISO_NAME}" 2>/dev/null || true
ln -sf "${LOCAL_ISO_PATH}.sha256" "$WS_DIR/iso/output/${ISO_NAME}.sha256" 2>/dev/null || true

if [ -d "$WIN_HOST_DIR" ]; then
    copy_win_host() {
        mkdir -p "$WIN_HOST_DIR/$TIER_NAME" 2>/dev/null || true
        cp "$LOCAL_ISO_PATH" "$WIN_HOST_DIR/$TIER_NAME/${ISO_NAME}" 2>/dev/null || dd if="$LOCAL_ISO_PATH" of="$WIN_HOST_DIR/$TIER_NAME/${ISO_NAME}" bs=64M conv=fsync 2>/dev/null || true
        cp "${LOCAL_ISO_PATH}.sha256" "$WIN_HOST_DIR/$TIER_NAME/${ISO_NAME}.sha256" 2>/dev/null || true
        cp "$LOCAL_ISO_PATH" "$WIN_HOST_DIR/${ISO_NAME}" 2>/dev/null || true
        cp "${LOCAL_ISO_PATH}.sha256" "$WIN_HOST_DIR/${ISO_NAME}.sha256" 2>/dev/null || true
    }
    export -f copy_win_host
    run_with_spinner "Synchronizing ISO artifact to Windows host directory" 8 copy_win_host
fi

BUILD_END_TIME=$(date +%s)
TOTAL_BUILD_SECS=$(( BUILD_END_TIME - BUILD_START_TIME ))
BUILD_MINS=$(( TOTAL_BUILD_SECS / 60 ))
BUILD_SECS=$(( TOTAL_BUILD_SECS % 60 ))

ISO_BYTES=$(stat -c%s "$LOCAL_ISO_PATH" 2>/dev/null || echo 0)
ISO_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$ISO_BYTES" 2>/dev/null || echo "0B")
SHA256_HASH=$(cat "${LOCAL_ISO_PATH}.sha256" 2>/dev/null | awk '{print $1}' || echo "N/A")
NEXT_VERSION=$(python3 - << PY_EOF
import re
current = "$BUILD_VERSION".strip()
is_beta = bool(re.search(r'beta', current, re.IGNORECASE))
is_omega = bool(re.search(r'omega', current, re.IGNORECASE))
is_alpha = bool(re.search(r'alpha', current, re.IGNORECASE))
recreate = "${XENO_RECREATE_ISO:-0}" == "1"

m = re.search(r'([0-9]+(?:\.[0-9]+)?)', current)
num = float(m.group(1)) if m else 9.0

if recreate:
    print(f"{current} (Snapshot Freeze)")
elif is_beta:
    if num >= 10.0:
        # v10 is the final version for the beta series!
        print("10.0-beta (Final Beta Milestone)")
    else:
        next_num = min(10.0, round(num + 0.5, 1))
        print(f"{next_num}-beta")
elif is_omega:
    next_num = round(num + 0.1, 1)
    print(f"{next_num}-omega")
elif is_alpha:
    next_num = round(num + 0.5, 1)
    print(f"{next_num}-alpha")
else:
    next_num = round(num + 0.5, 1)
    print(f"{next_num}")
PY_EOF
)
if [ "$ACTIVE_TIER" = "BETA" ]; then
    BETA_BUILT=1
    BETA_STATUS="BUILT"
    BETA_LAST_BUILD=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    BETA_ISO="$ISO_NAME"
    BETA_PROGRESS=100
elif [ "$ACTIVE_TIER" = "ALPHA" ]; then
    ALPHA_BUILT=1
    ALPHA_STATUS="BUILT"
    ALPHA_LAST_BUILD=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ALPHA_ISO="$ISO_NAME"
    ALPHA_PROGRESS=100
elif [ "$ACTIVE_TIER" = "OMEGA" ]; then
    OMEGA_BUILT=1
    OMEGA_STATUS="BUILT"
    OMEGA_LAST_BUILD=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    OMEGA_ISO="$ISO_NAME"
    OMEGA_PROGRESS=100
fi
LAST_BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LAST_BUILD_TIER="$TIER_NAME"
LAST_BUILD_ISO="$ISO_NAME"
LAST_BUILD_SIZE="$ISO_SIZE_HUMAN"
LAST_BUILD_SHA256="$SHA256_HASH"

if [ "${XENO_RECREATE_ISO:-0}" != "1" ] && [[ "$NEXT_VERSION" != *"Final Beta Milestone"* ]] && [[ "$NEXT_VERSION" != *"Snapshot Freeze"* ]]; then
    BUILD_VERSION="$NEXT_VERSION"
fi
save_version_manifest

echo -e "\n${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_BOLD}                   XENO OS BUILD PIPELINE COMPLETION REPORT                    ${C_RESET}"
echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
printf "  Master Progress:  %b\n" "$(render_bar 100 100 28 "$C_GREEN")"
echo -e "  Target Edition:   ${C_BOLD}${TIER_NAME}${C_RESET}"
echo -e "  ISO Artifact:     ${C_CYAN}${TARGET_ISO}${C_RESET}"
echo -e "  Artifact Size:    ${C_GREEN}${ISO_SIZE_HUMAN}${C_RESET} (${ISO_BYTES} bytes)"
echo -e "  SHA256 Checksum:  ${C_YELLOW}${SHA256_HASH}${C_RESET}"
echo -e "  Boot Kernel:      ${C_BLUE}${KVER}${C_RESET}"
echo -e "  Actual Duration:  ${C_CYAN}${BUILD_MINS}m ${BUILD_SECS}s${C_RESET} (${TOTAL_BUILD_SECS}s / target ~${TOTAL_ESTIMATED_SECS}s)"
echo -e "  Queued Version:   ${C_DIM}v${NEXT_VERSION}${C_RESET}"
echo -e "${C_BOLD}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"

if [ "$KERNEL_VALID" = "1" ]; then
    echo -e "${C_GREEN}${C_BOLD}✔ ISO PACKAGING COMPLETE — XANMOD BORE KERNEL & INJECTION CERTIFIED${C_RESET}\n"
else
    echo -e "${C_YELLOW}${C_BOLD}⚠ ISO PACKAGING COMPLETE — GENERIC FALLBACK KERNEL (CUSTOM KERNEL WAS INVALID)${C_RESET}\n"
fi
