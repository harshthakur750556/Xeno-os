#!/bin/bash
# Repair half-installed custom kernels and enforce install integrity.
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"
CACHE_DIR="${WS_DIR}/kernel/cache"
# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

xeno_require_root
if [ ! -d "$ROOTFS/usr/bin" ]; then
    echo "ERROR: rootfs not found at $ROOTFS"
    exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — Kernel Rootfs Repair"
echo "═══════════════════════════════════════════════════"

# Validate cached debs before touching rootfs
USE_FALLBACK=1
if [ "${XENO_SKIP_CUSTOM:-0}" = "1" ]; then
    echo "XENO_SKIP_CUSTOM=1 — will not install custom kernel debs."
    USE_FALLBACK=1
elif ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
    if bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$CACHE_DIR"; then
        USE_FALLBACK=0
    else
        echo ""
        echo "WARNING: cached kernel debs FAILED validation (likely no WLAN)."
        echo "They will NOT be installed. Trigger CI rebuild:"
        echo "  - push kernel/patches or kernel/build-kernel.sh"
        echo "  - or: gh workflow run build-kernel.yml"
        echo ""
        echo "Falling back to Ubuntu generic kernel for bootable Wi-Fi."
        USE_FALLBACK=1
    fi
else
    echo "No kernel debs in $CACHE_DIR"
    USE_FALLBACK=1
fi

xeno_chroot_mount "$ROOTFS"
cleanup() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup EXIT

# Fix any leftover .ko.dpkg-new / .dpkg-new boot files from failed installs
echo "[1/5] Cleaning broken dpkg-new artifacts for previous xeno kernels..."
find "$ROOTFS/lib/modules" -name '*.dpkg-new' -print 2>/dev/null | head -5 || true
# Remove half-installed xeno module trees; reinstall will recreate
for d in "$ROOTFS"/lib/modules/*xeno*; do
    [ -d "$d" ] || continue
    echo "  removing broken module tree: $d"
    rm -rf "$d"
done
rm -f "$ROOTFS"/boot/*xeno*.dpkg-new 2>/dev/null || true
rm -f "$ROOTFS"/boot/vmlinuz-*xeno* 2>/dev/null || true
rm -f "$ROOTFS"/boot/initrd.img-*xeno* 2>/dev/null || true
rm -f "$ROOTFS"/boot/System.map-*xeno* 2>/dev/null || true
rm -f "$ROOTFS"/boot/config-*xeno* 2>/dev/null || true

chroot "$ROOTFS" /bin/bash << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[2/5] Purging half-installed xeno kernel packages..."
# Force remove regardless of state
for pkg in $(dpkg -l | awk '/xeno|xanmod/ {print $2}'); do
    dpkg --remove --force-remove-reinstreq "$pkg" 2>/dev/null || true
    dpkg --purge --force-remove-reinstreq "$pkg" 2>/dev/null || true
done
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true

# Ensure a working Ubuntu generic kernel remains
echo "[3/5] Ensuring Ubuntu generic kernel is present..."
apt-get install -y --reinstall linux-image-generic linux-headers-generic linux-modules-generic 2>/dev/null \
    || apt-get install -y linux-image-generic linux-headers-generic

# Make sure generic kernel is the default symlink target
GEN=$(ls /boot/vmlinuz-*-generic 2>/dev/null | sort -V | tail -1 || true)
if [ -n "$GEN" ]; then
    VER="${GEN#/boot/vmlinuz-}"
    ln -sfn "vmlinuz-$VER" /boot/vmlinuz
    if [ -f "/boot/initrd.img-$VER" ]; then
        ln -sfn "initrd.img-$VER" /boot/initrd.img
    else
        update-initramfs -c -k "$VER" || update-initramfs -u -k "$VER"
        ln -sfn "initrd.img-$VER" /boot/initrd.img
    fi
    echo "Default kernel: $VER"
fi
EOF

if [ "${USE_FALLBACK:-1}" = "0" ]; then
    echo "[4/5] Installing validated custom Xeno kernel debs..."
    rm -rf "$ROOTFS/tmp/kernel-debs"
    mkdir -p "$ROOTFS/tmp/kernel-debs"
    cp "$CACHE_DIR"/*.deb "$ROOTFS/tmp/kernel-debs/"

    chroot "$ROOTFS" /bin/bash << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
cd /tmp/kernel-debs
dpkg -i linux-image-*.deb linux-headers-*.deb linux-libc-dev*.deb 2>/dev/null \
    || dpkg -i ./*.deb
apt-get -f install -y

# Hard fail on half-installed state
bad=$(dpkg -l | awk '$1 ~ /U|H|R|F/ {print $2}')
if [ -n "$bad" ]; then
    echo "ERROR: packages still broken after install:"
    echo "$bad"
    exit 1
fi

# No dpkg-new modules allowed
if find /lib/modules -name '*.dpkg-new' | grep -q .; then
    echo "ERROR: *.dpkg-new modules remain after install"
    find /lib/modules -name '*.dpkg-new' | head
    exit 1
fi

NEW_VERSION=$(ls /boot/vmlinuz-*xeno* 2>/dev/null | head -1 | sed 's|/boot/vmlinuz-||')
if [ -z "$NEW_VERSION" ]; then
    echo "ERROR: xeno vmlinuz missing after install"
    exit 1
fi
if [ ! -d "/lib/modules/$NEW_VERSION" ]; then
    echo "ERROR: /lib/modules/$NEW_VERSION missing"
    exit 1
fi
if [ ! -f "/lib/modules/$NEW_VERSION/modules.dep" ]; then
    depmod -a "$NEW_VERSION"
fi
if [ ! -f "/lib/modules/$NEW_VERSION/modules.dep" ]; then
    echo "ERROR: modules.dep still missing for $NEW_VERSION"
    exit 1
fi

# WLAN gate
if [ -f "/boot/config-$NEW_VERSION" ] && ! grep -q '^CONFIG_WLAN=y' "/boot/config-$NEW_VERSION"; then
    echo "ERROR: installed kernel has CONFIG_WLAN disabled"
    exit 1
fi

update-initramfs -c -k "$NEW_VERSION" || update-initramfs -u -k "$NEW_VERSION"
ln -sfn "vmlinuz-$NEW_VERSION" /boot/vmlinuz
ln -sfn "initrd.img-$NEW_VERSION" /boot/initrd.img
echo "Installed Xeno kernel: $NEW_VERSION"
EOF
else
    echo "[4/5] Skipping custom kernel install (invalid/missing debs)."
fi

echo "[5/5] Final integrity check..."
xeno_assert_no_broken_pkgs "$ROOTFS"
echo "✓ Kernel rootfs state repaired"
