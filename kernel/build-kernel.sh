#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Xeno OS — Production Kernel Build (XanMod + WLAN + injection)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

KERNEL_SUFFIX="-xeno1"
XANMOD_TAG="${XANMOD_TAG:-6.12.10-xanmod1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# GitHub Actions sets GITHUB_WORKSPACE; fall back to repo root locally
WS_DIR="${GITHUB_WORKSPACE:-$WS_DIR}"
PATCH_DIR="${WS_DIR}/kernel/patches"
FRAGMENT="${WS_DIR}/kernel/configs/xeno.config.fragment"
OUT_DIR="${WS_DIR}/kernel/output"
BUILD_ROOT="${XENO_KERNEL_BUILD_DIR:-/tmp/kernel-build}"

echo "=== Xeno OS Universal Production Kernel Build ==="
echo "Workspace : $WS_DIR"
echo "Patches   : $PATCH_DIR"
echo "Fragment  : $FRAGMENT"
echo "Output    : $OUT_DIR"

if [ ! -d "$PATCH_DIR" ]; then
    echo "ERROR: patch directory missing: $PATCH_DIR"
    exit 1
fi
if [ ! -f "$FRAGMENT" ]; then
    echo "ERROR: config fragment missing: $FRAGMENT"
    exit 1
fi

