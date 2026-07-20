#!/bin/bash
# Validate that a linux-image deb is fit for Xeno OS (WLAN + modules present).
set -euo pipefail

DEB_DIR="${1:-}"
if [ -z "$DEB_DIR" ] || [ ! -d "$DEB_DIR" ]; then
    echo "Usage: $0 <directory-with-linux-image-*.deb>"
    exit 1
fi

IMAGE_DEB=$(ls "$DEB_DIR"/linux-image-*.deb 2>/dev/null | head -1 || true)
if [ -z "$IMAGE_DEB" ]; then
    echo "ERROR: no linux-image-*.deb found in $DEB_DIR"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Validating: $IMAGE_DEB"
dpkg-deb -x "$IMAGE_DEB" "$TMP"

CFG=$(ls "$TMP"/boot/config-* 2>/dev/null | head -1 || true)
if [ -z "$CFG" ]; then
    echo "ERROR: config-* missing inside image package"
    exit 1
fi

fail=0
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

# Modules must not be stuck as dpkg-new inside the package itself
BAD=$(find "$TMP/lib/modules" -name '*.dpkg-new' 2>/dev/null | wc -l)
if [ "$BAD" -gt 0 ]; then
    echo "ERROR: package contains $BAD *.dpkg-new module files"
    fail=1
fi

MOD_COUNT=$(find "$TMP/lib/modules" \( -name '*.ko' -o -name '*.ko.*' \) ! -name '*.dpkg-new' 2>/dev/null | wc -l)
# mac80211 may be built-in; still expect a healthy module set
if [ "$MOD_COUNT" -lt 500 ]; then
    echo "ERROR: suspiciously few modules ($MOD_COUNT) — expected 500+"
    fail=1
else
    echo "  ✓ module count: $MOD_COUNT"
fi

# At least one wireless driver module OR built-in evidence
WLAN_MOD=$(find "$TMP/lib/modules" \( -path '*/net/wireless/*' -o -path '*/net/mac80211/*' -o -name 'ath9k*' -o -name 'iwlwifi*' -o -name 'rtw88*' -o -name 'mt76*' \) 2>/dev/null | head -5 || true)
if [ -z "$WLAN_MOD" ]; then
    # If drivers are built-in, CONFIG lines above still pass; warn only
    if grep -qE '^CONFIG_(ATH9K|IWLWIFI|RTW88)=y$' "$CFG"; then
        echo "  ✓ wireless drivers built-in"
    else
        echo "ERROR: no wireless driver modules found under lib/modules"
        fail=1
    fi
else
    echo "  ✓ wireless modules present"
fi

if [ "$fail" -ne 0 ]; then
    echo "KERNEL PACKAGE VALIDATION FAILED"
    exit 1
fi

echo "KERNEL PACKAGE VALIDATION PASSED"
