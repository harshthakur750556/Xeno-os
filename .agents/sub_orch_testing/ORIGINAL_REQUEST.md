# Original User Request

## Initial Request — 2026-07-06T18:25:28Z

Your identity:
- Archetype: self
- Working directory: /home/xeno/Xeno-os/.agents/sub_orch_testing
- Role: E2E Testing Track Orchestrator

Objective:
Design and implement a comprehensive opaque-box E2E test suite for the Xeno OS neonic anime GUI environment, mapping to the requirements in /home/xeno/Xeno-os/ORIGINAL_REQUEST.md.

Scope boundaries:
- Test case design must be requirement-driven and opaque-box.
- Do NOT base tests on internal implementation structures.
- Do NOT implement the desktop shell itself; focus entirely on the E2E test suite and runner.

Input Information:
- Requirements: /home/xeno/Xeno-os/ORIGINAL_REQUEST.md
- Constraints & Guidelines: /home/xeno/Xeno-os/.cursorrules (under Project Pattern, Dual Track, Test Case Design Methodology)
- Scope: /home/xeno/Xeno-os/.agents/sub_orch_testing/SCOPE.md

Output Requirements:
- Create and maintain /home/xeno/Xeno-os/.agents/sub_orch_testing/progress.md and /home/xeno/Xeno-os/.agents/sub_orch_testing/plan.md (can base it on SCOPE.md).
- Create /home/xeno/Xeno-os/TEST_INFRA.md at project root, documenting the test philosophy, feature inventory, test runner, formats, and scenarios.
- Create /home/xeno/Xeno-os/TEST_READY.md at project root once the E2E test suite is fully implemented and ready.
- Store all test scripts/runner in the repository under /home/xeno/Xeno-os/desktop/shell/tests/ or /home/xeno/Xeno-os/tests/.

Completion Criteria:
- TEST_INFRA.md is populated and conforms to the template.
- Test runner compiles and runs.
- Minimum test thresholds are met:
  * Tier 1 (Feature Coverage): >=5 tests per feature (Status Bar, Launcher, Notifications, Sandbox)
  * Tier 2 (Boundary & Corner Cases): >=5 tests per feature
  * Tier 3 (Cross-Feature Combinations): pairwise coverage of major feature interactions
  * Tier 4 (Real-World Application Scenarios): >=5 realistic scenarios
- TEST_READY.md is published with a detailed checklist.
- Handoff report is written to /home/xeno/Xeno-os/.agents/sub_orch_testing/handoff.md and a message sent back to the parent.
