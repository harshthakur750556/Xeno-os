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
# Ensure critical hardware and display groups have xeno membership
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

# ── 2.5 Hardware Auto-Detection ──────────────────────────────
echo "[2.5/4] Writing xeno-hardware-detect..."
cat > "$ROOTFS/usr/bin/xeno-hardware-detect" << 'HW_EOF'
#!/bin/bash
# Scan lspci and DRM nodes to set optimal hardware variables
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

# ── 2.6 Automatic Power & CPU Topology Optimizer ─────────────
echo "[2.6/4] Setting up xeno-autotune.service..."
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
ln -sf /etc/systemd/system/xeno-autotune.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/xeno-autotune.service" || true

# ── 3. Hyprland launcher ─────────────────────────────────────
echo "[3/4] Writing updated xeno-start-hyprland..."
cat > "$ROOTFS/usr/bin/xeno-start-hyprland" << 'LAUNCHER_EOF'
#!/bin/bash
# ─── Xeno OS — Hyprland Session Launcher ─────────────────────
set -e

export USER="${USER:-xeno}"
export HOME="${HOME:-/home/xeno}"
export LOGNAME="${LOGNAME:-xeno}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_CURRENT_DESKTOP=Hyprland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11,*}"
export CLUTTER_BACKEND=wayland
export SDL_VIDEODRIVER=wayland

# Wine / Windows apps on Wayland+XWayland
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"

force_software() {
    echo "[xeno-start-hyprland] Software rendering enabled ($1)"
    export WLR_NO_HARDWARE_CURSORS=1
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    export WLR_RENDERER=gles2
    export AQ_FORCE_SOFTWARE=1
    export AQ_NO_MODIFIERS=1
    export HYPRLAND_NO_SD_NOTIFY=1
    export HYPRLAND_NO_RT=1
    unset MESA_LOADER_DRIVER_OVERRIDE || true
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
            if [ -x /usr/bin/xeno-hardware-detect ]; then
                source /usr/bin/xeno-hardware-detect
            fi
            export WLR_NO_HARDWARE_CURSORS="${WLR_NO_HARDWARE_CURSORS:-0}"
            ;;
    esac
fi

# Ensure user config directory exists
mkdir -p "$HOME/.config/hypr"
if [ ! -f "$HOME/.config/hypr/hyprland.conf" ] && [ -f /etc/skel/.config/hypr/hyprland.conf ]; then
    cp -f /etc/skel/.config/hypr/hyprland.conf "$HOME/.config/hypr/hyprland.conf"
fi

echo "[xeno-start-hyprland] Starting Hyprland..."
RUN_CMD="/usr/bin/Hyprland --config $HOME/.config/hypr/hyprland.conf"
if [ -x /usr/bin/start-hyprland ]; then
    RUN_CMD="/usr/bin/start-hyprland --config $HOME/.config/hypr/hyprland.conf"
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    exec dbus-run-session -- $RUN_CMD
else
    exec $RUN_CMD
fi
LAUNCHER_EOF
chmod +x "$ROOTFS/usr/bin/xeno-start-hyprland"

# ── 3.4 Sync live user skeleton configs ───────────────────────
mkdir -p "$ROOTFS/etc/skel/.config/hypr" "$ROOTFS/home/xeno/.config/hypr"
if [ -f "$ROOTFS/home/xeno/.config/hypr/hyprland.conf" ]; then
    cp -f "$ROOTFS/home/xeno/.config/hypr/hyprland.conf" "$ROOTFS/etc/skel/.config/hypr/hyprland.conf"
fi
if [ -f "$ROOTFS/home/xeno/.profile" ]; then
    cp -f "$ROOTFS/home/xeno/.profile" "$ROOTFS/etc/skel/.profile"
fi
if [ -d "$ROOTFS/home/xeno/desktop" ]; then
    mkdir -p "$ROOTFS/etc/skel/desktop"
    cp -rf "$ROOTFS/home/xeno/desktop"/* "$ROOTFS/etc/skel/desktop/" 2>/dev/null || true
fi

# ── 3.5 Serial Console Autologin for QEMU / headless terminal ──
echo "[3.5/4] Configuring serial console autologin on ttyS0..."
mkdir -p "$ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d"
cat > "$ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf" << 'SERIAL_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 --noclear --autologin xeno %I $TERM
SERIAL_EOF
mkdir -p "$ROOTFS/etc/systemd/system/getty.target.wants"
ln -sf /usr/lib/systemd/system/serial-getty@.service "$ROOTFS/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service" 2>/dev/null || true

# ── 4. Verify ────────────────────────────────────────────────
echo "[4/4] Verifying..."
echo "  display-manager.service: $(ls "$ROOTFS/etc/systemd/system/display-manager.service" 2>/dev/null || echo 'REMOVED ✓')"
echo "  xeno-start-hyprland:     $(ls -la "$ROOTFS/usr/bin/xeno-start-hyprland" | awk '{print $1, $5, $9}')"
echo "  limits:                  $ROOTFS/etc/security/limits.d/99-hyprland.conf"
echo "  serial-getty@ttyS0:      $ROOTFS/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✓ Boot display fix complete"
echo "═══════════════════════════════════════════════════"
