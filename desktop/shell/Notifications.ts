import { Gtk, Astal } from "astal/gtk3";
import { bind } from "astal";
import { notificationQueue, handleIPCRequest } from "./state";

export function startNotificationServer() {
  try {
    Bun.serve({
      port: 5050,
      async fetch(req: any) {
        if (req.method === "POST") {
          try {
            const json = await req.json();
            const res = handleIPCRequest({
              command: "notification:send",
              params: {
                title: json.title || "",
                body: json.body || "",
                urgency: json.urgency || "normal",
                sound: json.sound || "",
                timeout: typeof json.timeout === "number" ? json.timeout : 3000
              }
            });
            return new Response(JSON.stringify(res), {
              headers: { "Content-Type": "application/json" }
            });
          } catch (e) {
            return new Response(JSON.stringify({ status: "error", message: String(e) }), {
              status: 400,
              headers: { "Content-Type": "application/json" }
            });
          }
        }
        return new Response("Not Found", { status: 404 });
      }
    });
    console.log("Notifications HTTP server listening on port 5050");
  } catch (e) {
    console.error("Failed to start Bun notification server:", e);
  }
}

export default function Notifications() {
  const container = new Gtk.Box({ className: "notifications-container", vertical: true });

  notificationQueue.observe(queue => {
    container.children = [];
    
    for (const notif of queue) {
      const toast = new Gtk.Box({ className: "notification-toast", vertical: true });
      
      const titleLabel = new Gtk.Label({ className: "notification-title", label: notif.title });
      const bodyLabel = new Gtk.Label({ className: "notification-body", label: notif.body });
      const dismissBtn = new Gtk.Button({
        className: "notification-dismiss-btn",
        label: "Dismiss",
        onClicked: () => {
          handleIPCRequest({ command: "notification:dismiss", params: { id: notif.id } });
        }
      });
      
      toast.add(titleLabel);
      toast.add(bodyLabel);
      toast.add(dismissBtn);
      
      container.add(toast);
    }
  });

  const hasItems = notificationQueue.as(q => q.length > 0);

  const revealer = new Gtk.Revealer({
    revealChild: bind(hasItems),
    transitionType: 1,
    transitionDuration: 300
  });
  revealer.add(container);

  const win = new Astal.Window({
    name: "notifications",
    className: "notification-window",
    visible: true
  });
  win.add(revealer);
  return win;
}
