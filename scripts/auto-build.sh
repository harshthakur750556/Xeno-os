#!/bin/bash
set -e

REPO="YOURGITHUBUSERNAME/xeno-os" # The script will automatically detect this from git, but falls back here
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
TARGET_ISO="/mnt/c/Users/harsh/xeno_os-3.0-alpha.iso"
if [ ! -d "/mnt/c/Users/harsh" ]; then
    TARGET_ISO="$WS_DIR/iso/output/xeno_os-3.0-alpha.iso"
fi

cd "$WS_DIR"

# Run boot display fix to ensure rootfs is configured correctly
echo "Applying boot display fixes..."
sudo bash scripts/fix-boot-display.sh

echo "=== Xeno OS Automated Packaging Pipeline ==="

# 1. Verify GitHub CLI auth
ACTUAL_USER="${SUDO_USER:-xeno}"
if ! sudo -u "$ACTUAL_USER" gh auth status &>/dev/null && ! gh auth status &>/dev/null; then
    echo "ERROR: GitHub CLI is not authenticated. Run 'gh auth login' first."
    exit 1
fi

# Detect repository name dynamically
DETECTED_REPO=$(git config --get remote.origin.url | sed -E 's/.*github.com[:\/](.*)\.git/\1/')
if [ -n "$DETECTED_REPO" ]; then
    REPO="$DETECTED_REPO"
fi
echo "Targeting Repository: $REPO"

# 2. Smart Kernel Backup Cache & Automated Monthly Rollout Check
CACHE_DIR="$WS_DIR/kernel/cache"
META_FILE="$CACHE_DIR/latest_release.json"
mkdir -p "$CACHE_DIR"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CACHE_DIR"

echo "Checking custom kernel backup cache & rollout status..."

NEED_DOWNLOAD=false
REMOTE_TAG=""

RELEASE_INFO=$(sudo -u "$ACTUAL_USER" gh release view -R "$REPO" --json tagName,publishedAt 2>/dev/null || true)
if [ -n "$RELEASE_INFO" ]; then
    REMOTE_TAG=$(echo "$RELEASE_INFO" | jq -r '.tagName // empty')
fi

if ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null && [ -f "$META_FILE" ]; then
    LOCAL_TAG=$(jq -r '.tagName // empty' "$META_FILE" 2>/dev/null || true)
    
    if [ -n "$REMOTE_TAG" ] && [ "$REMOTE_TAG" != "$LOCAL_TAG" ]; then
        echo "[ROLLOUT DETECTED] Remote release ($REMOTE_TAG) differs from local cache ($LOCAL_TAG). Updating backup cache..."
        NEED_DOWNLOAD=true
    else
        echo "[KERNEL CACHE VALID] Local backup ($LOCAL_TAG) is up-to-date with latest release ($REMOTE_TAG). Bypassing download."
    fi
else
    echo "[INITIAL DOWNLOAD] No valid kernel backup found in kernel/cache/. Fetching latest release..."
    NEED_DOWNLOAD=true
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "Downloading kernel packages from GitHub Release..."
    sudo -u "$ACTUAL_USER" gh release download -R "$REPO" --pattern "*.deb" -D "$CACHE_DIR" --clobber
    if [ -n "$RELEASE_INFO" ]; then
        echo "$RELEASE_INFO" > "$META_FILE"
    fi
fi

# Stage packages for rootfs chroot installation
sudo rm -rf rootfs/tmp/kernel-debs
sudo mkdir -p rootfs/tmp/kernel-debs
sudo cp "$CACHE_DIR"/*.deb rootfs/tmp/kernel-debs/

# Verify debs exist
if ! ls rootfs/tmp/kernel-debs/linux-image-*.deb &>/dev/null; then
    echo "ERROR: Downloaded kernel artifacts are empty or corrupted."
    exit 1
fi

# 4. Bind system partitions and enter chroot to install the packages
echo "Mounting rootfs partitions and performing chroot installation..."
sudo mount --bind /proc rootfs/proc 2>/dev/null || true
sudo mount --bind /sys rootfs/sys 2>/dev/null || true
sudo mount --bind /dev rootfs/dev 2>/dev/null || true
sudo mount --bind /dev/pts rootfs/dev/pts 2>/dev/null || true

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
dpkg -i *.deb || apt-get install -f -y

# Generate target ramdisk
NEW_VERSION=$(ls /boot/vmlinuz-*xeno* 2>/dev/null | head -1 | sed 's|/boot/vmlinuz-||')
if [ -z "$NEW_VERSION" ]; then
    echo "ERROR: Kernel vmlinuz image not found in /boot!"
    exit 1
fi
update-initramfs -c -k "$NEW_VERSION" || update-initramfs -u -k "$NEW_VERSION"
apt-get clean
EOF

sudo umount -l rootfs/dev/pts 2>/dev/null || true
sudo umount -l rootfs/dev 2>/dev/null || true
sudo umount -l rootfs/proc 2>/dev/null || true
sudo umount -l rootfs/sys 2>/dev/null || true

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
    linux /casper/vmlinuz boot=casper quiet splash username=xeno hostname=xeno-os ---
    initrd /casper/initrd
}
EOF

# 6b. Sync updated desktop environment and tests into rootfs
echo "Syncing updated desktop environment and tests into rootfs..."
sudo rsync -a --delete "$WS_DIR/desktop/" "$WS_DIR/rootfs/home/xeno/desktop/"
sudo rsync -a --delete "$WS_DIR/tests/" "$WS_DIR/rootfs/home/xeno/tests/"
sudo chown -R 1000:1000 "$WS_DIR/rootfs/home/xeno/desktop" "$WS_DIR/rootfs/home/xeno/tests"

# 7. Compress the root filesystem
echo "Compressing root filesystem into SquashFS (ZSTD L6)..."
sudo rm -f iso/build/casper/filesystem.squashfs
sudo mksquashfs rootfs iso/build/casper/filesystem.squashfs -comp zstd -Xcompression-level 6 -noappend -e rootfs/proc -e rootfs/sys -e rootfs/dev -e rootfs/tmp

# 8. Compile El Torito Boot Record
sudo cp -r /usr/lib/grub/i386-pc/* iso/build/boot/grub/i386-pc/ 2>/dev/null || true
grub-mkimage -O i386-pc -o iso/build/boot/grub/i386-pc/eltorito.img -p '(cd0)/boot/grub' iso9660 biosdisk normal

# 9. Create final ISO and copy to Windows Desktop
echo "Generating bootable xeno_os-3.0-alpha.iso..."
sudo grub-mkrescue --xorriso=$(pwd)/xorriso-wrapper.sh -o iso/output/xeno_os-3.0-alpha.iso iso/build/

echo "Copying the final bootable ISO directly to Windows C: drive..."
cp iso/output/xeno_os-3.0-alpha.iso "$TARGET_ISO" 2>/dev/null || true

echo "=== AUTOMATED PIPELINE COMPLETE! ==="
echo "Your bootable ISO is located at: $TARGET_ISO"