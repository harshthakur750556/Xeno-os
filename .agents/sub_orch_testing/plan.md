# plan.md — E2E Testing Track Plan

## Objectives
Design and implement a comprehensive opaque-box E2E test suite for the Xeno OS neonic anime GUI environment, covering the Status Bar (F1), Anime App Launcher (F2), Neon Notification Center (F3), and Sandbox Wrapper (F4).

## Test Architecture
- **Location**: `/home/xeno/Xeno-os/tests/` (E2E test suite and test runner).
- **Language**: Python or TypeScript (Bun), executing the shell/sandbox as subprocesses, validating exit codes, log outputs, DBus/socket interfaces, theme token adherence, and shell compilation.
- **Verification Strategy**:
  - Headless/Command-line verification of Astal shell compilation (`bun run build` or similar compiler checks).
  - Validation of the Sandbox Wrapper script syntax, parameters, and container configuration.
  - Verification of notification triggers (e.g. sending a notification and validating IPC/socket message or log).
  - Theme conformity validator (verifying that CSS/config references theme.ts tokens and contains no hardcoded colors/px/fonts).
  - CLI flag and runtime parameter checks.

## Milestones

### Milestone 1: Test Infra Setup & Design
- Create `/home/xeno/Xeno-os/TEST_INFRA.md` detailing the test philosophy, feature inventory, test cases, and runner commands.
- Initialize the test runner at `/home/xeno/Xeno-os/tests/run_tests.py` or `/home/xeno/Xeno-os/tests/runner.ts`.
- Set up helper libraries for running process pipelines, checking memory limits, and auditing theme usage.

### Milestone 2: Tier 1 & Tier 2 Test Cases
- Implement Tier 1 (Feature Coverage): >=5 tests per feature.
  - F1 (Status Bar): Clock update check, CPU parsing check, RAM parsing check, Workspace parsing check, Launcher button action.
  - F2 (Launcher): Application list fetch, Grid alignment properties check, Highlight state check, Custom font mapping check, App selection logic.
  - F3 (Notifications): Toast dispatch check, Warning message parsing check, Anim duration configuration check, Sound hook invocation check, Dismissal transition check.
  - F4 (Sandbox): Wayland container boot check, Thread allocation limit check, Widget page load check, Wrapper syntax check, Execution stability check.
- Implement Tier 2 (Boundary & Corner Cases): >=5 tests per feature.
  - F1: Missing system monitor variables, Clock DST/leap transitions, Over-limit CPU/RAM percentages, Workspace out of bounds, Rapid launcher toggle.
  - F2: Empty applications menu, Extreme font size parameter, Overflowing grid list, Invalid application binary execution, Launcher hotkey rapid-press.
  - F3: High-frequency notification flooding, Long notification strings, Empty warning message, Unsupported sound hooks, Notification overlay collisions.
  - F4: Missing Wayland/X11 display socket, Double-spawn window collisions, Memory exhaustion limits, Native thread allocation overflow, Sandbox script missing arguments.

### Milestone 3: Tier 3 & Tier 4 Test Cases
- Implement Tier 3 (Cross-Feature Combinations): pairwise interactions (Status Bar & Launcher toggle, Launcher launching app with notifications, Notification popups during high CPU/RAM system diagnostics, Sandbox wrapper scaling with multiple panels).
- Implement Tier 4 (Real-World Application Scenarios): >=5 application-level scenarios (Standard login & workspace boot; Launching math and data panels via grid; Notification flood under high load; Clean sandbox tear down; Theme token compliance check on visual stylesheets).

### Milestone 4: Verification & TEST_READY.md
- Run test runner and verify it executes properly.
- Publish `/home/xeno/Xeno-os/TEST_READY.md` containing the E2E Test Suite Ready statement, feature checklist, and execution guidelines.
