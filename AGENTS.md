```
 ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ 
 ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█──█ ░▀▀▀█ 
 ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█▄▄█ ░█▄▄█ 
```

# AGENTS.md — Xeno OS AI Developer & Engineering Guidelines

## Project Overview
Custom Linux distribution (Ubuntu 24.04 / Noble) featuring a custom XanMod kernel (v6.12+ BORE scheduler + Kali mac80211 patches), Hyprland Wayland compositor, 100% native TypeScript/Astal v2 desktop shell on Bun, universal application execution (.apk, .exe/.msi, .AppImage, .deb, .iso), and in-memory ZRAM compression.

---

## Critical Path Rules
1. **SquashFS Location**: SquashFS MUST live at `iso/build/casper/filesystem.squashfs`, NEVER `iso/build/live/`. Wrong path causes kernel panic.
2. **GRUB Boot Parameters**: Use `boot=casper` (NOT `boot=live`). Kernel at `/casper/vmlinuz`, initrd at `/casper/initrd`.
3. **ISO Level 3 Required**: SquashFS exceeds 4GB. `xorriso` must use `-iso-level 3`. GRUB volume ID must be ≤8 uppercase alphanumeric chars (`XENOOS`).
4. **Dynamic Workspace Paths**: Never hardcode `/home/xeno/Xeno-os`. Always use `WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"` in shell scripts.
5. **VM Software Rendering**: When running in virtual machines (VirtualBox, VMware, QEMU, Hyper-V), `/usr/bin/xeno-start-hyprland` enforces `MESA_LOADER_DRIVER_OVERRIDE=kms_swrast`, `LIBGL_ALWAYS_SOFTWARE=1`, and `GALLIUM_DRIVER=llvmpipe` to map software rendering onto DRM dumb buffers, preventing DRI2 screen creation crashes.
6. **Astal Shell Lifecycle**: The desktop shell is launched via `/usr/bin/xeno-desktop-shell` with dynamic runtime discovery and global error boundary wrappers (`uncaughtException`, `unhandledRejection`).

---

## System Credentials & Environment
* **Root / Sudo Password**: `Harsh@2004Thakur` (Default root/sudo credential for privileged commands, chroot execution, and ISO build pipelines).

---

## Primary Management & Diagnostic Scripts

| Command | Purpose |
|---|---|
| `bash scripts/master-doctor.sh` | 8-Tier comprehensive system diagnostic, test suite runner, and integrity verifier |
| `sudo bash scripts/master-doctor.sh --fix` | Master Doctor in self-healing mode (automatically repairs discovered issues) |
| `sudo bash scripts/auto-build.sh` | Full Smart Lean ISO packaging pipeline (ZSTD L19 1MB-block SquashFS + Level 3 GRUB ISO) |
| `bash run-qemu.sh --gui` | Run built ISO in QEMU with graphical Wayland display window |
| `bash run-qemu.sh --terminal` | Run built ISO in QEMU in headless serial console mode (ttyS0 autologin) |
| `bash kernel/validate-kernel-deb.sh kernel/cache` | Validates kernel packages for WLAN, preemption, and driver modules |
| `bash scripts/stage-kernel-debs.sh` | Validates and stages locally compiled kernel packages from `kernel/output/` into `kernel/cache/` |
| `sudo bash scripts/fix-kernel-rootfs.sh` | Repairs and installs validated custom XanMod kernel packages into rootfs |
| `sudo bash scripts/fix-boot-display.sh` | Resolves GDM conflicts, sets up systemd autostart, and installs software renderer launcher |
| `sudo bash scripts/install-astal-chroot.sh` | Installs Bun and Astal desktop shell dependencies inside rootfs chroot |
| `sudo bash scripts/setup-compat-stack.sh` | Configures Wine Staging, DXVK, VKD3D-Proton, and Windows compatibility layer |
| `sudo bash scripts/setup-security-tools.sh` | Configures Kali pinned repo (priority 100), wireless tools, and injection utilities |
| `sudo bash scripts/setup-ai.sh` | Configures Ollama local AI runtime and Bubblewrap agent sandbox |
| `sudo bash drivers/install-oot-wifi.sh` | Builds and installs Realtek rtl8812au out-of-tree injection DKMS module |
| `sudo bash scripts/enter-rootfs.sh` | Interactive chroot into rootfs with safe mount/trap handling |

---

## Automated Test Suite Execution

Simulation Mode (headless, no display server required):
```bash
python3 tests/run_tests.py
```

Adversarial IPC Boundary Suite:
```bash
python3 -m unittest tests/test_adversarial.py
```

Live Mode (interacts with active Wayland/X11 session):
```bash
python3 tests/run_tests.py --live
```

Total Test Count: **96 tests** (73 E2E Integration tests + 23 Adversarial boundary tests).

---

## Desktop Architecture Stack (TypeScript / Astal v2 on Bun)

* **Runtime**: Bun engine executing [`desktop/shell/app.ts`](file:///home/xeno/Xeno-os/desktop/shell/app.ts).
* **Bindings**: Uses `astal/gtk3` and `astal` (Astal v2). Legacy AGS v1 imports are forbidden.
* **Component Layout**:
  - `Bar.ts`: Real-time Cyber-Nord top status bar with CPU/RAM telemetry and dynamic workspace indicators.
  - `Launcher.ts`: Fast fuzzy application grid search matrix invoked via `Super+Space`.
  - `Notifications.ts`: High-throughput non-blocking notification toast dispatch daemon.
  - `state.ts`: Global reactive IPC client & telemetry store communicating via `/tmp/xeno-ipc.sock`.
* **Theme Tokens**: All styling references [`desktop/shell/theme.ts`](file:///home/xeno/Xeno-os/desktop/shell/theme.ts).
* **VM Optimization Rules**: No dynamic blur, no heavy drop shadows, static pixel values only for maximum responsiveness.

---

## Project Directory Map

```
Xeno-os/
├── desktop/          # TypeScript Astal shell, theme tokens, and assets
│   ├── env.py        # VM software graphics fallback initialization
│   ├── theme.py      # Python visual tokens (reference)
│   ├── assets/       # Desktop visual icons and SVG assets
│   ├── themes/       # Supplemental theme presets and palettes
│   └── shell/        # Astal v2 / Bun TypeScript shell (Bar, Launcher, Notifications, theme.ts)
├── drivers/          # Hardware & wireless driver scripts (README.md, install-oot-wifi.sh)
├── iso/              # ISO build directory (build/casper/, output/ALPHA, output/BETA, version.txt)
├── kernel/           # XanMod patches (0001, 0002, 0003), configs, cache/, build-kernel.sh, validate-kernel-deb.sh
├── rootfs/           # Ubuntu 24.04 LTS (Noble) debootstrap root filesystem
├── scripts/          # Packaging, doctor, chroot, compat, AI, and boot-fix shell scripts
├── tests/            # Automated test suites (96 tests across E2E & Adversarial, simulator.py)
├── .cursorrules      # Core engineering guidelines & revision logs
├── .editorconfig     # Global formatting & indentation rules
├── AGENTS.md         # Developer & AI agent instructions
├── CHANGELOG.md      # Chronological revision history & activity log
├── run-qemu.sh       # Fast QEMU test runner (--gui or --terminal)
├── xorriso-wrapper.sh# ISO Level 3 oversized image injection wrapper
└── README.md         # Cyber-Nord design specification & master technical manual
```
