# Plan: Astal v2 Desktop Shell Implementation

This plan details the steps to build the neonic anime desktop shell and GUI environment in Astal v2.

## Milestones

### Milestone 1: Env Setup & Config
- **Task**: Initialize Bun project configuration in `desktop/shell/`, create `package.json` with correct scripts and dependencies (Astal, Gtk, Gdk, Hyprland services), and configure `tsconfig.json`.
- **Verification**: Run `bun install` and run `tsc --noEmit` to verify type checking.
- **Worker Prompt Focus**: Project initialization and dependencies setup.

### Milestone 2: R1 Desktop Status Bar
- **Task**: Create `desktop/shell/widget/Bar.ts` and style overrides in CSS. Embed a clock (1s poll rate), system diagnostics (CPU/RAM meters at 2s poll rate), Hyprland active workspaces list, and launcher control.
- **Verification**: Build widget and run type checks. Confirm styling maps to `theme.ts` tokens.
- **Worker Prompt Focus**: Status bar UI, system polling, and GTK styling.

### Milestone 3: R2 Anime App Launcher
- **Task**: Create `desktop/shell/widget/Launcher.ts`. Implement an overlay grid panel showing desktop applications, search input, and neon hover states.
- **Verification**: Run type checks and verify launcher logic.
- **Worker Prompt Focus**: Launcher UI grid, search filtering.

### Milestone 4: R3 Notification Center
- **Task**: Create `desktop/shell/widget/Notifications.ts`. Implement a toast daemon/manager displaying transient notifications with neon borders and slide-in animations.
- **Verification**: Check compilation and basic event emitting.
- **Worker Prompt Focus**: Notification notification/toast manager.

### Milestone 5: R4 Sandbox Wrapper
- **Task**: Create `desktop/shell/sandbox.sh`. Standalone script to spin up the Wayland compositor or nested container running the shell widgets.
- **Verification**: Script execution check and container validation.
- **Worker Prompt Focus**: Wayland wrapper, display environment variables.

### Milestone 6: Phase 1 E2E Pass
- **Task**: Integrate E2E test suite from `TEST_READY.md`. Fix any bugs shown by the tests.
- **Verification**: 100% test success of Tiers 1-4 tests.

### Milestone 7: Phase 2 Hardening
- **Task**: Challenger runs white-box coverage analysis on the shell TypeScript code. Add adversarial test cases and fix discovered edge cases.
- **Verification**: Zero coverage gaps reported by Challenger.

## Guardrails
- **Solid Backgrounds**: Ensure all widgets use theme.ts colors, no transparency less than 0.9, no CSS `backdrop-filter: blur()`, no `box-shadow` with large blurs.
- **Static Dimensions**: Explicit widths and heights from theme tokens.
- **Low Polling Rates**: Clock = 1s, system metrics = 2s.