PATCH_COUNT=$(find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' | wc -l)
if [ "$PATCH_COUNT" -lt 1 ]; then
    echo "ERROR: no patches found in $PATCH_DIR — refusing to build an unpatched kernel"
    exit 1
fi

mkdir -p "$BUILD_ROOT" "$OUT_DIR"
cd "$BUILD_ROOT"
rm -rf linux-xanmod

echo "--- Downloading XanMod source (pinned tag: ${XANMOD_TAG}) ---"
MAX_RETRIES=3
RETRY=0
CLONED=0
while [ "$RETRY" -lt "$MAX_RETRIES" ]; do
    RETRY=$((RETRY+1))
    echo "Attempt $RETRY of $MAX_RETRIES: cloning XanMod source..."
    if git clone --depth 1 --branch "$XANMOD_TAG" https://gitlab.com/xanmod/linux.git linux-xanmod; then
        CLONED=1
        break
    else
        echo "Clone attempt $RETRY failed; retrying in 5 seconds..."
        sleep 5
    fi
done

if [ "$CLONED" -ne 1 ]; then
    echo "Single-branch shallow clone failed after retries; attempting full clone..."
    git clone https://gitlab.com/xanmod/linux.git linux-xanmod
    (cd linux-xanmod && git checkout "$XANMOD_TAG")
fi
cd linux-xanmod

apply_patch() {
    local patch_file="$1"
    local name
    name="$(basename "$patch_file")"
    echo "Applying: $name"
    local dry_log
    dry_log="$(mktemp /tmp/xeno-patch-dry.XXXXXX.log)"

    # 1. Try git apply first if inside git tree
    if git apply --check "$patch_file" >"$dry_log" 2>&1; then
        git apply "$patch_file"
        echo "  ✓ applied $name (via git apply)"
        rm -f "$dry_log"
        return 0
    fi

    # 2. Try patch with forward & ignore-whitespace flags
    if patch -p1 --forward --ignore-whitespace --dry-run < "$patch_file" >"$dry_log" 2>&1; then
        patch -p1 --forward --ignore-whitespace < "$patch_file"
        echo "  ✓ applied $name (via patch)"
        rm -f "$dry_log"
        return 0
    fi

    # 3. Check if patch is already applied
    if grep -qiE 'previously applied|Reversed \(or previously applied\)|Ignoring previously applied|already applied' "$dry_log"; then
        echo "  ✓ already applied: $name"
        rm -f "$dry_log"
        return 0
    fi

    echo "ERROR: required patch failed: $name"
    cat "$dry_log"
    rm -f "$dry_log"
    exit 1
}

echo "--- Applying wireless injection patches ---"
shopt -s nullglob
for patch_file in "$PATCH_DIR"/*.patch; do
    apply_patch "$patch_file"
done
shopt -u nullglob

echo "--- Configuring kernel ---"
# Prefer XanMod's own recommended config when present
BASE_CFG=""
for candidate in \
    CONFIGS/xanmod/gcc/config_x86-64-v3 \
    CONFIGS/xanmod/gcc/config_x86-64 \
    CONFIGS/xanmod/gcc/config \
    arch/x86/configs/xanmod_defconfig
do
    if [ -f "$candidate" ]; then
        BASE_CFG="$candidate"
        break
    fi
done

if [ -n "$BASE_CFG" ]; then
    echo "Using XanMod baseline: $BASE_CFG"
    cp "$BASE_CFG" .config
else
    echo "XanMod baseline not found — falling back to host Ubuntu config + olddefconfig"
    if [ -f "/boot/config-$(uname -r)" ]; then
        cp "/boot/config-$(uname -r)" .config
    else
        make defconfig
    fi
fi

# Clear Ubuntu-style locked key paths that break offline CI builds
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS "" || true
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS "" || true
./scripts/config --set-str CONFIG_MODULE_SIG_KEY "" || true
./scripts/config --disable CONFIG_MODULE_SIG_ALL || true
make olddefconfig

echo "--- Merging Xeno config fragment (WLAN + NTSYNC + latency) ---"
if [ -x ./scripts/kconfig/merge_config.sh ]; then
    ./scripts/kconfig/merge_config.sh -m .config "$FRAGMENT"
else
    # Fallback: apply key options via scripts/config
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        if [[ "$line" =~ ^#\ CONFIG_([A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
            ./scripts/config --disable "${BASH_REMATCH[1]}" || true
        elif [[ "$line" =~ ^CONFIG_([A-Za-z0-9_]+)=y$ ]]; then
            ./scripts/config --enable "${BASH_REMATCH[1]}" || true
        elif [[ "$line" =~ ^CONFIG_([A-Za-z0-9_]+)=m$ ]]; then
            ./scripts/config --module "${BASH_REMATCH[1]}" || true
        elif [[ "$line" =~ ^CONFIG_([A-Za-z0-9_]+)=([0-9]+)$ ]]; then
            ./scripts/config --set-val "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" || true
        elif [[ "$line" =~ ^CONFIG_([A-Za-z0-9_]+)=\"(.*)\"$ ]]; then
            ./scripts/config --set-str "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" || true
        fi
    done < "$FRAGMENT"
fi

# Hard enforce show-stopper options after merge
./scripts/config --enable CONFIG_WLAN
./scripts/config --enable CONFIG_WIRELESS
./scripts/config --enable CONFIG_CFG80211
./scripts/config --enable CONFIG_MAC80211
./scripts/config --enable CONFIG_RFKILL
./scripts/config --enable CONFIG_PREEMPT
./scripts/config --enable CONFIG_HZ_1000
./scripts/config --set-val CONFIG_HZ 1000
./scripts/config --enable CONFIG_NTSYNC || ./scripts/config --module CONFIG_NTSYNC || true
./scripts/config --enable CONFIG_MODULES
./scripts/config --disable CONFIG_MODULE_SIG_FORCE || true
./scripts/config --disable CONFIG_MODULE_SIG_ALL || true
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""
./scripts/config --set-str CONFIG_MODULE_SIG_KEY ""
./scripts/config --disable CONFIG_DEBUG_INFO || true
./scripts/config --disable CONFIG_DEBUG_INFO_BTF || true
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF5 || true
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT || true
./scripts/config --disable CONFIG_PAHOLE_HAS_SPLIT_BTF || true
./scripts/config --enable CONFIG_DEBUG_INFO_NONE || true

# Popular drivers as modules (ignore if symbol renamed on this tree)
for opt in \
    ATH9K ATH9K_HTC ATH10K ATH10K_PCI IWLWIFI IWLMVM \
    BRCMFMAC MT76_CORE MT76x2E MT7921E RTW88 RTW88_CORE RTW89 \
    RTL8187 RTL8XXXU ZD1211RW MAC80211_HWSIM RT2800USB
do
    ./scripts/config --module "CONFIG_${opt}" 2>/dev/null || true
done

make olddefconfig

echo "--- Validating critical config options ---"
fail=0
for req in CONFIG_WLAN=y CONFIG_CFG80211=y CONFIG_MAC80211=y CONFIG_MODULES=y; do
    if ! grep -q "^${req}$" .config; then
        # modules form also acceptable for cfg/mac
        key="${req%%=*}"
        if ! grep -qE "^${key}=[ym]$" .config; then
            echo "ERROR: required option missing: $req"
            fail=1
        fi
    fi
done
# At least one real Wi-Fi driver family must be present
if ! grep -qE '^CONFIG_(ATH9K|IWLWIFI|RTW88|MT76_CORE|BRCMFMAC)=[ym]$' .config; then
    echo "ERROR: no major WLAN drivers enabled (ATH9K/IWLWIFI/RTW88/MT76/BRCMFMAC)"
    fail=1
fi
if [ "$fail" -ne 0 ]; then
    echo "---- relevant .config lines ----"
    grep -E 'CONFIG_(WLAN|CFG80211|MAC80211|ATH9K|IWLWIFI|RTW88|MT76|BRCMFMAC|NTSYNC)=' .config || true
    exit 1
fi
echo "Config validation passed."

echo "--- Compiling kernel packages ---"
make -j"$(nproc)" bindeb-pkg \
    LOCALVERSION="${KERNEL_SUFFIX}" \
    KDEB_PKGVERSION="1.0" \
    KBUILD_BUILD_USER="xeno" \
    KBUILD_BUILD_HOST="xeno-os"

echo "--- Collecting packages ---"
cd "$BUILD_ROOT"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.deb
mv -v ./*.deb "$OUT_DIR/" 2>/dev/null || mv -v ../*.deb "$OUT_DIR/" 2>/dev/null || {
    # bindeb-pkg writes one directory up from the source tree
    find "$BUILD_ROOT" -maxdepth 2 -name 'linux-*.deb' -exec mv -v {} "$OUT_DIR/" \;
}

echo "--- Post-build package validation ---"
bash "${WS_DIR}/kernel/validate-kernel-deb.sh" "$OUT_DIR"

echo "--- Built packages ---"
ls -lh "$OUT_DIR/"
echo "=== Kernel Build Complete ==="
