#!/bin/bash
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_VER=$(grep '^ACTIVE_VERSION=' "$WS_DIR/iso/version.txt" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
if [ -z "$BUILD_VER" ]; then
    BUILD_VER=$(grep -v '^#' "$WS_DIR/iso/version.txt" 2>/dev/null | head -n1 | tr -d '[:space:]')
fi
[ -z "$BUILD_VER" ] && BUILD_VER="10.0-beta"
ISO_PATH=""
CANDIDATE_PATHS=(
    "$WS_DIR/iso/output/BETA VERSION/xeno_os-${BUILD_VER}.iso"
    "$WS_DIR/iso/output/BETA VERSION/xeno_os-${BUILD_VER}-beta.iso"
    "$WS_DIR/iso/output/ALPHA VERSION/xeno_os-${BUILD_VER}-alpha.iso"
    "$WS_DIR/iso/output/ALPHA VERSION/xeno_os-${BUILD_VER}.iso"
    "$WS_DIR/iso/output/xeno_os-${BUILD_VER}.iso"
    "$WS_DIR/iso/output/xeno_os-${BUILD_VER}-beta.iso"
    "$WS_DIR/iso/output/xeno_os-${BUILD_VER}-alpha.iso"
    "/mnt/c/Users/harsh/BETA VERSION/xeno_os-${BUILD_VER}.iso"
    "/mnt/c/Users/harsh/BETA VERSION/xeno_os-${BUILD_VER}-beta.iso"
    "/mnt/c/Users/harsh/ALPHA VERSION/xeno_os-${BUILD_VER}-alpha.iso"
    "/mnt/c/Users/harsh/xeno_os-${BUILD_VER}.iso"
    "/mnt/c/Users/harsh/xeno_os-${BUILD_VER}-beta.iso"
    "/mnt/c/Users/harsh/xeno_os-${BUILD_VER}-alpha.iso"
)

for p in "${CANDIDATE_PATHS[@]}"; do
    if [ -f "$p" ]; then
        ISO_PATH="$p"
        break
    fi
done

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
    LATEST_ISO=$(ls "$WS_DIR/iso/output"/ALPHA\ VERSION/xeno_os-*.iso "$WS_DIR/iso/output"/BETA\ VERSION/xeno_os-*.iso "$WS_DIR/iso/output"/xeno_os-*.iso /mnt/c/Users/harsh/ALPHA\ VERSION/xeno_os-*.iso /mnt/c/Users/harsh/xeno_os-*.iso 2>/dev/null | tail -n 1 || true)
    if [ -n "$LATEST_ISO" ]; then
        ISO_PATH="$LATEST_ISO"
    fi
fi

OVMF_BIOS=""
for p in /usr/share/OVMF/OVMF_CODE.fd /usr/share/ovmf/OVMF.fd /usr/share/qemu/OVMF.fd /usr/share/edk2-ovmf/x64/OVMF.fd; do
    if [ -f "$p" ]; then
        OVMF_BIOS="$p"
        break
    fi
done

BIOS_ARGS=()
if [ -n "$OVMF_BIOS" ]; then
    BIOS_ARGS+=("-bios" "$OVMF_BIOS")
fi

MODE="auto"
for arg in "$@"; do
    case "$arg" in
        --gui|-g) MODE="gui" ;;
        --nographic|-n|--terminal|-t) MODE="nographic" ;;
    esac
done

if [ "$MODE" = "auto" ]; then
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        MODE="gui"
    else
        MODE="nographic"
    fi
fi

echo "Booting ISO in QEMU ($MODE mode): $ISO_PATH"

if [ "$MODE" = "gui" ]; then
    # Graphical window mode (renders Wayland/Hyprland GUI on screen)
    qemu-system-x86_64 \
      -m 4096 \
      -smp 4 \
      -cpu max \
      "${BIOS_ARGS[@]}" \
      -vga virtio \
      -usb -device usb-tablet \
      -cdrom "$ISO_PATH" \
      -boot d
else
    # Terminal serial mode (headless stdio)
    echo "Note: Running in headless terminal mode. Exit with Ctrl+A then X."
    qemu-system-x86_64 \
      -m 4096 \
      -smp 4 \
      -cpu max \
      "${BIOS_ARGS[@]}" \
      -cdrom "$ISO_PATH" \
      -boot d \
      -nographic \
      -serial mon:stdio \
      -no-reboot | tee xeno-serial.log
fi


