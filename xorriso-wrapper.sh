#!/bin/bash
# Intercept the arguments sent by grub-mkrescue
args=()
for arg in "$@"; do
    args+=("$arg")
    # Inject the Level 3 override exactly where it belongs
    if [ "$arg" = "mkisofs" ]; then
        args+=("-iso-level" "3")
    fi
done
# Pass the modified arguments to the real xorriso
exec /usr/bin/xorriso "${args[@]}"
