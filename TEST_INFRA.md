# Xeno OS Neonic Anime GUI — E2E Test Infrastructure

This document outlines the test philosophy, feature inventory, test runner architecture, execution formats, and test scenarios designed to validate the Xeno OS desktop GUI environment.

---

## 1. Test Philosophy

The Xeno OS GUI shell E2E test suite adheres to an **opaque-box testing philosophy**:
* **Requirement-Driven**: All test cases are derived directly from the user specifications in `ORIGINAL_REQUEST.md`.
* **No Internal Dependency**: The tests do not rely on internal class names, private variables, or specific file structures of the shell implementation. They interact solely through exposed opaque interfaces.
* **Opaque Interfaces**: The tests communicate with Xeno OS via:
  1. Command-line utility invocations (CLI).
  2. Unix domain socket IPC payloads.
  3. Formatted outputs (stdout/stderr) and exit codes.
  4. Visual layout specifications (stylesheet and theme files).
* **Dual Execution Mode**: To handle parallel development, the test suite supports a **Simulation Mode** (which runs a mock IPC server and simulated CLI tools) and a **Live Mode** (which runs against the actual desktop shell processes).

---

## 2. Feature Inventory

The test suite validates four core features of the neonic anime GUI:

### F1: Desktop Status Bar (Astal v2)
* **Clock Updates**: High-fidelity clock displaying current date/time with a 1-second update interval constraint.
* **CPU Meter**: High-efficiency CPU utilization diagnostic parsing.
* **RAM Meter**: Core RAM utilization diagnostic parsing (used/total/percentage).
* **Workspaces**: Rendering and highlight of active workspaces list.
* **Launcher Controls**: Button actions to trigger the overlay app launcher.

### F2: Anime App Launcher
* **Grid Layout**: Application grid displaying IDs, names, launch commands, and graphic icons.
* **Highlights**: Visual selection state cursor highlights.
* **Custom Fonts**: Application of typography tokens (`font_primary`, `font_mono`, `size_base`, etc.).
* **Selection Action**: Selection click events triggering application subprocess launches.

### F3: Neon Notification Center
* **Toast Manager**: Spawning warning/message toast overlays.
* **Warning Logs**: Internal notification log logging warning events.
* **Animations**: Retention of CSS transition duration configurations.
* **Sound Hooks**: Execution triggers calling configured audio hook files.
* **Transitions**: Auto-dismiss timeout actions.

### F4: Sandbox Wrapper
* **Display Socket**: Enforcement of Wayland/X11 container display sockets.
* **Instance Lock**: Detection of double-spawn wrapper collisions.
* **Resource Limits**: Memory ceilings (minimum 128MB) and max thread core boundaries (maximum 4).
* **Panel Loading**: Dynamic injection of base/scientific widget panels.

---

## 3. Test Runner & Dual-Mode Execution

The suite is located under `tests/` and is managed by `tests/run_tests.py`.

### Execution Modes
1. **Simulation Mode** (Default):
   * Executed using: `python3 tests/run_tests.py` or `python3 -m unittest discover -s tests`
   * Spins up a background IPC Unix socket server (`tests/simulator.py`).
   * Prepends `tests/bin/` to `PATH` so that standard CLI calls target mock binaries translating options to IPC calls.
   * Simulates full system telemetry, state changes, errors, and resource bounds.
2. **Live Mode**:
   * Executed using: `python3 tests/run_tests.py --live` (sets `XENO_E2E_LIVE=1`).
   * Executes real desktop binaries (`xeno-status-bar`, `xeno-sandbox`, etc.).
   * Interacts with the real system IPC socket (defaults to `/tmp/xeno-ipc.sock`).

---

## 4. Test Suite Tier Structure

The test suite comprises **49 total tests** divided into four logical tiers:

### Tier 1: Feature Coverage (20 Tests)
Verifies nominal paths and core functionality for each of the four features:
* **F1**: Clock updates, CPU meter parsing, RAM meter parsing, workspaces rendering, launcher toggle.
* **F2**: App list grid, highlights index, custom typography, icon representation, selection launches.
* **F3**: Toast popups, warning logs, animation timeout, sound hooks, dismiss transition.
* **F4**: Display sockets, core threads, panel widget loading, start/stop cycles, performance limits.

### Tier 2: Boundary & Corner Cases (20 Tests)
Verifies error tolerance, validation rules, and stability under pressure:
* **F1**: Null CPU/RAM data, DST/leap-year clock transitions, CPU limits (>100%), large workspace lists (100+), rapid toggle spam.
* **F2**: Empty app grid, extreme font sizes (1000px), overflow lists (1000+ apps), launching invalid binaries, shortcut spam.
* **F3**: Storm flood (60+ notifications), extremely long text (5000 chars), null notifications, missing/invalid audio hooks, layout queue collisions.
* **F4**: Missing display sockets, double-spawn collisions, memory limits (<128MB), thread bounds (>4 threads), invalid CLI arguments.

### Tier 3: Cross-Feature Combinations (4 Tests)
Validates integration and state sync between components:
1. **StatusBar & Launcher Sync**: Verifies that toggling the launcher from the Status Bar syncs launcher visibility.
2. **Launch Notification**: Verifies that launching an app from the grid issues a warning/info toast.
3. **Stressed Notifications**: Verifies notification center processes alerts while the status bar diagnostics report 98%+ resource load.
4. **Sandbox Multi-Panel**: Verifies multiple widget panels load together in the active sandbox wrapper.

### Tier 4: Real-World Scenarios (5 Tests)
Simulates end-user flows and visual constraints:
1. **Session Initialization**: Login sequence -> status bar boot -> launcher grid build -> container start.
2. **Launcher Launch Flow**: Shortcut press -> grid fetch -> select app -> launch -> notify feedback.
3. **Telemetry Alert Sequence**: Telemetry warning -> warning toast trigger -> log assertion.
4. **Sandbox Restart Clean Exit**: Container start -> panel load -> container stop -> process/sockets clean up.
5. **Theme Conformity Audit Check**: Iterates through shell files (`desktop/shell/*.ts`) and stylesheets (`*.css`/`*.scss`) to ensure color hex codes and pixel sizing utilize variables from `theme.ts` / `theme.py` and contain no hardcoded overrides.
