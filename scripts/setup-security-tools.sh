#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Xeno OS — Kali-class security/wireless tooling on Ubuntu base
#
# Strategy (safe, show-stopper free):
#  1. Install full wireless + pentest toolset from Ubuntu repos
#  2. Optionally enable kali-rolling with STRICT apt pinning so
#     packages only install when explicitly requested
#  3. Install wifi monitor helper and firmware packages
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"
ENABLE_KALI_REPO="${ENABLE_KALI_REPO:-1}"
XENO_SECURITY_PROFILE="${XENO_SECURITY_PROFILE:-minimal}"
# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

xeno_require_root
if [ ! -d "$ROOTFS/usr/bin" ]; then
    echo "ERROR: rootfs not found at $ROOTFS"
    exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — Security / Wireless Tools Installer"
echo "  Target: $ROOTFS"
echo "═══════════════════════════════════════════════════"

xeno_chroot_mount "$ROOTFS"
cleanup() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup EXIT

# Host-side apt preferences / sources into rootfs
mkdir -p "$ROOTFS/etc/apt/preferences.d" "$ROOTFS/etc/apt/sources.list.d" "$ROOTFS/etc/apt/keyrings"

if [ "$ENABLE_KALI_REPO" = "1" ]; then
    echo "[host] Installing Kali archive key + pinned source (priority 100)..."
    # Official Kali archive keyring package is preferred; fall back to key fetch
    if [ ! -f "$ROOTFS/etc/apt/keyrings/kali-archive-keyring.gpg" ]; then
        curl -fsSL https://archive.kali.org/archive-key.asc \
            | gpg --dearmor -o "$ROOTFS/etc/apt/keyrings/kali-archive-keyring.gpg" || true
    fi
    cat > "$ROOTFS/etc/apt/sources.list.d/kali-rolling.list" << 'EOF'
# Kali rolling — PINNED LOW. Do not use for general upgrades.
# Install explicitly: apt-get install -t kali-rolling <package>
deb [signed-by=/etc/apt/keyrings/kali-archive-keyring.gpg] http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
EOF
    cat > "$ROOTFS/etc/apt/preferences.d/kali-pinning" << 'EOF'
# Prevent Kali packages from replacing Ubuntu base during apt upgrade.
Package: *
Pin: release o=Kali
Pin-Priority: 100
EOF
fi

chroot "$ROOTFS" /bin/bash << 'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export XENO_SECURITY_PROFILE="$XENO_SECURITY_PROFILE"


echo "[1/6] apt update..."
apt-get update || true

echo "[2/6] Core wireless firmware + utilities..."
apt-get install -y --no-install-recommends \
    linux-firmware \
    wireless-tools \
    iw \
    rfkill \
    network-manager \
    wpasupplicant \
    bluez \
    usbutils \
    pciutils \
    firmware-sof-signed \
    || true

echo "[3/6] Kali-class tools from Ubuntu (safe ABI)..."
# Install what exists; skip missing names without aborting the whole set
PKGS=(
    aircrack-ng
    reaver
    bully
    pixiewps
    mdk4
    mdk3
    hcxdumptool
    hcxtools
    hashcat
    hashcat-data
    john
    hydra
    nmap
    masscan
    wireshark
    tshark
    tcpdump
    kismet
    macchanger
    hostapd
    dnsmasq
    bettercap
    ettercap-text-only
    sqlmap
    nikto
    gobuster
    dirb
    proxychains4
    tor
    netcat-openbsd
    socat
    ncat
    python3-scapy
    python3-impacket
    python3-pwntools
    binwalk
    foremost
    steghide
    exiftool
    whois
    dnsutils
    traceroute
    iperf3
    net-tools
    bridge-utils
    iptables
    nftables
    openssh-client
    openssh-server
    git
    curl
    wget
)

install_one() {
    local p="$1"
    if apt-cache show "$p" >/dev/null 2>&1; then
        apt-get install -y --no-install-recommends "$p" && echo "  + $p" || echo "  ! failed $p"
    else
        echo "  · skip (not in Ubuntu): $p"
    fi
}

for p in "${PKGS[@]}"; do
    install_one "$p"
done

echo "[4/6] Optional Kali-only packages (pinned, explicit)..."
if [ -f /etc/apt/sources.list.d/kali-rolling.list ]; then
    apt-get update || true
    
    if [ "$XENO_SECURITY_PROFILE" = "wireless" ]; then
        apt-get install -y -t kali-rolling --no-install-recommends kali-tools-wireless || true
    elif [ "$XENO_SECURITY_PROFILE" = "full" ]; then
        apt-get install -y -t kali-rolling --no-install-recommends kali-linux-default kali-tools-wireless kali-tools-top10 kali-tools-web kali-tools-information-gathering || true
    fi

    # Only pull tools that are weak/missing on Ubuntu; never pull libc/base
    KALI_ONLY=(wifite airgeddon responder bloodhound)
    for p in "${KALI_ONLY[@]}"; do
        if apt-cache policy "$p" 2>/dev/null | grep -qi kali; then
            apt-get install -y -t kali-rolling --no-install-recommends "$p" 2>/dev/null \
                && echo "  + kali:$p" || echo "  ! kali skip $p"
        fi
    done
