# Original User Request

## Initial Request — 2026-07-06T18:19:55Z

Build a full-fledged, futuristic, neonic, anime-styled desktop shell and GUI environment for Xeno OS (running on Astal v2 with Bun) to serve as a standalone sandbox demonstration.

Working directory: ~/teamwork_projects/neonic_anime_gui
Integrity mode: demo

## Requirements

### R1. Desktop Status Bar (Astal v2)
Create a highly stylized status bar using Astal v2 (TypeScript + Bun) containing clock, system diagnostics (CPU/RAM meters), active workspace lists, and launcher controls. Visuals must feature neon glow borders, customizable CSS animations, and semi-transparent backgrounds.

### R2. Anime App Launcher
Build an overlay app launcher panel displaying applications in a futuristic grid layout with neon selection highlights, custom fonts, and integrated anime-styled graphic assets.

### R3. Neon Notification Center
Develop an on-screen toast manager to handle system warnings, messages, and state transitions using neonic border glows, custom sound hooks (if available), and slide-in animations.

### R4. Sandbox Wrapper
Provide an environment orchestration script to run the desktop shell, launcher, and widget pages in a standalone Wayland/X11 window container without causing native thread allocation collisions.

## Acceptance Criteria

### Compilability and Execution
- [ ] Astal v2 compiler builds the project with zero TypeScript syntax errors.
- [ ] The shell bar launches and binds successfully under the Bun runtime.

### Theme Conformity
- [ ] Stylesheet overrides use a neonic Cyber-Nord palette mapping neon pink (`#ff007f`), cyan (`#00ffff`), and neon purple (`#bc13fe`) as borders and animations.
- [ ] Layout renders custom fonts and supports background artwork overlays.

### Diagnostics and Controls
- [ ] Status bar displays live system diagnostics (CPU and RAM percentages) using custom animated progress meters.
- [ ] Launching the overlay is stable and does not cause BadWindow or X11 segment violations.
