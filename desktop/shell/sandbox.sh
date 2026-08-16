#!/bin/bash
WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
export WS_DIR

# Setup environment variables for VM software rendering
export WLR_RENDERER_ALLOW_SOFTWARE=1
export WLR_NO_HARDWARE_CURSORS=1
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export __GLX_VENDOR_LIBRARY_NAME=mesa

# Start the shell with bun run app.ts
cd "$WS_DIR/desktop/shell"
exec bun run app.ts

