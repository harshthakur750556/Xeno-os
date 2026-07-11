declare var require: any;

import { Variable, GLib } from "astal";
import { theme } from "./theme";

// Types
export interface Notification {
  id: number;
  title: string;
  body: string;
  urgency: string;
  sound: string;
  timeout: number;
}

export interface Application {
  id: string;
  name: string;
  exec: string;
  icon: string;
}

// Fallback applications from .cursorrules
export const standardApps: Application[] = [
  { id: "math", name: "Math Solver", exec: "python3 ${WS_DIR}/desktop/panels/math_panel.py", icon: "accessories-calculator" },
  { id: "data", name: "Data Analysis", exec: "python3 ${WS_DIR}/desktop/panels/data_panel.py", icon: "office-chart" },
  { id: "code", name: "Code Notebook", exec: "python3 ${WS_DIR}/desktop/panels/code_panel.py", icon: "accessories-text-editor" },
  { id: "threed", name: "3D Viewer", exec: "python3 ${WS_DIR}/desktop/panels/threed_panel.py", icon: "image-viewer" },
  { id: "signal", name: "Signal Analysis", exec: "python3 ${WS_DIR}/desktop/panels/signal_panel.py", icon: "media-record" },
  { id: "terminal", name: "Terminal", exec: "kitty", icon: "utilities-terminal" },
  { id: "settings", name: "Settings", exec: "python3 ${WS_DIR}/desktop/settings.py", icon: "preferences-system" }
];

// Live State Variables
export const clockTime = new Variable<string>("");
export const cpuUsage = new Variable<number>(0);
export const ramUsage = new Variable<{ used: number, total: number, percent: number }>({ used: 0, total: 16, percent: 0 });
export const workspacesList = new Variable<{ id: number, active: boolean }[]>([]);
export const launcherVisible = new Variable<boolean>(false);
export const highlightedIndex = new Variable<number>(0);
export const launcherFontFamily = new Variable<string>(theme.fontPrimary);
export const launcherFontSize = new Variable<number>(theme.sizeBase);
export const notificationQueue = new Variable<Notification[]>([]);
export const notificationLogs = new Variable<string[]>([]);
export const soundPlayed = new Variable<string[]>([]);
export const sandboxRunning = new Variable<boolean>(false);
export const sandboxMemoryLimit = new Variable<string>("2GB");
export const sandboxThreads = new Variable<number>(2);
export const sandboxPanels = new Variable<string[]>([]);
export const displaySocketExists = new Variable<boolean>(true);

// Overrides
let clockOverridden = false;
let cpuOverridden = false;
let ramOverridden = false;
let workspacesOverridden = false;

// 1. Clock Updates
export function initClock() {
  const updateClock = () => {
    if (!clockOverridden) {
      const now = new Date();
      clockTime.set(formatDateTime(now));
    }
  };
  updateClock();
  setInterval(updateClock, 1000);
}

