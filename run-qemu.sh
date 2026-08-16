#!/bin/bash
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_VER=$(tr -d '[:space:]' < "$WS_DIR/iso/version.txt" 2>/dev/null || echo "6.0")
ISO_PATH="$WS_DIR/iso/output/xeno_os-${BUILD_VER}-alpha.iso"

if [ ! -f "$ISO_PATH" ] && [ -f "/mnt/c/Users/harsh/xeno_os-${BUILD_VER}-alpha.iso" ]; then
    ISO_PATH="/mnt/c/Users/harsh/xeno_os-${BUILD_VER}-alpha.iso"
fi

if [ ! -f "$ISO_PATH" ]; then
    LATEST_ISO=$(ls "$WS_DIR/iso/output"/xeno_os-*.iso /mnt/c/Users/harsh/xeno_os-*.iso 2>/dev/null | tail -n 1 || true)
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


