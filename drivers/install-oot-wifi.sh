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

# Persistent driver source download store
DRIVER_SRC_CACHE="$WS_DIR/cache/downloads/drivers/rtl8812au"
mkdir -p "$(dirname "$DRIVER_SRC_CACHE")"

if [ -d "$DRIVER_SRC_CACHE/.git" ]; then
    echo "Using cached rtl8812au driver repository in $DRIVER_SRC_CACHE"
    git -C "$DRIVER_SRC_CACHE" pull --ff-only 2>/dev/null || true
else
    echo "Cloning rtl8812au driver into persistent cache ($DRIVER_SRC_CACHE)..."
    git clone --depth=1 https://github.com/aircrack-ng/rtl8812au.git "$DRIVER_SRC_CACHE" 2>/dev/null || true
fi

# aircrack-ng rtl8812au (commonly used injection NIC family)
if [ "$TARGET_ROOT" != "/" ]; then
    echo "Building OOT Wi-Fi driver inside ROOTFS chroot..."
    BUILD="$TARGET_ROOT/tmp/xeno-oot-wifi"
    rm -rf "$BUILD"
    mkdir -p "$BUILD"
    if [ -d "$DRIVER_SRC_CACHE" ]; then
        cp -r "$DRIVER_SRC_CACHE" "$BUILD/rtl8812au"
        KVER=$(ls "$TARGET_ROOT/lib/modules" 2>/dev/null | grep -v dpkg-new | sort -V | tail -1 || true)
        if [ -n "$KVER" ] && [ -d "$TARGET_ROOT/lib/modules/$KVER/build" ]; then
            chroot "$TARGET_ROOT" bash -c "cd /tmp/xeno-oot-wifi/rtl8812au && make KVER=$KVER KSRC=/lib/modules/$KVER/build -j\$(nproc) && make KVER=$KVER KSRC=/lib/modules/$KVER/build install" || echo "WARNING: OOT wifi build failed, continuing..."
        else
            echo "Skipping OOT WiFi build (no headers directory found for $KVER inside rootfs)."
        fi
    else
        echo "WARNING: No rtl8812au source available. Skipping OOT WiFi build."
    fi
    rm -rf "$BUILD"
else
    BUILD=/tmp/xeno-oot-wifi
    rm -rf "$BUILD"
    mkdir -p "$BUILD"
    if [ -d "$DRIVER_SRC_CACHE" ]; then
        cp -r "$DRIVER_SRC_CACHE" "$BUILD/rtl8812au"
        cd "$BUILD/rtl8812au"
        if command -v dkms >/dev/null 2>&1; then
            make dkms_install || make && make install
        else
            make -j"$(nproc)"
            make install
        fi
    fi
fi

echo "✓ OOT driver install attempted. Reboot and check: lsmod | grep 88XXau"
echo "  Monitor helper: sudo xeno-wifi-monitor doctor"
