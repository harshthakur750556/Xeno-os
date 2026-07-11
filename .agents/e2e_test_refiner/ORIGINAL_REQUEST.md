## 2026-07-07T18:03:36Z
Role: E2E Test Refiner
Objective:
Refine and patch the E2E test suite and runner in `/home/xeno/Xeno-os/tests/` to address all reviewer findings and ensure correctness under both Simulation and Live modes.

Scope Boundaries:
- NEVER write, modify, or create source code files directly.
- NEVER run build/test commands yourself.
- Do NOT base tests on internal implementation structures.
- Focus entirely on patching the E2E test suite, simulator, mock binaries, and verifying they pass in Simulation Mode.

Patch Details:
1. Update `tests/test_e2e.py`:
   - Fix the multi-line comment stripping bug in `test_theme_conformity_audit_check`. Strip JS/TS/CSS block comments (`/* ... */` which can span multiple lines) on the full file content *before* splitting it into lines (e.g. using `re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)`).
   - Ensure `.scss` files are included in the comment-stripping check.
   - In `tearDownClass`, ensure `XENO_IPC_SOCKET` environment variable is cleaned up (e.g. `del os.environ["XENO_IPC_SOCKET"]`).
   - Update `hex_color_regex` to support 8-digit and 4-digit hex transparency colors. Ensure the regex pattern lists the longest format first to prevent partial matching (e.g. `re.compile(r'#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})\b')`).
   - In `test_auto_dismiss_transitions`, instead of bypassing dismiss in Live Mode, call `self.run_command("xeno-notify", ["--dismiss", "1"])` to dismiss the notification via the CLI tool, which is compatible with both Simulation and Live modes.
   - In `test_wayland_x11_container_execution`, ensure the sandbox container is stopped at the end of the test by executing `self.run_command("xeno-sandbox", ["--stop"])` to prevent process leaks under Live Mode.

2. Update `tests/bin/xeno-notify`:
   - Add support for the `--dismiss <id>` CLI flag, which sends the `"notification:dismiss"` command to the IPC socket with `{"id": int(sys.argv[2])}`.

3. Run the test suite under Simulation Mode using `python3 tests/run_tests.py` to confirm that all 49 tests run and pass cleanly.
4. Report the command output and confirm that all files have been correctly updated.
