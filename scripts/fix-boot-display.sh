#!/bin/bash
# ─── Fix Xeno OS Boot-to-GUI ─────────────────────────────────
# This script fixes the blank screen issue by:
# 1. Removing GDM (which conflicts with Hyprland)
# 2. Updating xeno-start-hyprland with proper environment setup
set -e

ROOTFS="/home/xeno/Xeno-os/rootfs"

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — Boot Display Fix"
echo "═══════════════════════════════════════════════════"

# ── 1. Disable conflicting display services ──────────────────
echo "[1/3] Disabling conflicting display services..."
rm -f "$ROOTFS/etc/systemd/system/display-manager.service"
rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-session.service"
rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-x11-session.service"
echo "  ✓ Conflicting services disabled"

# ── 2. Configure realtime security limits ────────────────────
echo "[2/4] Setting up security limits for Hyprland realtime scheduling..."
mkdir -p "$ROOTFS/etc/security/limits.d"
cat > "$ROOTFS/etc/security/limits.d/99-hyprland.conf" << 'LIMITS_EOF'
* soft rtprio 99
* hard rtprio 99
* soft memlock unlimited
* hard memlock unlimited
LIMITS_EOF

# ── 3. Overwrite xeno-start-hyprland with improved version ───
echo "[3/4] Writing updated xeno-start-hyprland..."
cat > "$ROOTFS/usr/bin/xeno-start-hyprland" << 'LAUNCHER_EOF'
#!/bin/bash
# ─── Xeno OS — Hyprland Session Launcher ─────────────────────
# Called by xeno-session.service or .profile to start the Wayland compositor.

# ── 1. Ensure XDG_RUNTIME_DIR exists ─────────────────────────
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_CURRENT_DESKTOP=Hyprland

# ── 2. Detect virtual machines and force software rendering ──
VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "none")
case "$VIRT_TYPE" in
    microsoft|hyperv|oracle|vmware|kvm|qemu|xen|bochs)
        echo "[xeno-start-hyprland] VM detected ($VIRT_TYPE) — enabling software rendering & safe defaults"
        export WLR_RENDERER=pixman
        export WLR_NO_HARDWARE_CURSORS=1
        export LIBGL_ALWAYS_SOFTWARE=1
        export __GLX_VENDOR_LIBRARY_NAME=mesa
        export MESA_LOADER_DRIVER_OVERRIDE=softpipe
        export WLR_RENDERER_ALLOW_SOFTWARE=1
        export GALLIUM_DRIVER=llvmpipe
        export HYPRLAND_NO_RT=1
        ;;
    none|*)
        echo "[xeno-start-hyprland] Bare-metal or unknown — using software rendering as safe default"
        export WLR_RENDERER=pixman
        export WLR_NO_HARDWARE_CURSORS=1
        export LIBGL_ALWAYS_SOFTWARE=1
        export WLR_RENDERER_ALLOW_SOFTWARE=1
        export GALLIUM_DRIVER=llvmpipe
        ;;
esac

# ── 3. Set essential Wayland environment ─────────────────────
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland

# ── 4. Launch via official start-hyprland wrapper to avoid delays & warnings ─
echo "[xeno-start-hyprland] Starting Hyprland via official wrapper..."
if [ -x /usr/bin/start-hyprland ]; then
    exec /usr/bin/start-hyprland --config /home/xeno/.config/hypr/hyprland.conf
else
    exec /usr/bin/Hyprland --config /home/xeno/.config/hypr/hyprland.conf
fi
LAUNCHER_EOF

chmod +x "$ROOTFS/usr/bin/xeno-start-hyprland"
echo "  ✓ xeno-start-hyprland updated"

# ── 3. Verify ────────────────────────────────────────────────
echo "[3/3] Verifying..."
echo "  display-manager.service: $(ls $ROOTFS/etc/systemd/system/display-manager.service 2>/dev/null || echo 'REMOVED ✓')"
echo "  xeno-start-hyprland:     $(ls -la $ROOTFS/usr/bin/xeno-start-hyprland | awk '{print $1, $5, $9}')"
echo "  xeno-session.service:    $(ls $ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-session.service 2>/dev/null && echo 'ENABLED ✗' || echo 'DISABLED ✓')"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Boot display fix complete"
echo "  Now rebuild the ISO: bash scripts/auto-build.sh"
echo "═══════════════════════════════════════════════════"