function formatDateTime(date: Date): string {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const min = String(date.getMinutes()).padStart(2, '0');
  const sec = String(date.getSeconds()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd} ${hh}:${min}:${sec}`;
}

// 2. Telemetry (CPU & RAM) Updates
let prevIdle = 0;
let prevTotal = 0;

export function initTelemetry() {
  const updateTelemetry = () => {
    if (!cpuOverridden) {
      cpuUsage.set(calculateCpuUsage());
    }
    if (!ramOverridden) {
      ramUsage.set(calculateRamUsage());
    }
  };
  updateTelemetry();
  setInterval(updateTelemetry, 2000);
}

function calculateCpuUsage(): number {
  try {
    const [ok, content] = GLib.file_get_contents("/proc/stat");
    if (!ok) return 0;
    const lines = content.toString().split("\n");
    const cpuLine = lines.find((line: string) => line.startsWith("cpu "));
    if (!cpuLine) return 0;
    const parts = cpuLine.trim().split(/\s+/).slice(1).map(Number);
    if (parts.length < 4) return 0;
    const idle = parts[3] + (parts[4] || 0);
    const total = parts.reduce((a: number, b: number) => a + b, 0);
    const idleDiff = idle - prevIdle;
    const totalDiff = total - prevTotal;
    prevIdle = idle;
    prevTotal = total;
    if (totalDiff === 0) return 0;
    const val = Math.round((1 - idleDiff / totalDiff) * 100);
    return Math.max(0, Math.min(100, val));
  } catch (e) {
    return 0;
  }
}

function calculateRamUsage(): { used: number, total: number, percent: number } {
  try {
    const [ok, content] = GLib.file_get_contents("/proc/meminfo");
    if (!ok) return { used: 0, total: 16, percent: 0 };
    const lines = content.toString().split("\n");
    let memTotal = 0;
    let memAvailable = 0;
    for (const line of lines) {
      if (line.startsWith("MemTotal:")) {
        memTotal = parseInt(line.replace(/\D/g, ""), 10);
      } else if (line.startsWith("MemAvailable:")) {
        memAvailable = parseInt(line.replace(/\D/g, ""), 10);
      }
    }
    if (memTotal === 0) return { used: 0, total: 16, percent: 0 };
    const totalGB = Math.round((memTotal / (1024 * 1024)) * 10) / 10;
    const usedGB = Math.round(((memTotal - memAvailable) / (1024 * 1024)) * 10) / 10;
    const percent = Math.round((usedGB / totalGB) * 100);
    return { used: usedGB, total: totalGB, percent };
  } catch (e) {
    return { used: 0, total: 16, percent: 0 };
  }
}

// 3. Workspaces
export function initWorkspaces() {
  let hyprland: any = null;
  try {
    const Hypr = require("gi://AstalHyprland");
    hyprland = Hypr.default.get_default();
  } catch (e) {
    // Handled fallback silently
  }
  
  const update = () => {
    if (workspacesOverridden) return;
    try {
      if (!hyprland) throw new Error("No Hyprland");
      const ws = hyprland.get_workspaces() || [];
      const activeWs = hyprland.get_focused_workspace();
      const activeId = activeWs ? activeWs.get_id() : 1;
      
      const list = ws.map((w: any) => ({
        id: w.get_id(),
        active: w.get_id() === activeId
      })).sort((a: any, b: any) => a.id - b.id);
      
      if (list.length === 0) {
        workspacesList.set([
          { id: 1, active: true },
          { id: 2, active: false },
          { id: 3, active: false },
          { id: 4, active: false }
        ]);
      } else {
        workspacesList.set(list);
      }
    } catch (err) {
      workspacesList.set([
        { id: 1, active: true },
        { id: 2, active: false },
        { id: 3, active: false },
        { id: 4, active: false }
      ]);
    }
  };
  
  update();
  if (hyprland) {
    try {
      hyprland.connect("notify::workspaces", update);
      hyprland.connect("notify::focused-workspace", update);
    } catch (e) {}
  }
}

let notificationCounter = 0;

export function handleIPCRequest(request: any): any {
  const cmd = request.command;
  const params = request.params || {};
  
  switch (cmd) {
    // Simulator Controls
    case "simulator:set_clock":
      clockOverridden = true;
      clockTime.set(params.time);
      return { status: "success" };
      
    case "simulator:set_cpu":
      cpuOverridden = true;
      cpuUsage.set(params.cpu);
      return { status: "success" };
      
    case "simulator:set_ram":
      ramOverridden = true;
      ramUsage.set(params.ram);
      return { status: "success" };
      
    case "simulator:set_workspaces":
      workspacesOverridden = true;
      const activeId = params.active;
      const ids = params.workspaces || [];
      workspacesList.set(ids.map((id: number) => ({ id, active: id === activeId })));
      return { status: "success" };
      
    case "simulator:set_display_socket":
      displaySocketExists.set(params.display_socket_exists);
      return { status: "success" };
      
    case "simulator:get_sound_played":
      return { status: "success", sound_played: soundPlayed.get() };
      
    case "simulator:clear_state":
      clockOverridden = false;
      cpuOverridden = false;
      ramOverridden = false;
      workspacesOverridden = false;
      launcherVisible.set(false);
      highlightedIndex.set(0);
      launcherFontFamily.set(theme.fontPrimary);
      launcherFontSize.set(theme.sizeBase);
      notificationQueue.set([]);
      notificationLogs.set([]);
      soundPlayed.set([]);
      sandboxRunning.set(false);
      sandboxMemoryLimit.set("2GB");
      sandboxThreads.set(2);
      sandboxPanels.set([]);
      displaySocketExists.set(true);
      return { status: "success" };
      
    // F1: Status Bar APIs
    case "status_bar:get_clock":
      return { status: "success", clock: clockTime.get() };
      
    case "status_bar:get_cpu":
      let cpu = cpuUsage.get();
      cpu = Math.max(0, Math.min(100, cpu));
      return { status: "success", cpu };
      
    case "status_bar:get_ram":
      return { status: "success", ram: ramUsage.get() };
      
    case "status_bar:get_workspaces":
      const ws = workspacesList.get();
      const idsList = ws.map(w => w.id);
      const activeObj = ws.find(w => w.active);
      return { status: "success", workspaces: idsList, active: activeObj ? activeObj.id : 1 };
      
    case "status_bar:toggle_launcher":
      launcherVisible.set(!launcherVisible.get());
      return { status: "success", launcher_visible: launcherVisible.get() };
      
    // F2: Launcher APIs
    case "launcher:list_apps":
      return { status: "success", apps: getResolvedApps() };
      
    case "launcher:launch":
      const appId = params.app_id;
      const app = getResolvedApps().find(a => a.id === appId);
      if (!app) {
        notificationLogs.set([...notificationLogs.get(), `ERROR: Launcher failed to launch non-existent application: ${appId}`]);
        return { status: "error", message: `Application ${appId} not found` };
      }
      
      GLib.spawn_command_line_async(app.exec);
      
      notificationCounter++;
      const newNotif = {
        id: notificationCounter,
        title: "System Launch",
        body: `Launching ${app.name} inside container...`,
        urgency: "low",
        sound: "launch_hook.wav",
        timeout: 3000
      };
      notificationQueue.set([...notificationQueue.get(), newNotif]);
      notificationLogs.set([...notificationLogs.get(), `INFO: ${newNotif.title} - ${newNotif.body}`]);
      soundPlayed.set([...soundPlayed.get(), newNotif.sound]);
      
      setTimeout(() => {
        notificationQueue.set(notificationQueue.get().filter(n => n.id !== newNotif.id));
      }, 3000);
      
      return { status: "success", launched: appId };
      
    case "launcher:get_state":
      return {
        status: "success",
        highlighted_index: highlightedIndex.get(),
        font_family: launcherFontFamily.get(),
        font_size: launcherFontSize.get(),
        visible: launcherVisible.get()
      };
      
    case "launcher:press_shortcut":
      launcherVisible.set(!launcherVisible.get());
      return { status: "success", launcher_visible: launcherVisible.get() };
      
    // F3: Notification APIs
    case "notification:send":
      const notifTitle = params.title || "";
      const notifBody = params.body || "";
      const urgency = params.urgency || "normal";
      const sound = params.sound || "";
      const timeout = typeof params.timeout === "number" ? params.timeout : 3000;
      
      if (!notifTitle && !notifBody) {
        return { status: "error", message: "Notification title and body cannot both be empty" };
      }
      
      notificationCounter++;
      const id = notificationCounter;
      const notifItem: Notification = { id, title: notifTitle, body: notifBody, urgency, sound, timeout };
      
      notificationQueue.set([...notificationQueue.get(), notifItem]);
      notificationLogs.set([...notificationLogs.get(), `${urgency.toUpperCase()}: ${notifTitle} - ${notifBody}`]);
      
      if (sound) {
        soundPlayed.set([...soundPlayed.get(), sound]);
      }
      
      if (timeout > 0) {
        setTimeout(() => {
          notificationQueue.set(notificationQueue.get().filter(n => n.id !== id));
        }, timeout);
      }
      
      return { status: "success", id };
      
    case "notification:get_queue":
      return { status: "success", notifications: notificationQueue.get() };
      
    case "notification:get_logs":
      return { status: "success", logs: notificationLogs.get() };
      
    case "notification:dismiss":
      const dismissId = params.id;
      notificationQueue.set(notificationQueue.get().filter(n => n.id !== dismissId));
      return { status: "success" };
      
    // F4: Sandbox APIs
    case "sandbox:start":
      const mem = params.memory || "2GB";
      const threads = params.threads || 2;
      
      if (!displaySocketExists.get()) {
        return { status: "error", message: "No Wayland or X11 graphics driver/display socket found" };
      }
      if (sandboxRunning.get()) {
        return { status: "error", message: "Instance lock active: concurrent sandbox wrapper spawn collision" };
      }
      
      if (mem.includes("MB")) {
        const mbVal = parseInt(mem.replace("MB", ""), 10);
        if (mbVal < 128) {
          return { status: "error", message: "Resource limits violated: memory allocation below 128MB threshold" };
        }
      }
      
      if (threads > 4) {
        return { status: "error", message: "Resource limits violated: native thread allocation limit exceeded" };
      }
      
      sandboxRunning.set(true);
      sandboxMemoryLimit.set(mem);
      sandboxThreads.set(threads);
      return { status: "success" };
      
    case "sandbox:stop":
      sandboxRunning.set(false);
      sandboxPanels.set([]);
      return { status: "success" };
      
    case "sandbox:status":
      return {
        status: "success",
        running: sandboxRunning.get(),
        memory_limit: sandboxMemoryLimit.get(),
        threads: sandboxThreads.get(),
        max_threads: 4,
        panels: sandboxPanels.get()
      };
      
    case "sandbox:load_panel":
      const panel = params.panel;
      if (!sandboxRunning.get()) {
        return { status: "error", message: "Cannot load panel: sandbox is not active" };
      }
      sandboxPanels.set([...sandboxPanels.get(), panel]);
      return { status: "success", panels: sandboxPanels.get() };
      
    default:
      return { status: "error", message: `Unknown IPC command: ${cmd}` };
  }
}

function getResolvedApps(): Application[] {
  const wsDir = process.env.WS_DIR || "/home/xeno/Xeno-os";
  return standardApps.map(app => ({
    ...app,
    exec: app.exec.replace("${WS_DIR}", wsDir)
  }));
}
