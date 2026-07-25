#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Xeno OS — Stage locally built kernel debs to cache
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${WS_DIR}/kernel/output"
CACHE_DIR="${WS_DIR}/kernel/cache"
META_FILE="${CACHE_DIR}/latest_release.json"

echo "=== Xeno OS Kernel Staging Helper ==="
if ! ls "$OUT_DIR"/linux-image-*.deb &>/dev/null; then
    echo "ERROR: no linux-image-*.deb found in $OUT_DIR"
    echo "Run 'bash kernel/build-kernel.sh' first."
    exit 1
fi

echo "Validating packages in $OUT_DIR..."
bash "$WS_DIR/kernel/validate-kernel-deb.sh" "$OUT_DIR"

mkdir -p "$CACHE_DIR"
echo "Staging kernel packages from $OUT_DIR to $CACHE_DIR..."
rm -f "$CACHE_DIR"/*.deb
cp "$OUT_DIR"/*.deb "$CACHE_DIR/"

cat > "$META_FILE" << EOF
{
  "tagName": "local-build-$(date +%Y%m%d%H%M%S)",
  "publishedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "✓ Kernel packages staged in $CACHE_DIR"
ls -lh "$CACHE_DIR"/*.deb
