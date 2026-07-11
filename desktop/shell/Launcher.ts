declare var process: any;

import { Gtk, Astal } from "astal/gtk3";
import { bind, Variable } from "astal";
import { launcherVisible, standardApps, highlightedIndex, handleIPCRequest } from "./state";

export default function Launcher() {
  const filterText = new Variable<string>("");
  const appsGrid = new Gtk.Box({ className: "apps-grid" });

  const wsDir = process.env.WS_DIR || "/home/xeno/Xeno-os";
  const resolvedApps = standardApps.map(app => ({
    ...app,
    exec: app.exec.replace("${WS_DIR}", wsDir)
  }));

  const rebuildGrid = () => {
    const filter = filterText.get().toLowerCase();
    const list = resolvedApps.filter(app => 
      app.name.toLowerCase().includes(filter) || app.id.toLowerCase().includes(filter)
    );
    
    appsGrid.children = [];
    
    list.forEach((app, idx) => {
      const isHighlighted = highlightedIndex.get() === idx;
      const btn = new Gtk.Button({
        className: isHighlighted ? "launcher-app-btn highlighted" : "launcher-app-btn",
        label: `${app.name} (${app.icon})`,
        onClicked: () => {
          handleIPCRequest({ command: "launcher:launch", params: { app_id: app.id } });
          launcherVisible.set(false);
        }
      });
      appsGrid.add(btn);
    });
  };

  filterText.observe(rebuildGrid);
  highlightedIndex.observe(rebuildGrid);

  const container = new Gtk.Box({ className: "launcher-container", vertical: true });
  
  const searchEntry = new Gtk.Entry({
    className: "launcher-search",
    placeholderText: "Search...",
    onChanged: (self: any) => filterText.set(self.text || "")
  });

  container.add(searchEntry);
  container.add(appsGrid);

  const win = new Astal.Window({
    name: "launcher",
    className: "launcher-window",
    visible: bind(launcherVisible)
  });
  win.add(container);
  return win;
}
