import os
import sys
import json
import socket
import threading
import tempfile
import shutil
import time

class XenoSystemSimulator:
    def __init__(self):
        self.lock = threading.Lock()
        self.running = False
        self.server_thread = None
        self.socket_dir = None
        self.socket_path = None
        
        # Default State
        self.reset_state()

    def reset_state(self):
        with self.lock:
            # F1: Status Bar State
            self.clock_time = "2026-07-06 18:26:33"
            self.cpu_usage = 12.5
            self.ram_usage = {
                "used": 4.2,
                "total": 16.0,
                "percent": 26.3
            }
            self.workspaces = [1, 2, 3]
            self.active_workspace = 2
            
            # F2: Launcher State
            self.launcher_visible = False
            self.applications = [
                {"id": "terminal", "name": "Terminal", "command": "bash", "icon": "utilities-terminal"},
                {"id": "filemanager", "name": "File Manager", "command": "python3 filemanager.py", "icon": "system-file-manager"},
                {"id": "settings", "name": "Settings", "command": "python3 settings.py", "icon": "preferences-system"}
            ]
            self.launcher_highlighted_index = 0
            self.launcher_font_family = "Inter"
            self.launcher_font_size = 14
            
            # F3: Notification Center State
            self.notification_queue = []
            self.notification_logs = []
            self.notification_counter = 0
            self.sound_played = []
            
            # F4: Sandbox State
            self.sandbox_running = False
            self.sandbox_memory_limit = "2GB"
            self.sandbox_threads = 0
            self.sandbox_max_threads = 4
            self.sandbox_panels = []
            self.display_socket_exists = True
            
            # System Logs
            self.system_logs = []

    def log(self, message):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        self.system_logs.append(f"[{timestamp}] {message}")

    def start(self):
        self.reset_state()
        self.socket_dir = tempfile.mkdtemp(prefix="xeno_test_")
        self.socket_path = os.path.join(self.socket_dir, "xeno-ipc.sock")
        
        self.running = True
        self.server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server_socket.bind(self.socket_path)
        self.server_socket.listen(5)
        
        self.server_thread = threading.Thread(target=self._run_server, daemon=True)
        self.server_thread.start()
        self.log(f"Simulator started on Unix socket: {self.socket_path}")
        return self.socket_path

    def stop(self):
        self.running = False
        if hasattr(self, 'server_socket'):
            try:
                # Connect briefly to break the accept() loop
                temp_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                temp_sock.connect(self.socket_path)
                temp_sock.close()
            except Exception:
                pass
            try:
                self.server_socket.close()
            except Exception:
                pass
        
        if self.server_thread:
            self.server_thread.join(timeout=1.0)
            
        if self.socket_dir and os.path.exists(self.socket_dir):
            shutil.rmtree(self.socket_dir)
            
        self.log("Simulator stopped")

    def _run_server(self):
        while self.running:
            try:
                conn, _ = self.server_socket.accept()
                if not self.running:
                    conn.close()
                    break
                
                req_data = b""
                while True:
                    chunk = conn.recv(65536)
                    if not chunk:
                        break
                    req_data += chunk
                
                if not req_data:
                    conn.close()
                    continue
                
                try:
                    request = json.loads(req_data.decode('utf-8'))
                    response = self.handle_request(request)
                except Exception as e:
                    response = {"status": "error", "message": f"Malformed request: {str(e)}"}
                
                conn.sendall(json.dumps(response).encode('utf-8'))
                conn.close()
            except Exception:
                if not self.running:
                    break

    def handle_request(self, request):
        cmd = request.get("command")
        params = request.get("params", {})
        
        # Simulator internal controls
        if cmd == "simulator:set_clock":
            with self.lock:
                self.clock_time = params.get("time", self.clock_time)
            return {"status": "success"}
            
        elif cmd == "simulator:set_cpu":
            with self.lock:
                self.cpu_usage = params.get("cpu", self.cpu_usage)
            return {"status": "success"}
            
        elif cmd == "simulator:set_ram":
            with self.lock:
                self.ram_usage = params.get("ram", self.ram_usage)
            return {"status": "success"}
            
        elif cmd == "simulator:set_workspaces":
            with self.lock:
                self.workspaces = params.get("workspaces", self.workspaces)
                self.active_workspace = params.get("active", self.active_workspace)
            return {"status": "success"}
            
        elif cmd == "simulator:set_applications":
            with self.lock:
                self.applications = params.get("applications", self.applications)
            return {"status": "success"}
            
        elif cmd == "simulator:set_launcher_state":
            with self.lock:
                self.launcher_highlighted_index = params.get("highlighted_index", self.launcher_highlighted_index)
                self.launcher_font_family = params.get("font_family", self.launcher_font_family)
                self.launcher_font_size = params.get("font_size", self.launcher_font_size)
            return {"status": "success"}
            
        elif cmd == "simulator:set_display_socket":
            with self.lock:
                self.display_socket_exists = params.get("display_socket_exists", self.display_socket_exists)
            return {"status": "success"}
            
        elif cmd == "simulator:get_sound_played":
            with self.lock:
                return {"status": "success", "sound_played": list(self.sound_played)}
                
        elif cmd == "simulator:clear_state":
            self.reset_state()
            return {"status": "success"}

        # F1: Status Bar APIs
        elif cmd == "status_bar:get_clock":
            with self.lock:
                return {"status": "success", "clock": self.clock_time}
                
        elif cmd == "status_bar:get_cpu":
            with self.lock:
                clamped_cpu = max(0.0, min(100.0, self.cpu_usage))
                return {"status": "success", "cpu": clamped_cpu}
                
        elif cmd == "status_bar:get_ram":
            with self.lock:
                return {"status": "success", "ram": self.ram_usage}
                
        elif cmd == "status_bar:get_workspaces":
            with self.lock:
                return {"status": "success", "workspaces": self.workspaces, "active": self.active_workspace}
                
        elif cmd == "status_bar:toggle_launcher":
            with self.lock:
                self.launcher_visible = not self.launcher_visible
                self.log(f"Status Bar toggled Launcher. Visible: {self.launcher_visible}")
                return {"status": "success", "launcher_visible": self.launcher_visible}

        # F2: Launcher APIs
        elif cmd == "launcher:list_apps":
            with self.lock:
                return {"status": "success", "apps": self.applications}
                
        elif cmd == "launcher:launch":
            app_id = params.get("app_id")
            with self.lock:
                # Find application
                app = next((a for a in self.applications if a["id"] == app_id), None)
                if not app:
                    self.log(f"Launcher failed to launch non-existent application: {app_id}")
                    return {"status": "error", "message": f"Application {app_id} not found"}
                
                # Send a system notification log about launching
                self.notification_counter += 1
                new_id = self.notification_counter
                toast = {
                    "id": new_id,
                    "title": "System Launch",
                    "body": f"Launching {app['name']} inside container...",
                    "urgency": "low",
                    "sound": "launch_hook.wav"
                }
                self.notification_queue.append(toast)
                self.notification_logs.append(f"INFO: {toast['title']} - {toast['body']}")
                self.sound_played.append(toast["sound"])
                
                self.log(f"Launcher launched application: {app_id}")
                return {"status": "success", "launched": app_id}
                
        elif cmd == "launcher:get_state":
            with self.lock:
                return {
                    "status": "success",
                    "highlighted_index": self.launcher_highlighted_index,
                    "font_family": self.launcher_font_family,
                    "font_size": self.launcher_font_size,
                    "visible": self.launcher_visible
                }
                
        elif cmd == "launcher:press_shortcut":
            with self.lock:
                self.launcher_visible = not self.launcher_visible
                self.log(f"Launcher hotkey toggled. Visible: {self.launcher_visible}")
                return {"status": "success", "launcher_visible": self.launcher_visible}

        # F3: Notification APIs
        elif cmd == "notification:send":
            title = params.get("title", "")
            body = params.get("body", "")
            urgency = params.get("urgency", "normal")
            sound = params.get("sound", "")
            timeout = params.get("timeout", 3000)
            
            if not title and not body:
                self.log("Notification Center received null message notification")
                return {"status": "error", "message": "Notification title and body cannot both be empty"}
                
            with self.lock:
                self.notification_counter += 1
                new_id = self.notification_counter
                toast = {
                    "id": new_id,
                    "title": title,
                    "body": body,
                    "urgency": urgency,
                    "sound": sound,
                    "timeout": timeout
                }
                
                # Layout collision check if too many active notifications
                if len(self.notification_queue) >= 5:
                    self.log(f"Notification collision warning: {len(self.notification_queue)} active notifications")
                    
                self.notification_queue.append(toast)
                self.notification_logs.append(f"{urgency.upper()}: {title} - {body}")
                if sound:
                    self.sound_played.append(sound)
                    
                self.log(f"Notification dispatched: {title} (ID: {new_id})")
                return {"status": "success", "id": new_id}
                
        elif cmd == "notification:get_queue":
            with self.lock:
                return {"status": "success", "notifications": list(self.notification_queue)}
                
        elif cmd == "notification:get_logs":
            with self.lock:
                return {"status": "success", "logs": list(self.notification_logs)}
                
        elif cmd == "notification:dismiss":
            notif_id = params.get("id")
            with self.lock:
                self.notification_queue = [n for n in self.notification_queue if n["id"] != notif_id]
                self.log(f"Notification dismissed: ID {notif_id}")
                return {"status": "success"}

        # F4: Sandbox APIs
        elif cmd == "sandbox:start":
            mem = params.get("memory", "2GB")
            threads = params.get("threads", 2)
            
            with self.lock:
                if not self.display_socket_exists:
                    self.log("Sandbox execution failed: Missing display socket")
                    return {"status": "error", "message": "No Wayland or X11 graphics driver/display socket found"}
                    
                if self.sandbox_running:
                    self.log("Sandbox execution failed: Collision (already running)")
                    return {"status": "error", "message": "Instance lock active: concurrent sandbox wrapper spawn collision"}
                
                # Check memory limits
                if "MB" in mem:
                    m_val = int(mem.replace("MB", ""))
                    if m_val < 128:
                        self.log(f"Sandbox execution failed: memory limit {mem} below minimum threshold")
                        return {"status": "error", "message": "Resource limits violated: memory allocation below 128MB threshold"}
                
                # Thread allocation limit check
                if threads > self.sandbox_max_threads:
                    self.log(f"Sandbox execution failed: thread allocation {threads} exceeds limit {self.sandbox_max_threads}")
                    return {"status": "error", "message": "Resource limits violated: native thread allocation limit exceeded"}
                    
                self.sandbox_running = True
                self.sandbox_memory_limit = mem
                self.sandbox_threads = threads
                self.log(f"Sandbox started with {threads} threads, {mem} RAM limit")
                return {"status": "success"}
                
        elif cmd == "sandbox:stop":
            with self.lock:
                self.sandbox_running = False
                self.sandbox_panels = []
                self.log("Sandbox stopped and cleaned up")
                return {"status": "success"}
                
        elif cmd == "sandbox:status":
            with self.lock:
                return {
                    "status": "success",
                    "running": self.sandbox_running,
                    "memory_limit": self.sandbox_memory_limit,
                    "threads": self.sandbox_threads,
                    "max_threads": self.sandbox_max_threads,
                    "panels": list(self.sandbox_panels)
                }
                
        elif cmd == "sandbox:load_panel":
            panel = params.get("panel")
            with self.lock:
                if not self.sandbox_running:
                    self.log(f"Sandbox failed loading panel {panel}: Sandbox not running")
                    return {"status": "error", "message": "Cannot load panel: sandbox is not active"}
                self.sandbox_panels.append(panel)
                self.log(f"Sandbox loaded panel: {panel}")
                return {"status": "success", "panels": list(self.sandbox_panels)}

        else:
            return {"status": "error", "message": f"Unknown IPC command: {cmd}"}

if __name__ == "__main__":
    sim = XenoSystemSimulator()
    path = sim.start()
    print(f"Running simulation on {path}. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        sim.stop()
