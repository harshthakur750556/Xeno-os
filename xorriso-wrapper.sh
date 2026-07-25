#!/bin/bash
# Intercept the arguments sent by grub-mkrescue
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "ERROR: xorriso-wrapper.sh received no arguments"
    exit 1
fi

args=()
for arg in "$@"; do
    args+=("$arg")
    # Inject the Level 3 override exactly where it belongs
    if [ "$arg" = "mkisofs" ]; then
        args+=("-iso-level" "3")
    fi
done
# Log exact arguments passed to xorriso for empirical inspection
printf '%s\n' "${args[@]}" > /tmp/xorriso-args.log 2>/dev/null || true

# Pass the modified arguments to the real xorriso
exec /usr/bin/xorriso "${args[@]}"

