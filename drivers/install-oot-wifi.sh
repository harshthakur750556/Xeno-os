#!/bin/bash
# Optional out-of-tree Wi-Fi injection drivers (Realtek USB family).
# Run inside a booted Xeno system or chroot WITH matching kernel headers.
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-}"

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — Optional OOT Wi-Fi Drivers (DKMS)"
echo "═══════════════════════════════════════════════════"
echo "These drivers improve injection on some Realtek USB adapters."
echo "They require: build-essential, dkms, linux-headers-\$(uname -r)"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root"
    exit 1
fi

TARGET_ROOT="${ROOTFS:-/}"
export DEBIAN_FRONTEND=noninteractive

chroot_or_host() {
    if [ "$TARGET_ROOT" = "/" ]; then
        "$@"
    else
        chroot "$TARGET_ROOT" "$@"
    fi
}

chroot_or_host apt-get update
chroot_or_host apt-get install -y --no-install-recommends \
    dkms build-essential git bc \
    "linux-headers-$(chroot_or_host uname -r 2>/dev/null || echo meta)" \
    2>/dev/null || chroot_or_host apt-get install -y dkms build-essential git bc linux-headers-generic

# aircrack-ng rtl8812au (commonly used injection NIC family)
BUILD=/tmp/xeno-oot-wifi
rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"
git clone --depth=1 https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
# DKMS install when possible
if command -v dkms >/dev/null 2>&1; then
    make dkms_install || make && make install
else
    make -j"$(nproc)"
    make install
fi

echo "✓ OOT driver install attempted. Reboot and check: lsmod | grep 88XXau"
echo "  Monitor helper: sudo xeno-wifi-monitor doctor"
