declare var require: any;
declare var process: any;

import { App } from "astal/gtk3";
import Bar from "./Bar";
import Launcher from "./Launcher";
import Notifications, { startNotificationServer } from "./Notifications";
import { initClock, initTelemetry, initWorkspaces, handleIPCRequest } from "./state";
import { theme } from "./theme";
import * as fs from "fs";

console.log("Initializing Xeno OS Desktop Shell...");
console.log("Accent theme color:", theme.accent);

// 1. Generate CSS stylesheet dynamically based on theme.ts values
function buildAndWriteCSS() {
  const css = `
* {
  font-family: "${theme.fontPrimary}", sans-serif;
  font-size: ${theme.sizeBase}px;
}

.mono {
  font-family: "${theme.fontMono}", monospace;
}

window {
  background-color: transparent;
}

.bar-window {
  background-color: ${theme.bg};
  border-bottom: 1px solid ${theme.border};
}

.bar-container {
  padding: 0 ${theme.panelPadding}px;
  height: ${theme.topbarHeight}px;
}

.bar-clock, .bar-cpu, .bar-ram, .workspace-btn, .launcher-toggle-btn {
  color: ${theme.text};
  background-color: ${theme.surface};
  border: 1px solid ${theme.border};
  border-radius: ${theme.radiusSm}px;
  padding: ${theme.spaceXs}px ${theme.spaceSm}px;
  margin: 0 ${theme.spaceXs}px;
}

.bar-clock:hover, .bar-cpu:hover, .bar-ram:hover, .workspace-btn:hover, .launcher-toggle-btn:hover {
  background-color: ${theme.surface2};
  border-color: ${theme.accent2};
}

.workspace-btn.active {
  background-color: ${theme.accent2};
  border-color: ${theme.accentHover};
  color: ${theme.text};
}

.launcher-window {
  background-color: ${theme.overlay};
}

.launcher-container {
  background-color: ${theme.bg};
  border: 1px solid ${theme.border};
  border-radius: ${theme.radiusLg}px;
  padding: ${theme.panelPadding}px;
}

.launcher-search {
  background-color: ${theme.surface};
  color: ${theme.text};
  border: 1px solid ${theme.border};
  border-radius: ${theme.radiusMd}px;
  padding: ${theme.spaceSm}px;
  margin-bottom: ${theme.spaceMd}px;
}

.launcher-search:focus {
  border-color: ${theme.accentHover};
}

.launcher-app-btn {
  background-color: ${theme.surface};
  border: 1px solid ${theme.border};
  border-radius: ${theme.radiusMd}px;
  padding: ${theme.panelPadding}px;
  color: ${theme.textDim};
}

.launcher-app-btn:hover {
  background-color: ${theme.surface2};
  border-color: ${theme.accentHover};
  color: ${theme.text};
}

.launcher-app-btn.highlighted {
  background-color: ${theme.surface2};
  border-color: ${theme.accent2};
  color: ${theme.text};
}

.notification-window {
  background-color: transparent;
}

.notification-toast {
  background-color: ${theme.bg};
  border: 2px solid ${theme.accent2};
  border-radius: ${theme.radiusMd}px;
  padding: ${theme.panelPadding}px;
  margin: ${theme.spaceSm}px;
}

.notification-title {
  font-weight: bold;
  color: ${theme.text};
  font-size: ${theme.sizeMd}px;
}

.notification-body {
  color: ${theme.textDim};
  font-size: ${theme.sizeSm}px;
}
  `;
  
  fs.writeFileSync("/tmp/neonic-shell.css", css.trim());
  console.log("Dynamically constructed CSS stylesheet written to /tmp/neonic-shell.css");
}

// Global Error Boundary (S3)
if (typeof process !== "undefined") {
  process.on("uncaughtException", (err: any) => {
    console.error("[Shell Error Boundary] Uncaught Exception:", err);
  });
  process.on("unhandledRejection", (reason: any) => {
    console.error("[Shell Error Boundary] Unhandled Rejection:", reason);
  });

  const cleanupSocket = () => {
    const socketPath = process.env.XENO_IPC_SOCKET || "/tmp/xeno-ipc.sock";
    try {
      if (fs.existsSync(socketPath)) {
        fs.unlinkSync(socketPath);
      }
    } catch (e) {
      // Clean exit
    }
  };

  process.on("SIGINT", () => {
    cleanupSocket();
    process.exit(0);
  });
  process.on("SIGTERM", () => {
    cleanupSocket();
    process.exit(0);
  });
  process.on("exit", cleanupSocket);
}

// 2. Start UNIX domain socket IPC server
function startIPCServer() {
  const socketPath = process.env.XENO_IPC_SOCKET || "/tmp/xeno-ipc.sock";
  
  try {
    if (fs.existsSync(socketPath)) {
      fs.unlinkSync(socketPath);
    }
  } catch (e) {
    console.warn("Failed to clean up socket path:", e);
  }
  
  try {
    Bun.listen({
      socket: {
        open(socket: any) {
          // Strict IPC Socket Peer UID Verification
          try {
            if (typeof socket.getPeerCredentials === "function") {
              const creds = socket.getPeerCredentials();
              if (creds && typeof creds.uid === "number" && typeof process.getuid === "function") {
                const currentUid = process.getuid();
                if (creds.uid !== currentUid && creds.uid !== 0) {
                  console.warn(`[IPC Security] Rejected connection from unauthorized peer UID: ${creds.uid}`);
                  socket.end();
                  return;
                }
              }
            }
          } catch (err) {
            console.warn("[IPC Security] Peer verification warning:", err);
          }
        },
        data(socket: any, data: any) {
          try {
            if (typeof socket.getPeerCredentials === "function") {
              const creds = socket.getPeerCredentials();
              if (creds && typeof creds.uid === "number" && typeof process.getuid === "function") {
                const currentUid = process.getuid();
                if (creds.uid !== currentUid && creds.uid !== 0) {
                  socket.write(JSON.stringify({ status: "error", message: "Unauthorized socket peer UID" }));
                  socket.end();
                  return;
                }
              }
            }
            const reqStr = (data ? data.toString("utf-8") : "").trim();
            if (!reqStr) {
              socket.write(JSON.stringify({ status: "error", message: "Empty IPC payload" }));
              socket.end();
              return;
            }
            let request: any;
            try {
              request = JSON.parse(reqStr);
            } catch (jsonErr: any) {
              socket.write(JSON.stringify({ status: "error", message: `Malformed JSON payload: ${jsonErr.message || String(jsonErr)}` }));
              socket.end();
              return;
            }
            const response = handleIPCRequest(request);
            socket.write(JSON.stringify(response));
          } catch (e: any) {
            try {
              socket.write(JSON.stringify({ status: "error", message: `IPC handling failure: ${e.message || String(e)}` }));
            } catch (_) {}
          } finally {
            try {
              socket.end();
            } catch (_) {}
          }
        }
      },
      unix: socketPath
    });
    // Enforce strict socket file permissions (0700)
    fs.chmodSync(socketPath, 0o700);
    console.log(`IPC server listening on unix socket: ${socketPath} with permissions 0700`);
  } catch (e) {
    console.error("Failed to start IPC server:", e);
  }
}

// Startup Initialization
buildAndWriteCSS();
initClock();
initTelemetry();
initWorkspaces();
startNotificationServer();
startIPCServer();

// Start Astal Application
try {
  App.start({
    instanceName: "neonic-shell",
    css: "/tmp/neonic-shell.css",
    main() {
      Bar();
      Launcher();
      Notifications();
    }
  });
} catch (e) {
  console.error("[App.start Error]", e);
}
