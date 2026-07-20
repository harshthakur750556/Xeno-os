```
 ░█──░█ ░█▀▀▀ ░█▄─░█ ░█▀▀█ ── ░█▀▀█ ░█▀▀▀ 
 ─░█░█─ ░█▀▀▀ ░█░█░█ ░█──█ ── ░█──█ ░▀▀▀█ 
 ░█──░█ ░█▄▄▄ ░█──▀█ ░█▄▄█ ── ░█▄▄█ ░█▄▄█ 
```

# AGENTS.md — Xeno OS Engineering Guidelines

## Project Overview
Custom Linux distribution (Ubuntu 24.04 / Noble) featuring a custom XanMod kernel (v6.12+ BORE scheduler + Kali mac80211 patches), Hyprland Wayland compositor, TypeScript/Astal v2 desktop shell, and PySide6 scientific GUI panels.

---

## Critical Path Rules
1. **SquashFS Location**: SquashFS MUST live at `iso/build/casper/filesystem.squashfs`, NEVER `iso/build/live/`. Wrong path causes kernel panic.
2. **GRUB Boot Parameters**: Use `boot=casper` (NOT `boot=live`). Kernel at `/casper/vmlinuz`, initrd at `/casper/initrd`.
3. **ISO Level 3 Required**: SquashFS exceeds 4GB. `xorriso` must use `-iso-level 3`. GRUB volume ID must be ≤8 uppercase alphanumeric chars (`XENOOS`).
4. **Dynamic Workspace Paths**: Never hardcode `/home/xeno/Xeno-os`. Always use `WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"` in shell scripts.
5. **VTK Imports**: Defer VTK imports inside PySide6 panels to method scope (`_lazy_init_vtk()`) to avoid X11 `BadWindow` crashes on startup when hidden inside a `QStackedWidget`.
6. **VM Software Rendering**: Always initialize Qt environment via `from desktop.env import init_qt_environment; init_qt_environment()` in PySide6 entry points to set `LIBGL_ALWAYS_SOFTWARE=1` and `QTWEBENGINE_DISABLE_GPU=1` when running in VMs or standalone terminals.

---

## Primary Management Scripts

| Command | Purpose |
|---|---|
| `sudo bash scripts/auto-build.sh` | Full ISO packaging pipeline (fetches kernel debs, updates rootfs, builds ZSTD squashfs, generates GRUB ISO Level 3) |
| `bash scripts/stage-kernel-debs.sh` | Validates and stages locally compiled kernel packages from `kernel/output/` into `kernel/cache/` |
| `sudo bash scripts/fix-boot-display.sh` | Resolves GDM conflicts, sets up systemd autostart, and installs software renderer launcher `/usr/bin/xeno-start-hyprland` |
| `sudo bash scripts/enter-rootfs.sh` | Interactive chroot into rootfs |

---

## E2E Test Suite Execution

Simulation Mode (headless, no display server required):
```bash
python3 tests/run_tests.py
```

Live Mode (interacts with active Wayland/X11 session):
```bash
python3 tests/run_tests.py --live
```

Total Test Count: 72 tests across 4 tiers (Feature Coverage, Boundaries & Stress, Integration Sync, Real-World Flows & Theme Audits).

---

## Dual Architecture Stack

### 1. Python / PySide6 Panels (`desktop/panels/`)
* **Base Panel**: Subclass `desktop.panels.base_panel.BasePanel`. Do NOT modify `base_panel.py`.
* **Theme Tokens**: All styling MUST reference `desktop.theme.theme` (`theme.bg`, `theme.accent`, `theme.surface`, etc.).
* **Threading**: Heavy math/data calculations run in `BaseWorker` (`QObject`) offloaded via `QThread`. Never touch UI elements from worker threads.
* **Matplotlib Backend**: Set `matplotlib.use('Agg')` before importing any other matplotlib submodules.
* **Entry Point**: Every panel file MUST include a standalone `if __name__ == "__main__":` test block calling `init_qt_environment()`.

### 2. TypeScript / Astal v2 Shell (`desktop/shell/`)
* **Runtime**: Bun.
* **Imports**: Use `astal/gtk3` and `astal` (Astal v2). Legacy AGS v1 imports are forbidden.
* **Theme Mirror**: All visual properties reference `desktop/shell/theme.ts`.
* **VM Sizing Rules**: No blur, no drop shadows, static pixel values only.

---

## Project Directory Map

```
Xeno-os/
├── desktop/          # PySide6 panels + TypeScript Astal shell + theme tokens + env.py
├── drivers/          # Hardware driver packages & setup
├── iso/              # ISO build directory (build/casper/, output/)
├── kernel/           # XanMod kernel patches, build scripts, GitHub CI output
├── rootfs/           # Ubuntu 24.04 debootstrap root filesystem
├── scripts/          # Packaging, chroot, and boot-fix shell scripts
├── tests/            # E2E test suite (run_tests.py, simulator.py, mock bin/)
├── .cursorrules      # Core engineering guidelines & revision logs
├── AGENTS.md         # Developer & AI agent instructions
└── README.md         # Cyber-Nord design specification & user manual
```
