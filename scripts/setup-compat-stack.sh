#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Xeno OS — Windows application compatibility stack
# Wine + Winetricks + Bottles (Flatpak) + DXVK deps + fonts +
# multiarch + gamemode for smooth Windows software on Linux.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"
# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

xeno_require_root
if [ ! -d "$ROOTFS/usr/bin" ]; then
    echo "ERROR: rootfs not found at $ROOTFS"
    exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — Windows Compat Stack Installer"
echo "  Target: $ROOTFS"
echo "═══════════════════════════════════════════════════"

xeno_chroot_mount "$ROOTFS"
cleanup() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup EXIT

chroot "$ROOTFS" /bin/bash << 'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[1/7] Enabling multiarch (i386) for 32-bit Windows apps..."
dpkg --add-architecture i386
apt-get update

echo "[2/7] Installing Wine, Winetricks, fonts, audio, GPU helpers..."
apt-get install -y --no-install-recommends \
    wine \
    wine64 \
    wine32 \
    winetricks \
    wine-binfmt \
    fonts-wine \
    fonts-liberation \
    fonts-dejavu-core \
    cabextract \
    unzip \
    cabextract \
    libvkd3d1 \
    libvkd3d-shader1 \
    vulkan-tools \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    pocl-opencl-icd \
    intel-opencl-icd \
    clinfo \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386 \
    libasound2t64 \
    libasound2t64:i386 \
    pipewire-pulse \
    wireplumber \
    gamemode \
    libgamemode0 \
    libgamemodeauto0 \
    mangohud \
    goverlay \
    desktop-file-utils \
    xdg-utils \
    wget \
    curl \
    ca-certificates \
    gnupg \
    software-properties-common \
    flatpak \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    || apt-get install -y \
        wine wine64 winetricks fonts-wine cabextract \
        vulkan-tools mesa-vulkan-drivers gamemode flatpak

# Optional packages that may not exist on all Ubuntu point releases
for pkg in dxvk libdxvk-d3d9-0 libdxvk-d3d10-0 libdxvk-d3d11-0 lutris steam-installer; do
    apt-get install -y --no-install-recommends "$pkg" 2>/dev/null || true
done

# MS core fonts (accept EULA non-interactively)
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt-get install -y --no-install-recommends ttf-mscorefonts-installer 2>/dev/null || true

echo "[3/7] Configuring Flatpak + Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

echo "[4/7] Installing Bottles + Wine runtimes via Flatpak (best Windows UX)..."
# Bottles is the recommended daily path for Windows apps
flatpak install -y --noninteractive flathub com.usebottles.bottles || true
# Official Wine flatpak as fallback
flatpak install -y --noninteractive flathub org.winehq.Wine || true
# 32-bit GL / codecs for Bottles
flatpak install -y --noninteractive flathub \
    org.freedesktop.Platform.Compat.i386 \
    org.freedesktop.Platform.GL32.default \
    org.freedesktop.Platform.GL.default \
    2>/dev/null || true

echo "[5/7] Wine defaults for smoother app launch..."
mkdir -p /etc/profile.d
cat > /etc/profile.d/xeno-wine.sh << 'EOF'
# Xeno OS — Windows compatibility defaults
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"
# Prefer Wayland when available; apps can override
export WINE_VK_USE_WSI="${WINE_VK_USE_WSI:-1}"
EOF

# binfmt so double-click / ./app.exe works
if command -v update-binfmts >/dev/null 2>&1; then
    update-binfmts --enable wine || true
fi

echo "[6/7] Desktop entries for Windows launchers..."
mkdir -p /usr/share/applications
cat > /usr/share/applications/xeno-bottles.desktop << 'EOF'
[Desktop Entry]
Name=Bottles (Windows Apps)
Comment=Run Windows software smoothly on Xeno OS
Exec=flatpak run com.usebottles.bottles
Icon=com.usebottles.bottles
Terminal=false
Type=Application
Categories=System;Utility;Emulator;
Keywords=wine;windows;exe;proton;
EOF

cat > /usr/share/applications/xeno-winecfg.desktop << 'EOF'
[Desktop Entry]
Name=Wine Configuration
Comment=Configure Wine Windows compatibility layer
Exec=winecfg
Icon=wine
Terminal=false
Type=Application
Categories=System;Settings;
EOF

echo "[7/7] Writing xeno-windows helper..."
cat > /usr/bin/xeno-windows << 'EOF'
#!/bin/bash
# Launch Windows apps the recommended way on Xeno OS.
set -euo pipefail

usage() {
    cat <<'U'
Usage:
  xeno-windows                 # open Bottles GUI
  xeno-windows bottles         # open Bottles GUI
  xeno-windows wine <exe>      # run with system Wine
  xeno-windows winetricks ...  # run winetricks
  xeno-windows doctor          # print compatibility diagnostics
U
}

cmd="${1:-bottles}"
case "$cmd" in
    -h|--help|help) usage; exit 0 ;;
    bottles|"")
        if flatpak info com.usebottles.bottles &>/dev/null; then
            exec flatpak run com.usebottles.bottles
        fi
        echo "Bottles not installed. Falling back to winecfg."
        exec winecfg
        ;;
    wine)
        shift
        if [ "$#" -lt 1 ]; then
            echo "Usage: xeno-windows wine <path-to.exe> [args...]"
            exit 1
        fi
        export WINEESYNC=1 WINEFSYNC=1
        exec wine "$@"
        ;;
    winetricks)
        shift
        exec winetricks "$@"
        ;;
    doctor)
        echo "=== Xeno Windows Compatibility Doctor ==="
        echo "Kernel: $(uname -r)"
        echo -n "NTSYNC: "
        if [ -e /dev/ntsync ] || grep -qw ntsync /proc/devices 2>/dev/null; then
            echo "available"
        else
            echo "not present (Wine still works via esync/fsync)"
        fi
        echo -n "Wine: "; command -v wine >/dev/null && wine --version || echo missing
        echo -n "Winetricks: "; command -v winetricks >/dev/null && echo present || echo missing
        echo -n "Bottles flatpak: "
        flatpak info com.usebottles.bottles &>/dev/null && echo installed || echo missing
        echo -n "Vulkan: "
        command -v vulkaninfo >/dev/null && vulkaninfo --summary 2>/dev/null | head -5 || echo "vulkan-tools missing"
        echo -n "i386 multiarch: "
        dpkg --print-foreign-architectures 2>/dev/null | grep -q i386 && echo yes || echo no
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac
EOF
chmod 755 /usr/bin/xeno-windows

apt-get clean
echo "Windows compatibility stack installed."
CHROOT_EOF

echo "✓ Windows compat stack ready in rootfs"
