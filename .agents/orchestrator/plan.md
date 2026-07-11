# Project: Neonic Anime GUI Environment

## Architecture
- **Compositor / Display Protocol**: Wayland / X11
- **GUI Framework**: Astal v2 (TypeScript + Bun)
- **Styling**: Cyber-Nord CSS theme (neon pink `#ff007f`, cyan `#00ffff`, neon purple `#bc13fe`)
- **Modules**:
  - `status-bar`: Astal widget showing clock, system metrics (CPU/RAM), active workspace list, launcher control.
  - `app-launcher`: Anime-themed grid overlay displaying applications with neon selection highlights.
  - `notification-center`: Toast manager for warning and state messages with slide-in animations.
  - `sandbox-wrapper`: Environment script to run the shell in a standalone Wayland/X11 container.

## Milestones
| # | Track | Milestone Name | Scope | Dependencies | Status |
|---|---|---|---|---|---|
| M1 | Testing | E2E Test Suite | Build test infrastructure and coverage suite (Tiers 1-4) | None | DONE |
| M2 | Implementation | Project Setup | Initialize Astal v2, Bun configurations, and layout | None | DONE |
| M3 | Implementation | R1 Desktop Status Bar | Create Status Bar UI with live CPU/RAM and glow animations | M2 | DONE |
| M4 | Implementation | R2 Anime App Launcher | Build launcher overlay grid UI and custom highlights | M2 | DONE |
| M5 | Implementation | R3 Notification Center | Implement toast manager with slide-in and neon styling | M2 | DONE |
| M6 | Implementation | R4 Sandbox Wrapper | Develop script to run shell in window container | M3, M4, M5 | DONE |
| M7 | Implementation | Phase 1 E2E Pass | Fix implementation until 100% of E2E tests pass | M1, M6 | DONE |
| M8 | Implementation | Phase 2 Hardening | White-box adversarial testing and coverage hardening (Tier 5) | M7 | DONE |

## Code Layout
- Main code folder: `/home/xeno/Xeno-os/desktop/shell/` (or `~/teamwork_projects/neonic_anime_gui/`)
- E2E Tests: `/home/xeno/Xeno-os/desktop/shell/tests/` or `/home/xeno/Xeno-os/tests/`
