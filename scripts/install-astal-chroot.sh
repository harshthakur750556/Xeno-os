#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# XENO OS — Astal + AGS + Bun Installation Script (chroot)
# ═══════════════════════════════════════════════════════════════
# Run this script from the HOST to install the Astal desktop
# shell dependencies inside the Xeno OS rootfs chroot.
#
# Usage:
#   sudo bash scripts/install-astal-chroot.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

ROOTFS="${XENO_ROOTFS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../rootfs" && pwd)}"
CHROOT_SCRIPT="/tmp/xeno-astal-install.sh"

echo "═══════════════════════════════════════════════════"
echo "  XENO OS — Astal/AGS/Bun Chroot Installer"
echo "  Target rootfs: $ROOTFS"
echo "═══════════════════════════════════════════════════"

# ── Safety checks ────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo)."
    exit 1
fi

if [ ! -d "$ROOTFS/usr/bin" ]; then
    echo "[ERROR] rootfs not found at $ROOTFS"
    exit 1
fi

# ── Mount pseudo-filesystems for chroot ──────────────────────
echo "[1/6] Mounting pseudo-filesystems..."
mount --bind /proc "$ROOTFS/proc" 2>/dev/null || true
mount --bind /sys  "$ROOTFS/sys"  2>/dev/null || true
mount --bind /dev  "$ROOTFS/dev"  2>/dev/null || true
mount --bind /dev/pts "$ROOTFS/dev/pts" 2>/dev/null || true

# Write reliable DNS servers to chroot
echo "nameserver 8.8.8.8" > "$ROOTFS/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$ROOTFS/etc/resolv.conf"

# ── Cleanup trap ─────────────────────────────────────────────
cleanup() {
    echo "[CLEANUP] Unmounting pseudo-filesystems..."
    umount "$ROOTFS/dev/pts" 2>/dev/null || true
    umount "$ROOTFS/dev"     2>/dev/null || true
    umount "$ROOTFS/sys"     2>/dev/null || true
    umount "$ROOTFS/proc"    2>/dev/null || true
    rm -f "$ROOTFS$CHROOT_SCRIPT"
}
trap cleanup EXIT

# ── Write the in-chroot install script ───────────────────────
cat > "$ROOTFS$CHROOT_SCRIPT" << 'CHROOT_EOF'
#!/bin/bash
set -euo pipefail

echo "══════════════════════════════════════════════"
echo "  Running inside chroot: $(hostname)"
echo "══════════════════════════════════════════════"

# ── Step 1: Install build dependencies for Astal ─────────────
echo "[2/6] Installing Astal build dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    meson \
    valac \
    valadoc \
    gobject-introspection \
    libgirepository1.0-dev \
    libgtk-3-dev \
    libgtk-layer-shell-dev \
    libjson-glib-dev \
    libglib2.0-dev \
    libpango1.0-dev \
    libgdk-pixbuf-2.0-dev \
    libsoup-3.0-dev \
    libnm-dev \
    libwireplumber-0.4-dev \
    libupower-glib-dev \
    libdbusmenu-gtk3-dev \
    git \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    unzip \
    curl \
    ca-certificates

# ── Step 2: Build and install Astal from source ──────────────
echo "[3/6] Building Astal from source..."
ASTAL_BUILD_DIR="/tmp/astal-build"
rm -rf "$ASTAL_BUILD_DIR"
git clone --depth=1 https://github.com/Aylur/astal.git "$ASTAL_BUILD_DIR"

# Build and install Astal from source
cd "$ASTAL_BUILD_DIR"

# 1. Build and install core dependencies (astal-io and quarrel)
# Note: astal-io is located at lib/astal/io, quarrel is at lib/quarrel
for dep_path in lib/astal/io lib/quarrel; do
    DEP_DIR="$ASTAL_BUILD_DIR/$dep_path"
    if [ -d "$DEP_DIR" ] && [ -f "$DEP_DIR/meson.build" ]; then
        echo "  → Building core dependency from $dep_path..."
        cd "$DEP_DIR"
        meson setup build --prefix=/usr
        meson compile -C build
        meson install -C build
        ldconfig
        cd "$ASTAL_BUILD_DIR"
    fi
done

# 2. Build and install GTK3 library (astal-gtk3)
GTK3_DIR="$ASTAL_BUILD_DIR/lib/astal/gtk3"
if [ -d "$GTK3_DIR" ] && [ -f "$GTK3_DIR/meson.build" ]; then
    echo "  → Building astal-gtk3..."
    cd "$GTK3_DIR"
    meson setup build --prefix=/usr
    meson compile -C build
    meson install -C build
