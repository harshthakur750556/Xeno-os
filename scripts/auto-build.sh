#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Xeno OS — Full ISO packaging pipeline
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$WS_DIR/iso/version.txt"
mkdir -p "$WS_DIR/iso"
if [ -f "$VERSION_FILE" ]; then
    BUILD_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
else
    BUILD_VERSION="4.0"
fi

ISO_NAME="xeno_os-${BUILD_VERSION}-alpha.iso"
if [ -n "${XENO_ISO_DEST:-}" ]; then
    if [ -d "$XENO_ISO_DEST" ]; then
        TARGET_ISO="$XENO_ISO_DEST/${ISO_NAME}"
    else
        TARGET_ISO="$XENO_ISO_DEST"
    fi
elif [ -d "/mnt/c/Users/harsh" ]; then
    TARGET_ISO="/mnt/c/Users/harsh/${ISO_NAME}"
else
    TARGET_ISO="$WS_DIR/iso/output/${ISO_NAME}"
fi

# Clean up all older ISO versions (v1, v2, v3, etc.)
find "$WS_DIR/iso/output" -name "xeno_os*.iso" ! -name "${ISO_NAME}" -delete 2>/dev/null || true
if [ -d "$(dirname "$TARGET_ISO")" ] && [ "$TARGET_ISO" != "$WS_DIR/iso/output/${ISO_NAME}" ]; then
    find "$(dirname "$TARGET_ISO")" -maxdepth 1 -name "xeno_os*.iso" ! -name "${ISO_NAME}" -delete 2>/dev/null || true
fi
ROOTFS="$WS_DIR/rootfs"
CACHE_DIR="$WS_DIR/kernel/cache"
META_FILE="$CACHE_DIR/latest_release.json"
VOLUME_ID="XENOOS"
# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

cd "$WS_DIR"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo bash scripts/auto-build.sh"
    exit 1
fi

exec 9>/tmp/xeno-auto-build.lock
if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import fcntl; fcntl.fcntl(9, fcntl.F_SETFD, fcntl.FD_CLOEXEC)' 2>/dev/null || true
fi
flock -n --cloexec 9 2>/dev/null || flock -n 9 || { echo "ERROR: auto-build.sh is already running."; exit 1; }

echo "=== Xeno OS Automated Packaging Pipeline ==="
echo "Workspace: $WS_DIR"

# ── 0. Boot display / session fixes ──────────────────────────
echo "Applying boot display fixes..."
bash "$WS_DIR/scripts/fix-boot-display.sh"

# ── 1. GitHub auth (for kernel release download) ─────────────
ACTUAL_USER="${SUDO_USER:-xeno}"
if ! sudo -u "$ACTUAL_USER" gh auth status &>/dev/null && ! gh auth status &>/dev/null; then
    echo "ERROR: GitHub CLI is not authenticated. Run 'gh auth login' first."
    exit 1
fi

DETECTED_REPO=$(git config --get remote.origin.url | sed -E 's#.*github.com[:/](.+)(\.git)?$#\1#' | sed 's/\.git$//')
REPO="${DETECTED_REPO:-YOURGITHUBUSERNAME/xeno-os}"
echo "Targeting Repository: $REPO"

# ── 2. Kernel cache / release fetch ──────────────────────────
mkdir -p "$CACHE_DIR" "$WS_DIR/iso/output"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$CACHE_DIR" 2>/dev/null || true

echo "Checking custom kernel backup cache & rollout status..."
NEED_DOWNLOAD=false
REMOTE_TAG=""

# First check if fresh local build exists in kernel/output
if ls "$WS_DIR/kernel/output"/linux-image-*.deb &>/dev/null; then
    echo "Found local kernel build in kernel/output. Staging..."
    bash "$WS_DIR/scripts/stage-kernel-debs.sh" || true
fi

