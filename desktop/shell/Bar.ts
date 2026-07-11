import { Gtk, Astal } from "astal/gtk3";
import { bind } from "astal";
import { clockTime, cpuUsage, ramUsage, workspacesList, launcherVisible } from "./state";

export default function Bar() {
  const workspacesBox = new Gtk.Box({ className: "workspaces-box" });
  workspacesList.observe(list => {
    workspacesBox.children = [];
    for (const ws of list) {
      const btn = new Gtk.Button({
        className: ws.active ? "workspace-btn active" : "workspace-btn",
        label: String(ws.id)
      });
      workspacesBox.add(btn);
    }
  });

  const box = new Gtk.Box({ className: "bar-container", halign: 0, valign: 1 });
  
  const toggleBtn = new Gtk.Button({
    className: "launcher-toggle-btn",
    label: "Launcher",
    onClicked: () => {
      launcherVisible.set(!launcherVisible.get());
    }
  });
  
  const clockLabel = new Gtk.Label({
    className: "bar-clock",
    label: bind(clockTime)
  });
  
  const cpuLabel = new Gtk.Label({
    className: "bar-cpu",
    label: bind(cpuUsage).as((cpu: number) => `CPU: ${cpu}%`)
  });
  
  const ramLabel = new Gtk.Label({
    className: "bar-ram",
    label: bind(ramUsage).as((ram: any) => `RAM: ${ram.used}GB / ${ram.total}GB (${ram.percent}%)`)
  });

  box.add(toggleBtn);
  box.add(workspacesBox);
  box.add(clockLabel);
  box.add(cpuLabel);
  box.add(ramLabel);

  const win = new Astal.Window({
    name: "bar",
    className: "bar-window",
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT,
    exclusivity: Astal.Exclusivity.EXCLUSIVE,
    visible: true
  });
  win.add(box);
  return win;
}
