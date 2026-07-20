#!/bin/bash
# ─── Fix Xeno OS Boot-to-GUI ─────────────────────────────────
# 1. Remove GDM conflicts with Hyprland
# 2. Configure realtime limits (scoped, not global *)
# 3. Install xeno-start-hyprland with VM vs bare-metal GL paths
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"

if [ ! -d "$ROOTFS/usr/bin" ]; then
    echo "ERROR: rootfs not found at $ROOTFS"
    exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — Boot Display Fix"
echo "  Target: $ROOTFS"
echo "═══════════════════════════════════════════════════"

# ── 1. Disable conflicting display services ──────────────────
echo "[1/4] Disabling conflicting display services..."
rm -f "$ROOTFS/etc/systemd/system/display-manager.service"
rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-session.service"
rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-x11-session.service"
echo "  ✓ Conflicting services disabled"

# ── 2. Scoped realtime limits (not world-writable RT) ────────
echo "[2/4] Setting up scoped security limits for Hyprland..."
mkdir -p "$ROOTFS/etc/security/limits.d"
# Create hyprland group membership for live user
if [ -f "$ROOTFS/etc/group" ] && ! grep -q '^hyprland:' "$ROOTFS/etc/group"; then
    # Use a high GID unlikely to collide
    echo "hyprland:x:991:xeno" >> "$ROOTFS/etc/group"
fi
if [ -f "$ROOTFS/etc/group" ] && grep -q '^xeno:' "$ROOTFS/etc/group"; then
    # ensure xeno in hyprland group
    if ! grep -q '^hyprland:.*xeno' "$ROOTFS/etc/group"; then
        sed -i 's/^hyprland:x:\([0-9]*\):.*/hyprland:x:\1:xeno/' "$ROOTFS/etc/group" 2>/dev/null || true
    fi
fi
cat > "$ROOTFS/etc/security/limits.d/99-hyprland.conf" << 'LIMITS_EOF'
# Scoped RT privileges — NOT '*' (that was a security loophole)
@hyprland soft rtprio 99
@hyprland hard rtprio 99
@hyprland soft memlock unlimited
@hyprland hard memlock unlimited
xeno soft rtprio 99
xeno hard rtprio 99
xeno soft memlock unlimited
xeno hard memlock unlimited
LIMITS_EOF

# ── 3. Hyprland launcher ─────────────────────────────────────
echo "[3/4] Writing updated xeno-start-hyprland..."
cat > "$ROOTFS/usr/bin/xeno-start-hyprland" << 'LAUNCHER_EOF'
#!/bin/bash
# ─── Xeno OS — Hyprland Session Launcher ─────────────────────
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_CURRENT_DESKTOP=Hyprland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export GDK_BACKEND="${GDK_BACKEND:-wayland}"
# Wine / Windows apps on Wayland+XWayland
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"

force_software() {
    echo "[xeno-start-hyprland] Software rendering enabled ($1)"
    export WLR_RENDERER=pixman
    export WLR_NO_HARDWARE_CURSORS=1
    export LIBGL_ALWAYS_SOFTWARE=1
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export MESA_LOADER_DRIVER_OVERRIDE=softpipe
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export HYPRLAND_NO_RT=1
}

# Kernel cmdline opt: xeno.safegraphics=1
if grep -qw 'xeno.safegraphics=1' /proc/cmdline 2>/dev/null; then
    force_software "cmdline"
else
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "none")
    case "$VIRT_TYPE" in
        microsoft|hyperv|oracle|vmware|kvm|qemu|xen|bochs)
            force_software "VM:$VIRT_TYPE"
            ;;
        none|*)
            # Bare metal: prefer hardware GL/Vulkan for smooth desktop + Windows apps
            echo "[xeno-start-hyprland] Bare-metal — hardware rendering"
            unset LIBGL_ALWAYS_SOFTWARE || true
            unset MESA_LOADER_DRIVER_OVERRIDE || true
            unset GALLIUM_DRIVER || true
            export WLR_NO_HARDWARE_CURSORS="${WLR_NO_HARDWARE_CURSORS:-0}"
            ;;
    esac
fi

echo "[xeno-start-hyprland] Starting Hyprland..."
if [ -x /usr/bin/start-hyprland ]; then
    exec /usr/bin/start-hyprland --config /home/xeno/.config/hypr/hyprland.conf
else
    exec /usr/bin/Hyprland --config /home/xeno/.config/hypr/hyprland.conf
fi
LAUNCHER_EOF
chmod +x "$ROOTFS/usr/bin/xeno-start-hyprland"

# ── 4. Verify ────────────────────────────────────────────────
echo "[4/4] Verifying..."
echo "  display-manager.service: $(ls "$ROOTFS/etc/systemd/system/display-manager.service" 2>/dev/null || echo 'REMOVED ✓')"
echo "  xeno-start-hyprland:     $(ls -la "$ROOTFS/usr/bin/xeno-start-hyprland" | awk '{print $1, $5, $9}')"
echo "  limits:                  $ROOTFS/etc/security/limits.d/99-hyprland.conf"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Boot display fix complete"
echo "═══════════════════════════════════════════════════"
