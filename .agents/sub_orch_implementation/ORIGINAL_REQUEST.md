# Original User Request

## Initial Request — 2026-07-06T18:25:28Z

Your identity:
- Archetype: self
- Working directory: /home/xeno/Xeno-os/.agents/sub_orch_implementation
- Role: Implementation Track Orchestrator

Objective:
Build the neonic anime desktop shell and GUI environment (R1 Status Bar, R2 App Launcher, R3 Notification Center, R4 Sandbox Wrapper) in Astal v2 (TypeScript + Bun) and pass 100% of E2E tests.

Scope boundaries:
- Do NOT write or create tests for Tiers 1-4; consume the test suite built by the E2E Testing Track.
- Keep implementation authentic and strictly conformant to the visual/behavioral requirements.
- Strictly adhere to .cursorrules guardrails (no drop shadows, solid backgrounds, low polling rates, explicit dimensions).
- Never cheat or hardcode test results.

Input Information:
- Requirements: /home/xeno/Xeno-os/ORIGINAL_REQUEST.md
- Constraints & Guidelines: /home/xeno/Xeno-os/.cursorrules (under Project Pattern, Guardrail B, C, E)
- Scope: /home/xeno/Xeno-os/.agents/sub_orch_implementation/SCOPE.md
- Theme tokens: /home/xeno/Xeno-os/desktop/shell/theme.ts

Output Requirements:
- Create and maintain /home/xeno/Xeno-os/.agents/sub_orch_implementation/progress.md and /home/xeno/Xeno-os/.agents/sub_orch_implementation/plan.md (can base it on SCOPE.md).
- Create code files in /home/xeno/Xeno-os/desktop/shell/ (app.ts, widgets, styles) and sync with ~/teamwork_projects/neonic_anime_gui if needed.
- Create sandbox wrapper script.
- Compile and run under Bun with Astal v2.
- Perform white-box coverage hardening (Tier 5) during Phase 2.

Completion Criteria:
- Astal v2 compiler builds the project with zero TS errors.
- Status Bar, Launcher, Notification Center, and Sandbox Wrapper are fully implemented and functional.
- All E2E tests in TEST_READY.md pass with 100% success.
- White-box adversarial coverage hardening completes with clean results.
- Forensic Auditor validates code as authentic and clean.
- Handoff report is written to /home/xeno/Xeno-os/.agents/sub_orch_implementation/handoff.md and a message sent back to the parent.
