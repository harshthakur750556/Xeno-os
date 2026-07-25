#!/bin/bash
# Validate that a linux-image deb is fit for Xeno OS (WLAN + modules present).
set -euo pipefail

DEB_DIR="${1:-}"
if [ -z "$DEB_DIR" ] || [ ! -d "$DEB_DIR" ]; then
    echo "Usage: $0 <directory-with-linux-image-*.deb>"
    exit 1
fi

IMAGE_DEBS=("$DEB_DIR"/linux-image-*.deb)
if [ ! -f "${IMAGE_DEBS[0]:-}" ]; then
    echo "ERROR: no linux-image-*.deb found in $DEB_DIR"
    exit 1
fi

valid_count=0

for IMAGE_DEB in "${IMAGE_DEBS[@]}"; do
    [ -f "$IMAGE_DEB" ] || continue

    TMP=$(mktemp -d)
    echo "Validating: $IMAGE_DEB"
    dpkg-deb -x "$IMAGE_DEB" "$TMP"

    CFG=$(ls "$TMP"/boot/config-* 2>/dev/null | head -1 || true)
    fail=0

    if [ -z "$CFG" ]; then
        echo "ERROR: config-* missing inside image package: $IMAGE_DEB"
        fail=1
    else
        check_cfg() {
            local pat="$1"
            if ! grep -qE "$pat" "$CFG"; then
                echo "ERROR: config check failed: $pat"
                fail=1
            else
                echo "  ✓ $pat"
            fi
        }

        check_cfg '^CONFIG_WLAN=y'
        check_cfg '^CONFIG_CFG80211=[ym]'
        check_cfg '^CONFIG_MAC80211=[ym]'
        check_cfg '^CONFIG_(ATH9K|IWLWIFI|RTW88|MT76_CORE|BRCMFMAC)=[ym]'
        check_cfg '^CONFIG_PREEMPT(_BUILD|_DYNAMIC|_LAZY)?=[ym]'
        check_cfg '^CONFIG_HZ(_1000=y|=1000)'
        if grep -qE '^CONFIG_NTSYNC=[ym]' "$CFG"; then
            echo "  ✓ CONFIG_NTSYNC enabled"
        else
            echo "  · info: CONFIG_NTSYNC not set in kernel config"
        fi

        # Modules must not be stuck as dpkg-new inside the package itself
        BAD=$(find "$TMP/lib/modules" -name '*.dpkg-new' 2>/dev/null | wc -l)
        if [ "$BAD" -gt 0 ]; then
            echo "ERROR: package contains $BAD *.dpkg-new module files"
            fail=1
        fi

        MOD_COUNT=$(find "$TMP/lib/modules" \( -name '*.ko' -o -name '*.ko.*' \) ! -name '*.dpkg-new' 2>/dev/null | wc -l)
        if [ "$MOD_COUNT" -lt 500 ]; then
            echo "ERROR: suspiciously few modules ($MOD_COUNT) — expected 500+"
            fail=1
        else
            echo "  ✓ module count: $MOD_COUNT"
        fi

        # At least one wireless driver module OR built-in evidence
        WLAN_MOD=$(find "$TMP/lib/modules" \( -path '*/net/wireless/*' -o -path '*/net/mac80211/*' -o -name 'ath9k*' -o -name 'iwlwifi*' -o -name 'rtw88*' -o -name 'mt76*' \) 2>/dev/null | head -5 || true)
        if [ -z "$WLAN_MOD" ]; then
            if grep -qE '^CONFIG_(ATH9K|IWLWIFI|RTW88)=y$' "$CFG"; then
                echo "  ✓ wireless drivers built-in"
            else
                echo "ERROR: no wireless driver modules found under lib/modules"
                fail=1
            fi
        else
            echo "  ✓ wireless modules present"
        fi
    fi

    rm -rf "$TMP"

    if [ "$fail" -ne 0 ]; then
        echo "WARNING: Kernel package $IMAGE_DEB failed validation. Purging invalid package from cache..."
        pkg_base=$(basename "$IMAGE_DEB" | sed -E 's/^linux-image-//; s/\.deb$//; s/_.*$//')
        rm -f "$DEB_DIR"/*"$pkg_base"* 2>/dev/null || true
        rm -f "$IMAGE_DEB" 2>/dev/null || true
    else
        valid_count=$((valid_count + 1))
    fi
done

if [ "$valid_count" -eq 0 ]; then
    echo "KERNEL PACKAGE VALIDATION FAILED: No valid kernel packages remain in $DEB_DIR"
    exit 1
fi

echo "KERNEL PACKAGE VALIDATION PASSED ($valid_count valid package(s))"
