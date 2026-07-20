#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Xeno OS — Local LLM Runtime & Model Storage
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${XENO_ROOTFS:-$WS_DIR/rootfs}"
# shellcheck source=/dev/null
source "$WS_DIR/scripts/lib-chroot.sh"

xeno_require_root
if [ ! -d "$ROOTFS/usr/bin" ]; then
    echo "ERROR: rootfs not found at $ROOTFS"
    exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  Xeno OS — AI Engine Installer"
echo "  Target: $ROOTFS"
echo "═══════════════════════════════════════════════════"

xeno_chroot_mount "$ROOTFS"
cleanup() { xeno_chroot_umount "$ROOTFS"; }
trap cleanup EXIT

chroot "$ROOTFS" /bin/bash << 'CHROOT_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "Setting up AI Model Storage (/var/cache/xeno-ai)..."
mkdir -p /var/cache/xeno-ai/models
chmod 777 /var/cache/xeno-ai/models

echo "Installing LLM runtime dependencies..."
apt-get update
apt-get install -y --no-install-recommends curl python3 python3-pip bubblewrap

echo "Writing xeno-ai-engine.service..."
cat > /usr/bin/xeno-ai-engine << 'EOF'
#!/bin/bash
# Wrapper for Ollama / llama.cpp
export OLLAMA_MODELS="/var/cache/xeno-ai/models"
export OLLAMA_HOST="127.0.0.1:11434"
if command -v ollama >/dev/null; then
    exec ollama serve
else
    echo "AI Engine (Ollama) not installed. Waiting..."
    sleep 3600
fi
EOF
chmod +x /usr/bin/xeno-ai-engine

echo "Writing xeno-agent-sandbox..."
cat > /usr/bin/xeno-agent-sandbox << 'EOF'
#!/bin/bash
# Sandbox wrapper for AI Tool Calls
# Requires bwrap (bubblewrap)
if ! command -v bwrap >/dev/null; then
    echo "bwrap not installed, executing directly..."
    exec "$@"
fi
exec bwrap --ro-bind / / --dev /dev --proc /proc \
           --bind /tmp /tmp \
           --unshare-all --share-net \
           --new-session --die-with-parent \
           --uid 1000 --gid 1000 \
           "$@"
EOF
chmod +x /usr/bin/xeno-agent-sandbox

cat > /etc/systemd/system/xeno-ai-engine.service << 'EOF'
[Unit]
Description=Xeno OS Local AI Engine (Ollama/llama.cpp)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/xeno-ai-engine
Restart=always
User=xeno

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/xeno-ai-engine.service /etc/systemd/system/multi-user.target.wants/xeno-ai-engine.service || true

# Optional: Install ollama binary if network allows
curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || true

apt-get clean
echo "✓ AI Engine ready."
CHROOT_EOF

echo "✓ AI tools ready in rootfs"
