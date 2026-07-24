#!/bin/bash
# Shared helpers for rootfs chroot operations.
# shellcheck disable=SC2034

xeno_ws_dir() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    cd "${here}/.." && pwd
}

xeno_rootfs() {
    echo "$(xeno_ws_dir)/rootfs"
}

xeno_chroot_mount() {
    local ROOTFS="$1"
    mountpoint -q "$ROOTFS/proc" 2>/dev/null || mount --bind /proc "$ROOTFS/proc"
    mountpoint -q "$ROOTFS/sys" 2>/dev/null || mount --bind /sys "$ROOTFS/sys"
    mountpoint -q "$ROOTFS/dev" 2>/dev/null || mount --rbind /dev "$ROOTFS/dev"
    if [ -d /dev/pts ]; then
        mkdir -p "$ROOTFS/dev/pts"
        mountpoint -q "$ROOTFS/dev/pts" 2>/dev/null || mount --bind /dev/pts "$ROOTFS/dev/pts" 2>/dev/null || true
    fi
    mkdir -p "$ROOTFS/run"
    mountpoint -q "$ROOTFS/run" 2>/dev/null || mount --bind /run "$ROOTFS/run" 2>/dev/null || true
    # DNS for apt inside chroot
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" 2>/dev/null || {
            printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$ROOTFS/etc/resolv.conf"
        }
    else
        printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$ROOTFS/etc/resolv.conf"
    fi
}

xeno_chroot_umount() {
    local ROOTFS="$1"
    umount -l "$ROOTFS/run" 2>/dev/null || true
    umount -l "$ROOTFS/dev/pts" 2>/dev/null || true
    umount -lR "$ROOTFS/dev" 2>/dev/null || true
    umount -l "$ROOTFS/sys" 2>/dev/null || true
    umount -l "$ROOTFS/proc" 2>/dev/null || true
}

xeno_require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: this script must be run as root (sudo)."
        exit 1
    fi
}

xeno_assert_no_broken_pkgs() {
    local ROOTFS="$1"
    local bad
    bad=$(chroot "$ROOTFS" dpkg -l 2>/dev/null | awk '$1 ~ /U|H|R|F/ {print $2}' || true)
    if [ -n "$bad" ]; then
        echo "ERROR: broken/half-installed packages in rootfs:"
        echo "$bad"
        exit 1
    fi
}
