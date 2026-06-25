#!/bin/bash
sudo mount --bind /proc rootfs/proc
sudo mount --bind /sys rootfs/sys
sudo mount --bind /dev rootfs/dev
sudo mount --bind /dev/pts rootfs/dev/pts
sudo cp /etc/resolv.conf rootfs/etc/resolv.conf
sudo chroot rootfs /bin/bash
sudo umount rootfs/proc
sudo umount rootfs/sys
sudo umount rootfs/dev/pts
sudo umount rootfs/dev
echo "Exited Xeno OS rootfs"