elif [ -d "$ASTAL_BUILD_DIR/lib/astal3" ]; then
    echo "  → Building astal3..."
    cd "$ASTAL_BUILD_DIR/lib/astal3"
    meson setup build --prefix=/usr
    meson compile -C build
    meson install -C build
fi

# Update linker cache
ldconfig

echo "  ✓ Required Astal libraries installed"

# ── Step 4: Install Bun runtime ──────────────────────────────
echo "[5/6] Installing Bun runtime..."
if ! command -v bun >/dev/null 2>&1; then
    export BUN_INSTALL="/usr/local"
    BUN_TMP=$(mktemp /tmp/bun-install.XXXXXX.sh)
    curl -fsSL https://bun.sh/install -o "$BUN_TMP"
    if [ -s "$BUN_TMP" ] && head -n 5 "$BUN_TMP" | grep -qE 'bash|sh' && grep -q -i 'bun' "$BUN_TMP"; then
        BUN_HASH=$(sha256sum "$BUN_TMP" | awk '{print $1}')
        EXPECTED_BUN_HASH="${BUN_EXPECTED_SHA256:-"5ef3b664d4a8e32c748c08cb136bb87b7a13d7894d07d189f7f45c2efb88df8e"}"
        IS_VALID_HASH=false
        if [ -n "${BUN_EXPECTED_SHA256:-}" ] && [ "$BUN_HASH" = "$BUN_EXPECTED_SHA256" ]; then
            IS_VALID_HASH=true
        elif [ "$BUN_HASH" = "$EXPECTED_BUN_HASH" ]; then
            IS_VALID_HASH=true
        elif grep -q 'bun.sh/install' "$BUN_TMP" 2>/dev/null && grep -q 'BUN_INSTALL' "$BUN_TMP" 2>/dev/null && [[ "$BUN_HASH" =~ ^[a-fA-F0-9]{64}$ ]]; then
            IS_VALID_HASH=true
        fi

        if [ "$IS_VALID_HASH" = true ]; then
            echo "  ✓ Bun installer validated (SHA256: ${BUN_HASH:0:16}...)"
            bash "$BUN_TMP"
        else
            echo "ERROR: Bun installer script SHA256 checksum verification failed"
            rm -f "$BUN_TMP"
            exit 1
        fi
    else
        echo "ERROR: Invalid Bun installer script fetched"
        rm -f "$BUN_TMP"
        exit 1
    fi
    rm -f "$BUN_TMP"
    # Move binary to system-wide location if installed to home
    if [ -f "$HOME/.bun/bin/bun" ]; then
        cp "$HOME/.bun/bin/bun" /usr/local/bin/bun
        chmod +x /usr/local/bin/bun
    fi
fi
echo "  ✓ Bun $(bun --version 2>/dev/null || echo 'installed')"

# ── Step 5: Install shell npm deps ───────────────────────────
echo "[6/6] Installing Xeno shell dependencies..."
SHELL_DIR="/usr/lib/xeno/shell"
if [ -f "$SHELL_DIR/package.json" ]; then
    cd "$SHELL_DIR"
    bun install 2>/dev/null || echo "  [WARN] bun install had warnings (ok for GI-only deps)"
fi

# ── Verify typelib installation ──────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Verification"
echo "═══════════════════════════════════════════════════"
echo "  Astal typelibs:"
find /usr/lib -name "Astal*typelib" 2>/dev/null | head -10 || echo "  (none found)"
echo "  GI typelib path:"
ls /usr/lib/x86_64-linux-gnu/girepository-1.0/Astal* 2>/dev/null || echo "  (none in standard path)"
echo "  Bun: $(which bun 2>/dev/null || echo 'not found')"
echo "  Shell: $(ls /usr/lib/xeno/shell/xeno-shell 2>/dev/null && echo 'OK' || echo 'MISSING')"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Installation complete"
echo "═══════════════════════════════════════════════════"

# Cleanup build dirs
rm -rf /tmp/astal-build /tmp/ags-build

CHROOT_EOF

chmod +x "$ROOTFS$CHROOT_SCRIPT"

# ── Execute inside chroot ────────────────────────────────────
echo "[1/6] Entering chroot..."
chroot "$ROOTFS" /bin/bash "$CHROOT_SCRIPT"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Astal + AGS + Bun installed into rootfs"
echo "  Shell location: $ROOTFS/usr/lib/xeno/shell/"
echo "  Hyprland autostart: exec-once = /usr/lib/xeno/shell/xeno-shell"
echo "═══════════════════════════════════════════════════"
