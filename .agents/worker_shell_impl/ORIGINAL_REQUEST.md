## 2026-07-07T17:58:36Z
You are the Shell Implementation Worker. Your task is to build the status bar, launcher, notification center, CSS styles, and sandbox wrapper under `/home/xeno/Xeno-os/desktop/shell/`.

Verbatim Integrity Warning:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Requirements:
1. Status Bar (Bar.ts):
- Clock widget updating every 1s.
- CPU and RAM diagnostic widgets updating every 2s. Read `/proc/stat` and `/proc/meminfo` directly using `GLib.file_get_contents` to compute percentages without spawning shell processes.
- Active workspaces list. Use `gi://AstalHyprland` to dynamically query workspaces, but wrap it in try/catch to fall back to a mock list `[1, 2, 3, 4]` (with `1` active) if Hyprland is unavailable.
- Launcher toggle control (button) that communicates visibility to the launcher widget.

2. Anime App Launcher (Launcher.ts):
- Fullscreen or overlay window container.
- Grid layout displaying applications. Include a list of fallback standard apps (Math Solver, Data Analysis, Code Notebook, 3D Viewer, Signal Analysis, Terminal, Settings) with their executable paths from `.cursorrules`.
- Search entry that filters the grid list. Clicking an app runs `GLib.spawn_command_line_async(app.exec)`.
- Highlight selections and hover states using neon colors from `theme.ts`.

3. Notification Center (Notifications.ts):
- Toast manager displaying alerts with neon border glow.
- GTK Revealer for slide-in animation.
- Start a simple HTTP listener using `Bun.serve` on port 5050 (or listen on `/tmp/xeno-notifications.sock`) that receives POST requests with json notifications and triggers the toast. This allows E2E tests to trigger notifications easily.

4. Entry Point (app.ts):
- Initialize and load widgets (Bar, Launcher, Notifications).
- Load CSS styles. You can dynamically construct a CSS stylesheet based on `theme.ts` values and write it to `/tmp/neonic-shell.css` at startup, then load it using `App.apply_css`.
- Ensure no hex codes, fonts, or pixel values are hardcoded; read everything from `./theme.ts`.

5. Sandbox Wrapper (sandbox.sh):
- Create `desktop/shell/sandbox.sh` using the dynamic path detection: `WS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"`.
- Setup environment variables for VM software rendering (e.g. `export WLR_RENDERER_ALLOW_SOFTWARE=1`).
- Start the shell with `bun run app.ts`.

6. Verification:
- Run `bun install` and `bun x tsc --noEmit` to verify type checking passes with zero errors.
- Sync files to `/home/xeno/teamwork_projects/neonic_anime_gui/` (creating the folder if it does not exist) as requested by the user.

Handoff & Reporting:
- Update `/home/xeno/Xeno-os/.agents/worker_shell_impl/progress.md` after each step.
- Create `/home/xeno/Xeno-os/.agents/worker_shell_impl/handoff.md` detailing changes made, compilation results, and verification command lines.
- State in your handoff which section of `.cursorrules` you found most relevant.
- Once complete, send a message back to parent ID `591be0b5-1781-4362-9ef9-f61cdffb0862`.
