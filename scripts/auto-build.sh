#!/bin/bash
set -e

REPO="YOURGITHUBUSERNAME/xeno-os" # The script will automatically detect this from git, but falls back here
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
TARGET_ISO="/mnt/c/Users/harsh/xeno_os-alpha-v_02.0.iso"

cd "$WS_DIR"

echo "=== Xeno OS Automated Packaging Pipeline ==="

# 1. Verify GitHub CLI auth
if ! gh auth status &>/dev/null; then
    echo "ERROR: GitHub CLI is not authenticated. Run 'gh auth login' first."
    exit 1
fi

# Detect repository name dynamically
DETECTED_REPO=$(git config --get remote.origin.url | sed -E 's/.*github.com[:\/](.*)\.git/\1/')
if [ -n "$DETECTED_REPO" ]; then
    REPO="$DETECTED_REPO"
fi
echo "Targeting Repository: $REPO"

# 2. Query latest successful Actions run for the kernel artifact
echo "Querying GitHub for the latest successful kernel compilation..."
RUN_ID=$(gh run list --workflow="build-kernel.yml" --status=success --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
    echo "ERROR: No successful kernel build runs found on GitHub Actions yet."
    echo "Please wait for your active GitHub Action run to finish and turn green."
    exit 1
fi

echo "Found successful run ID: $RUN_ID"

# 3. Download the .deb packages automatically using the API
echo "Downloading custom kernel deb artifacts..."
sudo rm -rf rootfs/tmp/kernel-debs
sudo mkdir -p rootfs/tmp/kernel-debs
sudo chown -R xeno:xeno rootfs/tmp/kernel-debs

gh run download "$RUN_ID" -n xeno-kernel-debs -D rootfs/tmp/kernel-debs

# Verify debs exist
if [ ! -f rootfs/tmp/kernel-debs/linux-image-*.deb ]; then
    echo "ERROR: Downloaded artifacts are empty or corrupted."
    exit 1
fi

# 4. Bind system partitions and enter chroot to install the packages
echo "Mounting rootfs partitions and performing chroot installation..."
sudo mount --bind /proc rootfs/proc 2>/dev/null || true
sudo mount --bind /sys rootfs/sys 2>/dev/null || true
sudo mount --bind /dev rootfs/dev 2>/dev/null || true

sudo chroot rootfs /bin/bash << 'EOF'
# Force remove conflicting live-boot packages
apt-get purge -y live-boot live-boot-initramfs-tools live-tools
apt-get autoremove -y

# Reinstall stable Casper system
apt-get install -y --reinstall casper

# Force essential modules into target initramfs
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "zstd" >> /etc/initramfs-tools/modules

# Purge any older kernel versions
dpkg --purge $(dpkg -l | grep -E "linux-image|linux-headers" | grep xeno | awk '{print $2}') 2>/dev/null || true

# Install the new Universal Kernel packages downloaded from the API
cd /tmp/kernel-debs
dpkg -i *.deb

# Generate target ramdisk
NEW_VERSION=$(ls /boot/vmlinuz-*xeno* | head -1 | sed 's|/boot/vmlinuz-||')
update-initramfs -c -k "$NEW_VERSION"
apt-get clean
EOF

sudo umount -f rootfs/proc rootfs/sys rootfs/dev 2>/dev/null || true

# 5. Clean staging and copy boot files
echo "Assembling bootloader files..."
sudo rm -rf iso/build/*
mkdir -p iso/build/casper
mkdir -p iso/build/boot/grub/i386-pc

KERNEL=$(ls rootfs/boot/vmlinuz-*xeno* | head -1)
INITRD=$(ls rootfs/boot/initrd.img-*xeno* | head -1)
sudo cp "$KERNEL" iso/build/casper/vmlinuz
sudo cp "$INITRD" iso/build/casper/initrd

# 6. Generate GRUB configuration
cat > iso/build/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0
menuentry "Xeno OS Live (Wayland - Universal)" {
    linux /casper/vmlinuz boot=casper quiet splash
    initrd /casper/initrd
}
EOF

# 7. Compress the root filesystem
echo "Compressing root filesystem into SquashFS (ZSTD L6)..."
sudo rm -f iso/build/casper/filesystem.squashfs
sudo mksquashfs rootfs iso/build/casper/filesystem.squashfs -comp zstd -Xcompression-level 6 -noappend -e rootfs/proc -e rootfs/sys -e rootfs/dev -e rootfs/tmp

# 8. Compile El Torito Boot Record
sudo cp -r /usr/lib/grub/i386-pc/* iso/build/boot/grub/i386-pc/ 2>/dev/null || true
grub-mkimage -O i386-pc -o iso/build/boot/grub/i386-pc/eltorito.img -p '(cd0)/boot/grub' iso9660 biosdisk normal

# 9. Create final ISO and copy to Windows Desktop
echo "Generating bootable xeno_os-alpha-v_02.0.iso..."
sudo grub-mkrescue --xorriso=$(pwd)/xorriso-wrapper.sh -o iso/output/xeno_os-alpha-v_02.0.iso iso/build/

echo "Copying the final bootable ISO directly to Windows C: drive..."
cp iso/output/xeno_os-alpha-v_02.0.iso "$TARGET_ISO"

echo "=== AUTOMATED PIPELINE COMPLETE! ==="
echo "Your bootable ISO is located at: $TARGET_ISO"