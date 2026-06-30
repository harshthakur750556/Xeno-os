#!/bin/bash
set -e

KERNEL_SUFFIX="-xeno1"

echo "=== Xeno OS Universal Production Kernel Build ==="
echo "Base: XanMod (Latest Default Branch)"
echo "Patches: Kali mac80211 wireless injection"

mkdir -p /tmp/kernel-build
cd /tmp/kernel-build

echo "--- Downloading XanMod source ---"
git clone --depth=1 https://gitlab.com/xanmod/linux.git linux-xanmod
cd linux-xanmod

echo "--- Applying Kali wireless injection patches ---"
PATCH_DIR="${GITHUB_WORKSPACE}/kernel/patches"
for patch_file in "${PATCH_DIR}"/*.patch; do
    if [ -f "$patch_file" ]; then
        echo "Applying: $(basename $patch_file)"
        patch -p1 --forward < "$patch_file" || echo "Patch may already be applied or conflict, continuing"
    fi
done

echo "--- Configuring kernel using Ubuntu Production Baseline ---"
# Copy the GitHub runner's official production Ubuntu config as our baseline!
cp /boot/config-$(uname -r) .config
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""
# Update it to match the XanMod source structure
make olddefconfig

# Inject our custom performance and wireless overrides
./scripts/config --enable CONFIG_PREEMPT
./scripts/config --enable CONFIG_HZ_1000
./scripts/config --set-val CONFIG_HZ 1000
./scripts/config --enable CONFIG_NTSYNC
./scripts/config --enable CONFIG_MAC80211_MONITOR_BY_DEFAULT
./scripts/config --enable CONFIG_MAC80211
./scripts/config --enable CONFIG_CFG80211

# Disable heavy debug symbols to speed up compile time by 30%
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --disable CONFIG_DEBUG_INFO
make olddefconfig

echo "--- Compiling kernel (This will take a while) ---"
make -j$(nproc) bindeb-pkg \
    LOCALVERSION="${KERNEL_SUFFIX}" \
    KDEB_PKGVERSION="1.0" \
    KBUILD_BUILD_USER="xeno" \
    KBUILD_BUILD_HOST="xeno-os"

echo "--- Moving packages ---"
cd /tmp/kernel-build
mkdir -p "${GITHUB_WORKSPACE}/kernel/output"
mv *.deb "${GITHUB_WORKSPACE}/kernel/output/"

echo "--- Built packages ---"
ls -lh "${GITHUB_WORKSPACE}/kernel/output/"
echo "=== Kernel Build Complete ==="