import unittest
import os
import sys
import socket
import json
import subprocess
import time
import re

class XenoE2ETestCase(unittest.TestCase):
    live_mode = False
    simulator = None
    socket_path = None
    original_path = None

    @classmethod
    def setUpClass(cls):
        # Determine mode
        cls.live_mode = os.environ.get("XENO_E2E_LIVE", "").lower() in ("1", "true", "yes")
        
        if not cls.live_mode:
            # Import simulator inline to avoid loading errors if running in live mode on systems without it
            from tests.simulator import XenoSystemSimulator
            cls.simulator = XenoSystemSimulator()
            cls.socket_path = cls.simulator.start()
            
            # Save original PATH and prepend the mock binary folder
            cls.original_path = os.environ.get("PATH")
            mock_bin_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "bin"))
            os.environ["PATH"] = f"{mock_bin_dir}{os.path.pathsep}{cls.original_path}"
            os.environ["XENO_IPC_SOCKET"] = cls.socket_path
        else:
            # Under Live Mode, default to standard socket path if not provided
            if "XENO_IPC_SOCKET" not in os.environ:
                os.environ["XENO_IPC_SOCKET"] = "/tmp/xeno-ipc.sock"

    @classmethod
    def tearDownClass(cls):
        if not cls.live_mode and cls.simulator:
            cls.simulator.stop()
            if cls.original_path:
                os.environ["PATH"] = cls.original_path
        if "XENO_IPC_SOCKET" in os.environ:
            del os.environ["XENO_IPC_SOCKET"]

    def setUp(self):
        # Reset simulator state before each test case for test isolation
        if not self.live_mode and self.simulator:
            self.send_simulator_command("simulator:clear_state")
            time.sleep(0.01)

    def send_simulator_command(self, command, params=None):
        """Send direct control request to background simulator socket."""
        if self.live_mode:
            return None
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(self.socket_path)
            payload = {"command": command, "params": params or {}}
            s.sendall(json.dumps(payload).encode('utf-8'))
            s.shutdown(socket.SHUT_WR)
            resp = s.recv(262144)
            s.close()
            return json.loads(resp.decode('utf-8'))
        except Exception as e:
            self.fail(f"Failed to communicate with simulator: {e}")

    def run_command(self, cmd, args=None):
        """Helper to run a shell command and capture stdout/stderr."""
        full_cmd = [cmd] + (args or [])
        res = subprocess.run(full_cmd, capture_output=True, text=True, env=os.environ)
        return res.stdout, res.stderr, res.returncode

    # =========================================================================
    # TIER 1: FEATURE COVERAGE (20 Tests, 5 per Feature)
    # =========================================================================

    # --- F1: Status Bar ---
    def test_clock_updates_at_one_second_intervals(self):
        """Verify clock updates correctly at 1-second intervals."""
        self.send_simulator_command("simulator:set_clock", {"time": "2026-07-06 18:26:33"})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertEqual(code, 0)
        self.assertIn("2026-07-06 18:26:33", stdout)

        # Advance by 1 second
        self.send_simulator_command("simulator:set_clock", {"time": "2026-07-06 18:26:34"})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertEqual(code, 0)
        self.assertIn("2026-07-06 18:26:34", stdout)

    def test_cpu_meter_parsing_valid(self):
        """Verify CPU meter diagnostic parsing of typical usage percentages."""
        self.send_simulator_command("simulator:set_cpu", {"cpu": 24.5})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-cpu"])
        self.assertEqual(code, 0)
        self.assertIn("CPU: 24.5%", stdout.strip())

    def test_ram_meter_parsing_valid(self):
        """Verify RAM meter diagnostic parsing of used/total system memory."""
        ram_state = {"used": 8.0, "total": 16.0, "percent": 50.0}
        self.send_simulator_command("simulator:set_ram", {"ram": ram_state})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-ram"])
        self.assertEqual(code, 0)
        self.assertIn("RAM: 8.0GB / 16.0GB (50.0%)", stdout.strip())

    def test_active_workspaces_render(self):
        """Verify active workspaces list renders with proper active selection highlights."""
        self.send_simulator_command("simulator:set_workspaces", {"workspaces": [1, 2, 3, 4], "active": 3})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-workspaces"])
        self.assertEqual(code, 0)
        self.assertIn("Workspaces: 1, 2, [3], 4", stdout.strip())

    def test_launcher_toggle_trigger(self):
        """Verify launcher toggles visible state on status bar trigger event."""
        # Initial toggle (show)
        stdout, _, code = self.run_command("xeno-status-bar", ["--toggle-launcher"])
        self.assertEqual(code, 0)
        self.assertIn("Launcher toggled: True", stdout.strip())
        
        # Second toggle (hide)
        stdout, _, code = self.run_command("xeno-status-bar", ["--toggle-launcher"])
        self.assertEqual(code, 0)
        self.assertIn("Launcher toggled: False", stdout.strip())

    # --- F2: Launcher ---
    def test_application_list_grid(self):
        """Verify launcher lists the grid layout of applications correctly."""
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0)
        self.assertIn("[terminal] Terminal", stdout)
        self.assertIn("[filemanager] File Manager", stdout)

    def test_launcher_selection_highlights(self):
        """Verify selection cursor highlight index state."""
        self.send_simulator_command("simulator:set_launcher_state", {"highlighted_index": 2})
        stdout, _, code = self.run_command("xeno-launcher", ["--get-state"])
        self.assertEqual(code, 0)
        self.assertIn("Highlighted: 2", stdout)

    def test_launcher_custom_font_settings(self):
        """Verify custom typography and font size parameters are applied to launcher."""
        self.send_simulator_command("simulator:set_launcher_state", {
            "font_family": "JetBrains Mono",
            "font_size": 18
        })
        stdout, _, code = self.run_command("xeno-launcher", ["--get-state"])
        self.assertEqual(code, 0)
        self.assertIn("Font: JetBrains Mono 18px", stdout)

    def test_launcher_grid_layout_rendering(self):
        """Verify application names, run commands, and icons render correctly in grid format."""
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0)
        self.assertIn("Terminal - bash (utilities-terminal)", stdout.strip())

    def test_launcher_selection_click_event(self):
        """Verify selecting/clicking an application spawns launcher launch action."""
        stdout, _, code = self.run_command("xeno-launcher", ["--launch", "terminal"])
        self.assertEqual(code, 0)
        self.assertIn("Launched application: terminal", stdout)

    # --- F3: Notifications ---
    def test_toast_popup_dispatch(self):
        """Verify notification center processes and registers toast popup dispatches."""
        stdout, _, code = self.run_command("xeno-notify", ["--send", "System Update", "Download complete"])
        self.assertEqual(code, 0)
        self.assertIn("Notification Sent [ID: 1]", stdout)

    def test_warning_logs_parsing(self):
        """Verify warning level logs parse correctly in notification storage logs."""
        self.run_command("xeno-notify", ["--send", "Low Battery", "15% remaining", "--urgency", "warning"])
        stdout, _, code = self.run_command("xeno-notify", ["--get-logs"])
        self.assertEqual(code, 0)
        self.assertIn("WARNING: Low Battery - 15% remaining", stdout)

    def test_notification_animation_configuration(self):
        """Verify notifications retain custom duration transitions."""
        self.run_command("xeno-notify", ["--send", "Alert", "Text", "--timeout", "5000"])
        stdout, _, code = self.run_command("xeno-notify", ["--get-queue"])
        self.assertEqual(code, 0)
        self.assertIn("Timeout: 5000ms", stdout)

    def test_sound_hooks_execution(self):
        """Verify custom audio hooks execution trigger on notification arrival."""
        self.run_command("xeno-notify", ["--send", "Ping", "Hello", "--sound", "ping.wav"])
        if not self.live_mode:
            res = self.send_simulator_command("simulator:get_sound_played")
            self.assertIn("ping.wav", res.get("sound_played", []))

    def test_auto_dismiss_transitions(self):
        """Verify auto-dismiss transitions remove toasts from active queue."""
        self.run_command("xeno-notify", ["--send", "Temp", "Dismiss me"])
        
        # Check it is in queue
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertIn("Temp", stdout)
        
        # Perform dismiss command
        self.run_command("xeno-notify", ["--dismiss", "1"])
            
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertNotIn("Temp", stdout)

    # --- F4: Sandbox ---
    def test_wayland_x11_container_execution(self):
        """Verify container starts and loads environment display variables."""
        try:
            stdout, _, code = self.run_command("xeno-sandbox", ["--start"])
            self.assertEqual(code, 0)
            self.assertIn("Sandbox started successfully", stdout)
        finally:
            self.run_command("xeno-sandbox", ["--stop"])

    def test_thread_allocation_bounds(self):
        """Verify sandbox runs correctly under valid thread bounds."""
        stdout, _, code = self.run_command("xeno-sandbox", ["--start", "--threads", "3"])
        self.assertEqual(code, 0)
        
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("Threads: 3/4", stdout)

    def test_panel_widget_loading(self):
        """Verify dynamic panel widgets load correctly inside active container."""
        self.run_command("xeno-sandbox", ["--start"])
        stdout, _, code = self.run_command("xeno-sandbox", ["--load-panel", "math_panel"])
        self.assertEqual(code, 0)
        self.assertIn("Panel math_panel loaded successfully", stdout)

    def test_sandbox_start_stop_scripts(self):
        """Verify sandbox environment start and stop scripts cycle execution state cleanly."""
        self.run_command("xeno-sandbox", ["--start"])
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("Sandbox Status: Running", stdout)

        self.run_command("xeno-sandbox", ["--stop"])
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("Sandbox Status: Stopped", stdout)

    def test_sandbox_performance_metrics(self):
        """Verify sandbox reports current resource telemetry allocation limits."""
        self.run_command("xeno-sandbox", ["--start", "--memory", "1GB", "--threads", "2"])
        stdout, _, code = self.run_command("xeno-sandbox", ["--status"])
        self.assertEqual(code, 0)
        self.assertIn("Memory Limit: 1GB", stdout)
        self.assertIn("Threads: 2/4", stdout)

    # =========================================================================
    # TIER 2: BOUNDARY & CORNER CASES (20 Tests, 5 per Feature)
    # =========================================================================

    # --- F1: Status Bar Boundaries ---
    def test_empty_null_cpu_ram_diagnostics(self):
        """Verify status bar handles empty/null diagnostic data streams."""
        self.send_simulator_command("simulator:set_cpu", {"cpu": 0.0})
        self.send_simulator_command("simulator:set_ram", {"ram": {"used": 0.0, "total": 16.0, "percent": 0.0}})
        stdout_cpu, _, _ = self.run_command("xeno-status-bar", ["--get-cpu"])
        stdout_ram, _, _ = self.run_command("xeno-status-bar", ["--get-ram"])
        self.assertIn("0%", stdout_cpu)
        self.assertIn("0.0%", stdout_ram)

    def test_clock_dst_leap_transition_boundaries(self):
        """Verify clock format calculations over leap year day boundary transitions."""
        self.send_simulator_command("simulator:set_clock", {"time": "2026-02-28 23:59:59"})
        stdout, _, _ = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertIn("2026-02-28 23:59:59", stdout)

        self.send_simulator_command("simulator:set_clock", {"time": "2026-03-01 00:00:00"})
        stdout, _, _ = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertIn("2026-03-01 00:00:00", stdout)

    def test_out_of_range_cpu_values(self):
        """Verify status bar clamps or handles extreme out-of-range CPU values (>100% or <0%)."""
        self.send_simulator_command("simulator:set_cpu", {"cpu": 150.0})
        stdout, _, _ = self.run_command("xeno-status-bar", ["--get-cpu"])
        self.assertIn("100.0%", stdout) # Clamped to maximum 100%

    def test_active_workspace_array_overflows(self):
        """Verify status bar handles massive workspace lists without buffer crashes."""
        large_workspaces = list(range(1, 101))
        self.send_simulator_command("simulator:set_workspaces", {"workspaces": large_workspaces, "active": 99})
        stdout, _, code = self.run_command("xeno-status-bar", ["--get-workspaces"])
        self.assertEqual(code, 0)
        self.assertIn("[99]", stdout)

    def test_rapid_toggle_spam(self):
        """Verify rapid repeated status bar toggle clicks do not lead to race lockups."""
        for _ in range(20):
            _, _, code = self.run_command("xeno-status-bar", ["--toggle-launcher"])
            self.assertEqual(code, 0)

    # --- F2: Launcher Boundaries ---
    def test_empty_applications_grid(self):
        """Verify launcher rendering and messaging with empty apps grid."""
        self.send_simulator_command("simulator:set_applications", {"applications": []})
        stdout, _, code = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code, 0)
        self.assertIn("Applications grid: empty", stdout)

    def test_extreme_font_sizes(self):
        """Verify launcher layout constraints with extreme sizes (0px or 1000px)."""
        self.send_simulator_command("simulator:set_launcher_state", {"font_size": 1000})
        stdout, _, code = self.run_command("xeno-launcher", ["--get-state"])
        self.assertEqual(code, 0)
        self.assertIn("1000px", stdout)

    def test_overflow_bounds_app_list(self):
        """Verify overflow scaling bounds of launcher with 1000+ app listings."""
        huge_apps = [{"id": f"app_{i}", "name": f"App {i}", "command": "true", "icon": "app"} for i in range(1000)]
        self.send_simulator_command("simulator:set_applications", {"applications": huge_apps})
        stdout, stderr, code = self.run_command("xeno-launcher", ["--list-apps"])
        if code != 0:
            print(f"DEBUG: stdout={stdout!r}, stderr={stderr!r}")
        self.assertEqual(code, 0)
        self.assertIn("app_999", stdout)

    def test_launching_non_existent_applications(self):
        """Verify launching missing binaries reports failure gracefully."""
        _, stderr, code = self.run_command("xeno-launcher", ["--launch", "non_existent_binary"])
        self.assertNotEqual(code, 0)
        self.assertIn("not found", stderr.lower())

    def test_high_frequency_launcher_shortcut_presses(self):
        """Verify rapid overlay toggles do not crash the XServer/Wayland thread loops."""
        for _ in range(25):
            _, _, code = self.run_command("xeno-launcher", ["--press-shortcut"])
            self.assertEqual(code, 0)

    # --- F3: Notifications Boundaries ---
    def test_high_frequency_notification_storm(self):
        """Verify notification center queue integrity under heavy storm floods."""
        for i in range(60):
            _, _, code = self.run_command("xeno-notify", ["--send", f"Storm {i}", "Flooding system"])
            self.assertEqual(code, 0)
        
        # Verify queue continues to function and has records
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertTrue(len(stdout) > 0)

    def test_extremely_long_text_strings(self):
        """Verify notification center handles large character payload titles/bodies safely."""
        long_body = "A" * 5000
        stdout, _, code = self.run_command("xeno-notify", ["--send", "Warning", long_body])
        self.assertEqual(code, 0)
        self.assertIn("Notification Sent", stdout)

    def test_null_message_warning_notifications(self):
        """Verify notification center rejects null/empty message contents."""
        _, stderr, code = self.run_command("xeno-notify", ["--send", "", ""])
        self.assertNotEqual(code, 0)
        self.assertIn("cannot both be empty", stderr.lower())

    def test_unsupported_sound_files_hooks(self):
        """Verify notification plays without crashing on invalid or missing audio hook paths."""
        stdout, _, code = self.run_command("xeno-notify", ["--send", "Alert", "Msg", "--sound", "/invalid/path.mp3"])
        self.assertEqual(code, 0)
        self.assertIn("Notification Sent", stdout)

    def test_overlapping_collision_layout(self):
        """Verify notification queue structures avoid visual index coordinates collision crashes."""
        # Flood layout to check warnings
        for i in range(8):
            self.run_command("xeno-notify", ["--send", f"Notif {i}", "Layout Check"])
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertTrue(len(stdout.splitlines()) >= 8)

    # --- F4: Sandbox Boundaries ---
    def test_missing_graphics_drivers_display_sockets(self):
        """Verify sandbox refuses boot cleanly if display server socket is missing."""
        self.send_simulator_command("simulator:set_display_socket", {"display_socket_exists": False})
        _, stderr, code = self.run_command("xeno-sandbox", ["--start"])
        self.assertEqual(code, 1)
        self.assertIn("no wayland or x11 graphics driver/display socket found", stderr.lower())

    def test_concurrent_double_spawn_collisions(self):
        """Verify sandbox instance locks trigger exit codes on double execution collision."""
        # Spawn first
        _, _, code1 = self.run_command("xeno-sandbox", ["--start"])
        self.assertEqual(code1, 0)
        
        # Try spawning second
        _, stderr, code2 = self.run_command("xeno-sandbox", ["--start"])
        self.assertEqual(code2, 2)
        self.assertIn("concurrent sandbox wrapper spawn collision", stderr.lower())

    def test_extreme_memory_limits(self):
        """Verify sandbox validation rejects memory limits below runtime requirements."""
        _, stderr, code = self.run_command("xeno-sandbox", ["--start", "--memory", "64MB"])
        self.assertEqual(code, 3)
        self.assertIn("memory allocation below 128mb threshold", stderr.lower())

    def test_max_thread_allocation_exhaust_boundaries(self):
        """Verify sandbox rejects launching thread count exceeding physical core allocations."""
        _, stderr, code = self.run_command("xeno-sandbox", ["--start", "--threads", "16"])
        self.assertEqual(code, 3)
        self.assertIn("native thread allocation limit exceeded", stderr.lower())

    def test_script_parameter_validation(self):
        """Verify sandbox CLI tools reject invalid flag scripts with usage messages."""
        _, stderr, code = self.run_command("xeno-sandbox", ["--invalid-flag"])
        self.assertEqual(code, 1)
        self.assertIn("invalid flag", stderr.lower())

    # =========================================================================
    # TIER 3: CROSS-FEATURE COMBINATIONS (4 Tests)
    # =========================================================================

    def test_status_bar_launcher_toggle_sync(self):
        """Verify status bar launcher button triggers synchronized toggle state updates in launcher."""
        # Initially hidden
        stdout, _, _ = self.run_command("xeno-launcher", ["--get-state"])
        self.assertIn("Visible: False", stdout)
        
        # Toggle via Status Bar
        self.run_command("xeno-status-bar", ["--toggle-launcher"])
        stdout, _, _ = self.run_command("xeno-launcher", ["--get-state"])
        self.assertIn("Visible: True", stdout)

        # Toggle via Launcher Shortcut
        self.run_command("xeno-launcher", ["--press-shortcut"])
        stdout, _, _ = self.run_command("xeno-launcher", ["--get-state"])
        self.assertIn("Visible: False", stdout)

    def test_app_launch_with_notifications(self):
        """Verify launching an application from the grid triggers launcher dispatch warning toasts."""
        self.run_command("xeno-launcher", ["--launch", "terminal"])
        
        # Verify notification was queued
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertIn("System Launch", stdout)
        self.assertIn("Launching Terminal inside container...", stdout)

    def test_notifications_under_high_resource_stress(self):
        """Verify notifications dispatch correctly while status bar handles high CPU/RAM workloads."""
        # Stress system metrics
        self.send_simulator_command("simulator:set_cpu", {"cpu": 98.2})
        self.send_simulator_command("simulator:set_ram", {"ram": {"used": 15.5, "total": 16.0, "percent": 96.8}})
        
        # Trigger notifications
        for i in range(5):
            self.run_command("xeno-notify", ["--send", f"Critical Alert {i}", "System resources stressed"])
            
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertIn("Critical Alert 4", stdout)

    def test_sandbox_multi_panel_scaling(self):
        """Verify sandbox wrapper scaling works with multiple concurrent active panels."""
        self.run_command("xeno-sandbox", ["--start"])
        self.run_command("xeno-sandbox", ["--load-panel", "math_panel"])
        self.run_command("xeno-sandbox", ["--load-panel", "code_panel"])
        
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("math_panel, code_panel", stdout)

    # =========================================================================
    # TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 Tests)
    # =========================================================================

    def test_system_boot_session_initialization(self):
        """Scenario 1: Cold system boot and desktop UI initialization cycle."""
        # 1. Login session starts
        self.run_command("xeno-notify", ["--send", "Session Init", "Starting Xeno session..."])
        
        # 2. Status bar connects
        _, _, code1 = self.run_command("xeno-status-bar", ["--get-clock"])
        self.assertEqual(code1, 0)
        
        # 3. App launcher builds grid
        _, _, code2 = self.run_command("xeno-launcher", ["--list-apps"])
        self.assertEqual(code2, 0)
        
        # 4. Sandbox starts
        _, _, code3 = self.run_command("xeno-sandbox", ["--start"])
        self.assertEqual(code3, 0)
        
        # 5. Confirm logs record boot initialization
        stdout, _, _ = self.run_command("xeno-notify", ["--get-logs"])
        self.assertIn("Session Init", stdout)

    def test_application_launch_flow(self):
        """Scenario 2: User browsing launcher grid, selecting app, sandbox launching, and notification feedback."""
        # 1. Open launcher
        self.run_command("xeno-launcher", ["--press-shortcut"])
        
        # 2. Fetch apps grid
        self.run_command("xeno-launcher", ["--list-apps"])
        
        # 3. Click application (terminal)
        self.run_command("xeno-launcher", ["--launch", "terminal"])
        
        # 4. Check sandbox status showing panel load or active program
        self.run_command("xeno-sandbox", ["--start"])
        self.run_command("xeno-sandbox", ["--load-panel", "terminal"])
        
        # 5. Check toast dispatch
        stdout, _, _ = self.run_command("xeno-notify", ["--get-queue"])
        self.assertIn("System Launch", stdout)

    def test_system_telemetry_alert_scenario(self):
        """Scenario 3: CPU utilization exceeds warning threshold, triggering status bar alerts and telemetry log warnings."""
        # 1. High CPU detected
        self.send_simulator_command("simulator:set_cpu", {"cpu": 95.0})
        
        # 2. Auto-warning trigger sends warning toast
        self.run_command("xeno-notify", ["--send", "CPU Alert", "CPU usage at 95.0%", "--urgency", "warning"])
        
        # 3. Check logs to verify warning is parsed and formatted
        stdout, _, _ = self.run_command("xeno-notify", ["--get-logs"])
        self.assertIn("WARNING: CPU Alert - CPU usage at 95.0%", stdout)

    def test_sandbox_restart_clean_exit(self):
        """Scenario 4: Running panel workspace, issuing restart command, verifying clean subprocess tear down and sockets cleanup."""
        # 1. Sandbox starts
        self.run_command("xeno-sandbox", ["--start"])
        self.run_command("xeno-sandbox", ["--load-panel", "data_panel"])
        
        # 2. Clean exit / stop
        self.run_command("xeno-sandbox", ["--stop"])
        
        # 3. Verify stopped state and panels cleared
        stdout, _, _ = self.run_command("xeno-sandbox", ["--status"])
        self.assertIn("Sandbox Status: Stopped", stdout)
        self.assertNotIn("data_panel", stdout)

    def test_theme_conformity_audit_check(self):
        """Scenario 5: Audit all shell files (TS/JS/CSS) to verify no hardcoded color/pixel values exist outside theme.ts/theme.py."""
        workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        
        # Directories to search
        shell_dir = os.path.join(workspace_root, "desktop", "shell")
        
        # Regex definitions
        # Matches hex color codes (e.g. #ff007f, #00ffff)
        hex_color_regex = re.compile(r'#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})\b')
        # Matches hardcoded dimensions (e.g. 10px, 24px) but permits 0px, 1px, 2px as standard line widths/resets
        hardcoded_px_regex = re.compile(r'\b([3-9]|\d{2,})px\b')
        
        violations = []
        
        # Walk desktop directory looking for css/scss/ts files
        desktop_dir = os.path.join(workspace_root, "desktop")
        for root, _, files in os.walk(desktop_dir):
            is_shell_path = shell_dir in os.path.abspath(root)
            
            for file in files:
                filepath = os.path.join(root, file)
                
                # Check condition: Is it a CSS stylesheet anywhere, or any TS file in the shell folder
                # Skip the theme configuration files themselves
                if file in ("theme.ts", "theme.py"):
                    continue
                    
                is_css = file.endswith((".css", ".scss"))
                is_shell_ts = is_shell_path and file.endswith((".ts", ".js", ".tsx", ".jsx"))
                
                if not (is_css or is_shell_ts):
                    continue
                    
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                
                if file.endswith((".ts", ".js", ".tsx", ".jsx", ".css", ".scss")):
                    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                
                lines = content.splitlines()
                for idx, line in enumerate(lines, 1):
                    # Strip comments to prevent false positives in docstrings or comments
                    clean_line = line
                    if file.endswith((".ts", ".js", ".tsx", ".jsx", ".css", ".scss")):
                        clean_line = re.sub(r'//.*', '', clean_line)
                    
                    # Audit Hex Colors
                    color_matches = [m.group(0) for m in hex_color_regex.finditer(clean_line)]
                    if color_matches:
                        for match in color_matches:
                            violations.append(f"{file}:{idx} - Hardcoded color hex '{match}' in line: {line.strip()}")
                            
                    # Audit Pixel Sizes
                    px_matches = hardcoded_px_regex.findall(clean_line)
                    if px_matches:
                        for match in px_matches:
                            violations.append(f"{file}:{idx} - Hardcoded pixel size '{match}px' in line: {line.strip()}")
                            
        if violations:
            print("\n--- Theme Conformity Violations Found ---")
            for violation in violations:
                print(violation)
            self.fail(f"Theme conformity audit failed: {len(violations)} violations found in shell files or stylesheets.")

if __name__ == "__main__":
    unittest.main()
