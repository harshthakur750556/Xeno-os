# Scope: Implementation Track

## Architecture
- **Language/Runtime**: TypeScript, Bun, Astal v2, GTK3
- **Styling**: Cyber-Nord CSS theme (neon pink `#ff007f`, cyan `#00ffff`, neon purple `#bc13fe`)
- **Modules**:
  - `desktop/shell/theme.ts`: theme configuration tokens
  - `desktop/shell/app.ts`: main application setup
  - `desktop/shell/widget/Bar.ts`: status bar
  - `desktop/shell/widget/Launcher.ts`: grid app launcher overlay
  - `desktop/shell/widget/Notifications.ts`: toast manager
  - `desktop/shell/sandbox.sh`: sandbox orchestration script

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | Env Setup & Config | Initialize Bun project, configure package.json, TypeScript, and install Astal dependencies | None | PLANNED |
| 2 | R1 Desktop Status Bar | Build Astal v2 top status bar with CPU/RAM metrics and CSS animations | M1 | PLANNED |
| 3 | R2 Anime App Launcher | Build overlay app launcher panel with grid layout and neon effects | M1 | PLANNED |
| 4 | R3 Notification Center | Build toast manager with slide-in animation and neon borders | M1 | PLANNED |
| 5 | R4 Sandbox Wrapper | Write Wayland/X11 container execution wrapper | M2, M3, M4 | PLANNED |
| 6 | Phase 1 E2E Pass | Pass 100% of the testing track's E2E test cases | M5 | PLANNED |
| 7 | Phase 2 Hardening | White-box adversarial testing and coverage hardening (Tier 5) | M6 | PLANNED |

## Interface Contracts
- Must reference `desktop/shell/theme.ts` tokens for color, fonts, and dimensions (Guardrail B).
- No drop shadows, solid backgrounds only (Guardrail C).
- Low polling rates: Clock 1s, CPU/RAM meters 1-3s (Guardrail C).
