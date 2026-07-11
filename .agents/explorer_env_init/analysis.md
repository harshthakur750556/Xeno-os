# Environment Initialization Exploration Report

## 1. Bun & Astal/AGS Installation Status

* **Bun Version**: `1.3.14` (located at `/home/xeno/.bun/bin/bun`).
* **Astal CLI/AGS Status**: Not installed.
  * Running `which astal` and `which ags` returned `command not found` (exit status 1).
  * Global npm packages list (`npm list -g --depth=0`) contains only `corepack@0.35.0`, `npm@11.16.0`, and `typescript@6.0.3`.
  * Global Bun package search (`bun pm ls -g`) yielded no global installation folder (`No package.json was found for directory "/home/xeno/.bun/install/global"`).
  * System package search (`apt-cache search astal`) returned no packages related to Astal or Aylur's Gtk Shell.

## 2. Directory Structure & Project Paths

* **`teamwork_projects` check**: `/home/xeno/teamwork_projects` does not exist.
  * Command `ls -la /home/xeno/teamwork_projects` failed with `ls: cannot access '/home/xeno/teamwork_projects': No such file or directory`.
* **`neonic_anime_gui` search**: No directory named `neonic_anime_gui` exists on the filesystem.
  * Checked using: `find /home/xeno -type d -name "neonic_anime_gui" -maxdepth 4` which returned nothing.
* **Recommendation**: Create the project directory at `/home/xeno/teamwork_projects/neonic_anime_gui`.

## 3. Desktop Shell & Existing Configs

* **Path**: `/home/xeno/Xeno-os/desktop/shell/`
* **Contents**: Only `theme.ts` exists inside this directory.
* **`theme.ts` contents**:
  ```typescript
  // XENO OS THEME — mirrors theme.py token names for the Astal/TypeScript side.
  // Keep every key here in sync with desktop/theme.py.

  export const theme = {
    bg: "#0c0d12",
    surface: "#161821",
    surface2: "#222533",
    border: "#2f3448",
    borderGlow: "#bc13fe40",
    accent: "#88c0d0",
    accent2: "#bc13fe",
    accentHover: "#00ffff",
    text: "#eceff4",
    textDim: "#a0a8b6",
    textMuted: "#5e657a",
    success: "#a3be8c",
    warning: "#ebcb8b",
    error: "#bf616a",
    overlay: "#000000b0",

    fontPrimary: "Inter",
    fontMono: "JetBrains Mono",
    sizeXs: 10,
    sizeSm: 12,
    sizeBase: 14,
    sizeMd: 16,
    sizeLg: 20,
    sizeXl: 24,
    size2xl: 32,
    size3xl: 48,

    radiusSm: 4,
    radiusMd: 8,
    radiusLg: 12,
    radiusFull: 9999,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 16,
    spaceXl: 24,
    panelPadding: 16,
    sidebarWidth: 280,
    topbarHeight: 48,
    iconSm: 16,
    iconMd: 24,
    iconLg: 32,
    touchTargetMin: 36,
  };
  ```
* **Context**: The existing desktop environment is implemented as a PySide6 Python application (located in `/home/xeno/Xeno-os/desktop`), showcasing a decryption/scientific interface shell. `theme.ts` maps Python-defined theme configurations to TypeScript tokens for compatibility with Astal.

## 4. Wayland/X11 Container Runtimes

* **Runtimes Check**: All checked standalone/nested container runtimes are **not installed** in the system PATH:
  * `weston`: not found
  * `cage`: not found
  * `Xephyr`: not found
  * `Xvfb`: not found
  * `xterm`: not found
  * `xvfb-run`: not found
* **Compositor and Display Environment**:
  * Environment variables indicate active displays: `WAYLAND_DISPLAY=wayland-0` and `DISPLAY=:0`.
  * `snap` is available, but no snap packages are installed.
  * No Flatpak is installed.
  * No standard container runtime wrapper or nested X/Wayland compositor is currently available.
