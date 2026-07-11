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

# ── 1. Remove GDM display-manager.service symlink ────────────
echo "[1/3] Removing GDM display-manager.service symlink..."
rm -f "$ROOTFS/etc/systemd/system/display-manager.service"
echo "  ✓ GDM disabled (was conflicting with Hyprland)"

# ── 2. Overwrite xeno-start-hyprland with improved version ───
echo "[2/3] Writing updated xeno-start-hyprland..."
cat > "$ROOTFS/usr/bin/xeno-start-hyprland" << 'LAUNCHER_EOF'
#!/bin/bash
# ─── Xeno OS — Hyprland Session Launcher ─────────────────────
# Called by xeno-session.service to start the Wayland compositor.

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
        echo "[xeno-start-hyprland] VM detected ($VIRT_TYPE) — enabling software rendering"
        export WLR_RENDERER=pixman
        export WLR_NO_HARDWARE_CURSORS=1
        export LIBGL_ALWAYS_SOFTWARE=1
        export __GLX_VENDOR_LIBRARY_NAME=mesa
        export MESA_LOADER_DRIVER_OVERRIDE=softpipe
        export WLR_RENDERER_ALLOW_SOFTWARE=1
        export GALLIUM_DRIVER=llvmpipe
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

# ── 4. Launch Hyprland ───────────────────────────────────────
echo "[xeno-start-hyprland] Starting Hyprland..."
exec /usr/bin/Hyprland
LAUNCHER_EOF

chmod +x "$ROOTFS/usr/bin/xeno-start-hyprland"
echo "  ✓ xeno-start-hyprland updated"

# ── 3. Verify ────────────────────────────────────────────────
echo "[3/3] Verifying..."
echo "  display-manager.service: $(ls $ROOTFS/etc/systemd/system/display-manager.service 2>/dev/null || echo 'REMOVED ✓')"
echo "  xeno-start-hyprland:     $(ls -la $ROOTFS/usr/bin/xeno-start-hyprland | awk '{print $1, $5, $9}')"
echo "  xeno-session.service:    $(ls $ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-session.service 2>/dev/null && echo 'ENABLED ✓' || echo 'NOT ENABLED ✗')"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Boot display fix complete"
echo "  Now rebuild the ISO: bash scripts/auto-build.sh"
echo "═══════════════════════════════════════════════════"
