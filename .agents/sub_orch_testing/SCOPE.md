# Scope: E2E Testing Track

## Architecture
- **Approach**: Opaque-box, requirement-driven E2E tests.
- **Verification Channel**: Since the desktop shell runs as a GUI application under Bun and Astal v2, tests will verify CLI execution, configuration compilation, and standard outputs/state files, running in a Wayland/X11 container or headless environment if possible.
- **Features Under Test**:
  - F1: Status Bar (Astal v2 UI + live CPU/RAM)
  - F2: Anime App Launcher (Overlay grid UI)
  - F3: Neon Notification Center (Toast notifications)
  - F4: Sandbox Wrapper (Orchestration script)

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | Test Infra Setup | Design test runner and setup `TEST_INFRA.md` | None | PLANNED |
| 2 | Tier 1 & 2 Cases | Write feature coverage tests (Tier 1) and boundary/corner cases (Tier 2) | M1 | PLANNED |
| 3 | Tier 3 & 4 Cases | Write cross-feature combo tests (Tier 3) and application workloads (Tier 4) | M2 | PLANNED |
| 4 | Publish Ready | Publish `TEST_READY.md` containing coverage checklist and test runner commands | M3 | PLANNED |

## Interface Contracts
- The desktop shell must build and run using `bun run app.ts` (or similar configured script) inside the sandbox wrapper.
- Notification trigger: the test suite must be able to trigger notification toasts (e.g., via CLI or IPC) to verify slide-in animations and text rendering.
- Exit codes: standard shell command exits and script parameters.
