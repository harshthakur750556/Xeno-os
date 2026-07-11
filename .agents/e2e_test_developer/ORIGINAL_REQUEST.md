## 2026-07-06T18:26:33Z

Role: E2E Test Developer
Objective:
Design and implement a comprehensive opaque-box E2E test suite for the Xeno OS neonic anime GUI environment, mapping to the requirements in `/home/xeno/Xeno-os/ORIGINAL_REQUEST.md` and following the guidelines in `.cursorrules`.

Scope boundaries:
- Test case design must be requirement-driven and opaque-box.
- Do NOT base tests on internal implementation structures.
- Do NOT implement the desktop shell itself; focus entirely on the E2E test suite and runner.
- Create `/home/xeno/Xeno-os/TEST_INFRA.md` at project root, documenting the test philosophy, feature inventory, test runner, formats, and scenarios.
- Store all test scripts/runner in the repository under `/home/xeno/Xeno-os/tests/`.

Detailed Test Requirements:
1. Create a Python-based E2E test suite under `/home/xeno/Xeno-os/tests/` (e.g. `tests/test_e2e.py` and `tests/run_tests.py`). It should run using standard unittest (`python3 -m unittest discover -s tests` or `python3 tests/run_tests.py`).
2. Design and implement the following four tiers of tests:
   - Tier 1 (Feature Coverage): >=5 tests per feature (F1: Status Bar, F2: Launcher, F3: Notifications, F4: Sandbox Wrapper) -> at least 20 tests.
     * F1 (Status Bar): Clock updates (1s), CPU meter parsing, RAM meter parsing, active workspaces render, launcher toggle trigger.
     * F2 (Launcher): Application list grid, highlights, custom font settings, grid layout rendering, selection click event.
     * F3 (Notifications): Toast popups, warning logs, animation configuration, sound hooks execution, auto-dismiss transitions.
     * F4 (Sandbox): Wayland/X11 container execution, thread allocation bounds, panel widget loading, sandbox start/stop scripts, performance metrics.
   - Tier 2 (Boundary & Corner Cases): >=5 tests per feature -> at least 20 tests.
     * F1: Empty/Null CPU/RAM diagnostics, clock DST/leap transition boundaries, out-of-range CPU (>100% or <0%), active workspace array overflows, rapid toggle spam.
     * F2: Empty applications grid, extreme font sizes (0 or 1000px), overflow bounds of application list, launching non-existent applications, high-frequency launcher shortcut presses.
     * F3: High-frequency notification storm (flooding), extremely long text strings, null message warning notifications, unsupported sound files/hooks, overlapping/collision layout of multiple notifications.
     * F4: Missing graphics drivers/display sockets, concurrent double-spawn wrapper run collisions, running under extreme memory limits, max thread allocation exhaust boundaries, script parameter validation (invalid flags).
   - Tier 3 (Cross-Feature Combinations): >=4 tests checking pairwise interactions (Status Bar & Launcher toggle synchronization, App launch with notifications, Notifications under high resource stress, Sandbox multi-panel scaling).
   - Tier 4 (Real-World Application Scenarios): >=5 realistic use case scenarios (System Boot & Session Initialization, Application Launch Flow, System Telemetry & Alert Scenario, Sandbox Restart & Clean Exit, Theme Conformity Audit Check verifying that shell files and CSS utilize the variables from theme.ts and have no hardcoded colors/pixels).

3. To handle parallel development (since the shell implementation is done in another track), build the tests to have:
   - A Simulation/Mock Mode: The E2E tests can run and verify their own assertion pipelines and validation mechanisms (e.g., against simulated shell logs, mock configs, or a local test server). This ensures the E2E test runner compiles and runs successfully (all tests pass) as proof of correct design.
   - A Live Mode: Configurable via environment variable or CLI flag, running tests against the actual desktop shell implementation (once built by the other track).

4. Create the `/home/xeno/Xeno-os/TEST_INFRA.md` at project root, describing the philosophy, feature inventory, test cases, and execution commands.
5. Create the `/home/xeno/Xeno-os/TEST_READY.md` at project root when the test suite is complete and passing under Simulation Mode.

## 2026-07-07T17:57:25Z
A system restart occurred. Please check the status of your work on designing and implementing the E2E test suite (creating tests/run_tests.py, tests/test_e2e.py, tests/simulator.py, TEST_INFRA.md, and TEST_READY.md). If you have already created some of these files, verify their completeness against the original objectives. Specifically, ensure that all 49 tests (Tiers 1-4) are implemented, and that the tests compile and run successfully in simulation mode. Once they pass and are ready, publish TEST_READY.md and report back with your findings.