fi

echo "[5/6] Non-root wireshark capture group..."
groupadd -f wireshark || true
if getent passwd xeno >/dev/null; then
    usermod -aG wireshark,netdev,plugdev,bluetooth,sudo xeno 2>/dev/null || true
fi
# Allow dumpcap without root where package supports it
if command -v dpkg-reconfigure >/dev/null 2>&1; then
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections || true
    dpkg-reconfigure -f noninteractive wireshark-common 2>/dev/null || true
fi

echo "[6/6] Installing xeno-wifi-monitor helper..."
cat > /usr/bin/xeno-wifi-monitor << 'EOF'
#!/bin/bash
# Manage Wi-Fi monitor mode cleanly with NetworkManager.
set -euo pipefail

usage() {
    cat <<'U'
Usage:
  xeno-wifi-monitor list
  xeno-wifi-monitor start <iface> [channel]
  xeno-wifi-monitor stop  <iface>
  xeno-wifi-monitor inject-test <mon_iface>
  xeno-wifi-monitor doctor
U
}

need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run as root: sudo $0 $*"
        exit 1
    fi
}

cmd="${1:-}"
case "$cmd" in
    list)
        iw dev
        echo "---"
        nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null || true
        ;;
    start)
        need_root "$@"
        iface="${2:-}"
        ch="${3:-}"
        [ -n "$iface" ] || { usage; exit 1; }
        mon="mon0"
        # Release from NetworkManager
        nmcli dev set "$iface" managed no 2>/dev/null || true
        ip link set "$iface" down
        iw dev "$iface" set type monitor 2>/dev/null || {
            # fallback: create a monitor vif
            iw dev "$iface" interface add "$mon" type monitor
            iface_for_up="$mon"
            ip link set "$iface_for_up" up
            [ -n "$ch" ] && iw dev "$iface_for_up" set channel "$ch" 2>/dev/null || true
            echo "Monitor interface: $iface_for_up"
            exit 0
        }
        ip link set "$iface" up
        [ -n "$ch" ] && iw dev "$iface" set channel "$ch" 2>/dev/null || true
        echo "Interface $iface is in monitor mode"
        ;;
    stop)
        need_root "$@"
        iface="${2:-}"
        [ -n "$iface" ] || { usage; exit 1; }
        ip link set "$iface" down 2>/dev/null || true
        iw dev "$iface" set type managed 2>/dev/null || true
        # remove synthetic mon0 if present
        if [ "$iface" = "mon0" ]; then
            iw dev mon0 del 2>/dev/null || true
        fi
        ip link set "$iface" up 2>/dev/null || true
        nmcli dev set "$iface" managed yes 2>/dev/null || true
        echo "Restored managed mode on $iface"
        ;;
    inject-test)
        mon="${2:-}"
        [ -n "$mon" ] || { usage; exit 1; }
        if command -v aireplay-ng >/dev/null; then
            aireplay-ng --test "$mon"
        else
            echo "aireplay-ng not installed"
            exit 1
        fi
        ;;
    doctor)
        echo "=== Xeno Wi-Fi Doctor ==="
        echo "Kernel: $(uname -r)"
        echo -n "CONFIG_WLAN: "
        if [ -f "/boot/config-$(uname -r)" ]; then
            grep -E '^CONFIG_WLAN=' "/boot/config-$(uname -r)" || echo "missing"
        else
            echo "no config file"
        fi
        echo "mac80211: $(lsmod | grep -c mac80211 || true) modules loaded hints"
        lsmod | grep -E 'mac80211|cfg80211|ath9k|iwlwifi|rtw88|mt76|brcmfmac' || echo "(none loaded)"
        echo "--- interfaces ---"
        iw dev 2>/dev/null || true
        echo "--- aircrack ---"
        command -v airmon-ng >/dev/null && airmon-ng || echo "aircrack-ng missing"
        ;;
    *)
        usage
        exit 1
        ;;
esac
EOF
chmod 755 /usr/bin/xeno-wifi-monitor

apt-get clean
echo "Security/wireless tooling installed."

# 1.3 MAC Randomization
mkdir -p /etc/NetworkManager/conf.d/
cat > /etc/NetworkManager/conf.d/00-macrandomize.conf << 'MAC_EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
MAC_EOF

# 1.3 Transparent Tor proxy toggle helper (kalitorify alternative)
cat > /usr/bin/xeno-tor-proxy << 'TOR_EOF'
#!/bin/bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 {start|stop|status}"
    exit 1
fi
CMD="${1:-status}"
case "$CMD" in
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
    status)
        iptables -t nat -L OUTPUT -n -v
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
TOR_EOF
chmod 755 /usr/bin/xeno-tor-proxy

# 1.4 Posture Management
if [ "$XENO_SECURITY_PROFILE" = "hardened" ]; then
    echo "Applying hardened security posture..."
    echo "xeno ALL=(ALL:ALL) ALL" > /etc/sudoers.d/xeno
else
    echo "Applying live-lab security posture..."
    echo "xeno ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/xeno
fi

CHROOT_EOF

echo "✓ Security tools ready in rootfs"