RELEASE_INFO=$(sudo -u "$ACTUAL_USER" gh release view -R "$REPO" --json tagName,publishedAt 2>/dev/null || true)
if [ -n "$RELEASE_INFO" ]; then
    REMOTE_TAG=$(echo "$RELEASE_INFO" | jq -r '.tagName // empty')
fi

if ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null && [ -f "$META_FILE" ]; then
    LOCAL_TAG=$(jq -r '.tagName // empty' "$META_FILE" 2>/dev/null || true)
    if [ -n "$REMOTE_TAG" ] && [ "$REMOTE_TAG" != "$LOCAL_TAG" ] && [[ "$LOCAL_TAG" != local-build-* ]]; then
        echo "[ROLLOUT DETECTED] Remote ($REMOTE_TAG) != local ($LOCAL_TAG). Updating..."
        NEED_DOWNLOAD=true
    else
        echo "[KERNEL CACHE] Local backup tag=$LOCAL_TAG remote=$REMOTE_TAG"
    fi
else
    echo "[INITIAL DOWNLOAD] Fetching latest kernel release..."
    NEED_DOWNLOAD=true
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "Downloading kernel packages from GitHub Release..."
    rm -f "$CACHE_DIR"/*.deb
    if sudo -u "$ACTUAL_USER" gh release download -R "$REPO" --pattern "*.deb" -D "$CACHE_DIR" --clobber 2>/dev/null; then
        if [ -n "$RELEASE_INFO" ]; then
            echo "$RELEASE_INFO" > "$META_FILE"
        fi
    else
        echo "WARNING: Failed to download release debs from GitHub. Using local cache if present."
    fi
fi

if ! ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
    echo "ERROR: no linux-image-*.deb in $CACHE_DIR"
    exit 1
fi

# ── 3. Validate kernel debs (show-stopper gate) ──────────────
KERNEL_VALID=0
if bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$CACHE_DIR"; then
    KERNEL_VALID=1
    echo "✓ Kernel debs passed WLAN/module validation"
else
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  FATAL: kernel debs failed validation."
    echo "  Refusing to ship a Wi-Fi-broken custom kernel."
    echo ""
    echo "  Fix: rebuild kernel via CI (patches + WLAN fragment):"
    echo "    gh workflow run build-kernel.yml"
    echo "  Or wait for schedule / push under kernel/**"
    echo "════════════════════════════════════════════════════"
    # Fall back ONLY if Ubuntu generic is present so ISO still boots
    if ! ls "$ROOTFS"/boot/vmlinuz-*-generic &>/dev/null; then
        echo "ERROR: no generic fallback kernel either. Aborting."
        exit 1
    fi
    echo "Continuing with Ubuntu generic kernel fallback for this ISO build."
    KERNEL_VALID=0
fi

# ── 4. Repair / install kernel into rootfs ───────────────────
if [ "$KERNEL_VALID" = "1" ]; then
    # Use validated debs
    bash "$WS_DIR/scripts/fix-kernel-rootfs.sh"
else
    # Purge broken custom kernels; keep generic
    XENO_SKIP_CUSTOM=1 bash "$WS_DIR/scripts/fix-kernel-rootfs.sh" || true
fi

# ── 5. Sync desktop & install feature stacks ─────────────────
echo "Syncing desktop environment and tests into rootfs..."
rsync -a --delete \
    --exclude='*.local' \
    --exclude='.config/' \
    --exclude='custom/' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='*.pyo' \
    --exclude='.pytest_cache' \
    --exclude='node_modules' \
    --exclude='.git' \
    "$WS_DIR/desktop/" "$ROOTFS/home/xeno/desktop/"

rsync -a --delete \
    --exclude='*.local' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='*.pyo' \
    --exclude='.pytest_cache' \
    --exclude='.git' \
    "$WS_DIR/tests/" "$ROOTFS/home/xeno/tests/"
chown -R 1000:1000 "$ROOTFS/home/xeno/desktop" "$ROOTFS/home/xeno/tests" 2>/dev/null || true

# Clean up developer history files so they do not leak into ISO
rm -f "$ROOTFS/home/xeno/.bash_history" "$ROOTFS/home/xeno/.lesshst" "$ROOTFS/home/xeno/.python_history" 2>/dev/null || true
rm -f "$ROOTFS/root/.bash_history" "$ROOTFS/root/.lesshst" 2>/dev/null || true

# Ensure Windows + security tools present (idempotent)
if [ "${XENO_SKIP_FEATURE_SETUP:-0}" != "1" ]; then
    run_feature_step() {
        local step_name="$1"
        shift
        echo "Installing ${step_name} into rootfs..."
        if ! "$@"; then
            if [ "${XENO_STRICT_BUILD:-1}" = "1" ]; then
                echo "FATAL: ${step_name} failed under XENO_STRICT_BUILD=1"
                exit 1
            else
                echo "WARNING: ${step_name} setup had errors (non-fatal mode)"
            fi
        fi
    }

    if [ ! -x "$ROOTFS/usr/bin/xeno-windows" ] || [ "${XENO_FORCE_FEATURE_SETUP:-0}" = "1" ]; then
        run_feature_step "Windows compatibility stack" bash "$WS_DIR/scripts/setup-compat-stack.sh"
    fi
    if [ ! -x "$ROOTFS/usr/bin/xeno-wifi-monitor" ] || [ "${XENO_FORCE_FEATURE_SETUP:-0}" = "1" ]; then
        run_feature_step "Security/wireless tools" bash "$WS_DIR/scripts/setup-security-tools.sh"
    fi
    if [ ! -x "$ROOTFS/usr/bin/xeno-ai-engine" ] || [ "${XENO_FORCE_FEATURE_SETUP:-0}" = "1" ]; then
        run_feature_step "AI Engine" bash "$WS_DIR/scripts/setup-ai.sh"
    fi
    if [ -x "$WS_DIR/drivers/install-oot-wifi.sh" ]; then
        run_feature_step "OOT WiFi drivers" env XENO_ROOTFS="$ROOTFS" bash "$WS_DIR/drivers/install-oot-wifi.sh"
    fi
fi

# Re-assert no broken packages after feature setup
xeno_assert_no_broken_pkgs "$ROOTFS"

# ── 6. Casper / initramfs essentials ─────────────────────────
echo "Mounting rootfs and ensuring casper live stack..."
xeno_chroot_mount "$ROOTFS"
cleanup_mounts() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup_mounts EXIT

chroot "$ROOTFS" /bin/bash << 'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y live-boot live-boot-initramfs-tools live-tools 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
apt-get install -y --reinstall casper

# 6.1 ZRAM Setup
apt-get install -y --no-install-recommends systemd-zram-generator 2>/dev/null || true
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf.d/zram0.conf << 'ZRAM_EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM_EOF

# 6.3 Bloat Removal
apt-get purge -y snapd apport whoopsie cups geoclue-2.0 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

mkdir -p /etc/initramfs-tools
for m in overlay squashfs zstd nls_utf8 isofs sr_mod sd_mod ahci; do
    grep -qxF "$m" /etc/initramfs-tools/modules 2>/dev/null || echo "$m" >> /etc/initramfs-tools/modules
done

# Select boot kernel: prefer validated xeno, else generic
if ls /boot/vmlinuz-*xeno* >/dev/null 2>&1; then
    KIMG=$(ls /boot/vmlinuz-*xeno* 2>/dev/null | grep -v dpkg-new | sort -V | tail -1 || true)
else
    KIMG=""
fi
if [ -z "$KIMG" ]; then
    KIMG=$(ls /boot/vmlinuz-*-generic 2>/dev/null | sort -V | tail -1)
fi
if [ -z "$KIMG" ]; then
    echo "ERROR: no bootable vmlinuz found"
    exit 1
fi
NEW_VERSION="${KIMG#/boot/vmlinuz-}"
echo "Boot kernel version: $NEW_VERSION"
echo "Regenerating initramfs with casper live boot modules for $NEW_VERSION..."
update-initramfs -u -k "$NEW_VERSION" || update-initramfs -c -k "$NEW_VERSION"

# Reject broken package state
bad=$(dpkg -l | awk '$1 ~ /U|H|R|F/ {print $2}')
if [ -n "$bad" ]; then
    echo "ERROR: broken packages remain:"
    echo "$bad"
    exit 1
fi
# Reject dpkg-new modules
if find /lib/modules -name '*.dpkg-new' 2>/dev/null | grep -q .; then
    echo "ERROR: *.dpkg-new modules present — kernel install incomplete"
    exit 1
fi
apt-get clean
echo "$NEW_VERSION" > /tmp/xeno-boot-kver
EOF

KVER=$(cat "$ROOTFS/tmp/xeno-boot-kver")
echo "Using kernel: $KVER"

# ── 7. Assemble casper boot files ────────────────────────────
echo "Assembling bootloader files..."
rm -rf "$WS_DIR/iso/build"/*
mkdir -p "$WS_DIR/iso/build/casper" "$WS_DIR/iso/build/boot/grub/i386-pc"

KERNEL_SRC="$ROOTFS/boot/vmlinuz-$KVER"
INITRD_SRC="$ROOTFS/boot/initrd.img-$KVER"
if [ ! -f "$KERNEL_SRC" ] || [ ! -f "$INITRD_SRC" ]; then
    echo "ERROR: missing $KERNEL_SRC or $INITRD_SRC"
    exit 1
fi
cp "$KERNEL_SRC" "$WS_DIR/iso/build/casper/vmlinuz"
cp "$INITRD_SRC" "$WS_DIR/iso/build/casper/initrd"

# Generate filesystem.manifest for Casper live boot validation
chroot "$ROOTFS" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WS_DIR/iso/build/casper/filesystem.manifest"

cat > "$WS_DIR/iso/build/boot/grub/grub.cfg" << 'EOF'
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input serial console
terminal_output serial console

set timeout=5
set default=0
menuentry "Xeno OS Live (Wayland - Universal)" {
    linux /casper/vmlinuz boot=casper console=ttyS0,115200n8 console=tty1 quiet splash username=xeno hostname=xeno-os ---
    initrd /casper/initrd
}
menuentry "Xeno OS Live (Safe graphics)" {
    linux /casper/vmlinuz boot=casper console=ttyS0,115200n8 console=tty1 quiet splash username=xeno hostname=xeno-os xeno.safegraphics=1 ---
    initrd /casper/initrd
}
EOF

# ── 8. SquashFS ──────────────────────────────────────────────
echo "Compressing root filesystem into SquashFS (ZSTD L6)..."
rm -f "$WS_DIR/iso/build/casper/filesystem.squashfs"
mksquashfs "$ROOTFS" "$WS_DIR/iso/build/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 6 -noappend \
    -e "$ROOTFS/proc" -e "$ROOTFS/sys" -e "$ROOTFS/dev" -e "$ROOTFS/tmp" \
    -e "$ROOTFS/run" -e "$ROOTFS/var/cache/apt/archives"

# Generate filesystem.size for Casper live boot validation
printf $(du -sx --block-size=1 "$ROOTFS" | cut -f1) > "$WS_DIR/iso/build/casper/filesystem.size"

# ── 9. GRUB ISO (Dual BIOS i386-pc + UEFI x86_64-efi via wrapper) ──
mkdir -p "$WS_DIR/iso/build/boot/grub/i386-pc" "$WS_DIR/iso/build/boot/grub/x86_64-efi" "$WS_DIR/iso/build/EFI/BOOT"
cp -r /usr/lib/grub/i386-pc/* "$WS_DIR/iso/build/boot/grub/i386-pc/" 2>/dev/null || true

grub-mkimage -O i386-pc -o "$WS_DIR/iso/build/boot/grub/i386-pc/eltorito.img" \
    -p '(cd0)/boot/grub' iso9660 biosdisk normal

# Generate standalone UEFI boot binary (BOOTX64.EFI) and FAT EFI System Partition image (efi.img)
if [ -d "/usr/lib/grub/x86_64-efi" ]; then
    echo "Building UEFI x86_64-efi bootloader..."
    cp -r /usr/lib/grub/x86_64-efi/* "$WS_DIR/iso/build/boot/grub/x86_64-efi/" 2>/dev/null || true
    
    grub-mkimage -O x86_64-efi -o "$WS_DIR/iso/build/EFI/BOOT/BOOTX64.EFI" \
        -p '/boot/grub' iso9660 fat part_gpt part_msdos normal boot linux configfile tar search search_fs_file search_label search_fs_uuid efi_gop efi_uga gfxterm gfxmenu
    
    # Generate FAT EFI System Partition image (efi.img) for El Torito alt boot / UEFI hardware compatibility
    dd if=/dev/zero of="$WS_DIR/iso/build/boot/grub/efi.img" bs=1k count=4096 2>/dev/null || true
    mkfs.vfat "$WS_DIR/iso/build/boot/grub/efi.img" 2>/dev/null || true
    if command -v mcopy >/dev/null 2>&1; then
        mmd -i "$WS_DIR/iso/build/boot/grub/efi.img" ::EFI ::EFI/BOOT 2>/dev/null || true
        mcopy -i "$WS_DIR/iso/build/boot/grub/efi.img" "$WS_DIR/iso/build/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
    fi
fi

echo "Generating bootable ISO (${ISO_NAME})..."
mkdir -p "$WS_DIR/iso/output"
LOCAL_ISO_PATH="$WS_DIR/iso/output/${ISO_NAME}"

grub-mkrescue --xorriso="$WS_DIR/xorriso-wrapper.sh" \
    -volid "$VOLUME_ID" \
    -o "$LOCAL_ISO_PATH" "$WS_DIR/iso/build/"

# Generate SHA256 checksum for ISO artifact validation
echo "Generating SHA256 checksum..."
(cd "$WS_DIR/iso/output" && sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256")

if [ "$TARGET_ISO" != "$LOCAL_ISO_PATH" ]; then
    echo "Copying ISO to target location: $TARGET_ISO..."
    if ! cp "$LOCAL_ISO_PATH" "$TARGET_ISO" 2>/dev/null; then
        echo "Standard cp failed (likely WSL /mnt 9P memory limit) — attempting chunked dd copy..."
        dd if="$LOCAL_ISO_PATH" of="$TARGET_ISO" bs=64M status=progress conv=fsync || {
            echo "WARNING: Could not copy ISO to $TARGET_ISO. Local copy remains safe at $LOCAL_ISO_PATH."
        }
    fi
    cp "${LOCAL_ISO_PATH}.sha256" "${TARGET_ISO}.sha256" 2>/dev/null || true
fi

trap - EXIT
xeno_chroot_umount "$ROOTFS"

# Auto-increment version by +0.5 for the next build
NEXT_VERSION=$(python3 -c "print(round($BUILD_VERSION + 0.5, 1))")
echo "$NEXT_VERSION" > "$VERSION_FILE"

echo "=== AUTOMATED PIPELINE COMPLETE ==="
echo "ISO: $TARGET_ISO"
echo "SHA256: $(cat "${LOCAL_ISO_PATH}.sha256" | awk '{print $1}')"
echo "Boot kernel: $KVER"
echo "Next build version queued: v${NEXT_VERSION}"
if [ "$KERNEL_VALID" != "1" ]; then
    echo "NOTE: Custom Xeno kernel was INVALID — ISO used fallback generic kernel."
    echo "      Rebuild kernel CI to restore XanMod + injection + full WLAN."
fi
