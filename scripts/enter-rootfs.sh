#!/bin/bash
set -euo pipefail
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$WS_DIR/rootfs"
# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo bash scripts/enter-rootfs.sh"
    exit 1
fi

xeno_chroot_mount "$ROOTFS"
cleanup() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup EXIT

echo "Entering Xeno OS rootfs at $ROOTFS"
chroot "$ROOTFS" /bin/bash
echo "Exited Xeno OS rootfs"
