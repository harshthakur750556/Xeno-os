#!/bin/bash
set -e

KERNEL_SUFFIX="-xeno1"

echo "=== Xeno OS Kernel Build ==="
echo "Base: XanMod (Latest Default Branch)"
echo "Patches: Kali mac80211 wireless injection"

mkdir -p /tmp/kernel-build
cd /tmp/kernel-build

echo "--- Downloading XanMod source ---"
# Pulling directly from XanMod's new GitLab repository!
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

echo "--- Configuring kernel ---"
make x86_64_defconfig
./scripts/config --enable CONFIG_PREEMPT
./scripts/config --enable CONFIG_HZ_1000
./scripts/config --set-val CONFIG_HZ 1000
./scripts/config --enable CONFIG_EXPERT
./scripts/config --enable CONFIG_FUTEX
./scripts/config --enable CONFIG_FUTEX_PI
./scripts/config --enable CONFIG_NTSYNC
./scripts/config --enable CONFIG_CFQ_GROUP_IOSCHED
./scripts/config --enable CONFIG_BFQ_GROUP_IOSCHED
./scripts/config --enable CONFIG_NET
./scripts/config --enable CONFIG_WIRELESS
./scripts/config --enable CONFIG_CFG80211
./scripts/config --enable CONFIG_MAC80211
./scripts/config --enable CONFIG_MAC80211_MONITOR_BY_DEFAULT
./scripts/config --enable CONFIG_RFKILL
./scripts/config --enable CONFIG_INTEL_IDLE
./scripts/config --enable CONFIG_ACPI_PROCESSOR
./scripts/config --enable CONFIG_X86_INTEL_LPSS
./scripts/config --enable CONFIG_I915
./scripts/config --enable CONFIG_DRM_I915
./scripts/config --enable CONFIG_SOUND
./scripts/config --enable CONFIG_SND
./scripts/config --enable CONFIG_SND_HDA_INTEL
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --disable CONFIG_DEBUG_INFO
make olddefconfig

echo "--- Compiling kernel ---"
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