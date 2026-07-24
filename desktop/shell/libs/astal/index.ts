declare var require: any;

import { GtkWidget } from "@astal/gtk3";

export class Variable<T> {
  private value: T;
  private listeners: ((value: T) => void)[] = [];
  
  constructor(value: T) {
    this.value = value;
  }
  
  get(): T {
    return this.value;
  }
  
  set(value: T): void {
    if (this.value !== value) {
      this.value = value;
      for (const listener of this.listeners) {
        listener(value);
      }
    }
  }
  
  observe(callback: (value: T) => void): () => void {
    this.listeners.push(callback);
    callback(this.value);
    return () => {
      this.listeners = this.listeners.filter(l => l !== callback);
    };
  }

  as<R>(fn: (val: T) => R): Variable<R> {
    const derived = new Variable<R>(fn(this.value));
    this.observe(val => {
      derived.set(fn(val));
    });
    return derived;
  }
}

export const GLib: any = {
  file_get_contents(path: string) {
    try {
      const fs = require("fs");
      if (!fs.existsSync(path)) {
        return [false, ""];
      }
      const content = fs.readFileSync(path, "utf8");
      return [true, content];
    } catch (e) {
      return [false, ""];
    }
  },
  shell_quote(str: string): string {
    if (!str) return "''";
    if (str.includes(" ")) {
      return str.split(/\s+/).map(s => "'" + s.replace(/'/g, "'\\''") + "'").join(" ");
    }
    return "'" + str.replace(/'/g, "'\\''") + "'";
  },
  spawn_command_line_async(cmd: string) {
    try {
      const { spawn } = require("child_process");
      spawn(cmd, { shell: true, detached: true, stdio: "ignore" }).unref();
      return true;
    } catch (e) {
      return false;
    }
  }
};

export function bind(obj: any, prop?: string): any {
  if (obj instanceof Variable) {
    return obj;
  }
  return obj;
}

export const JSX = {
  createElement(tag: any, props: any, ...children: any[]) {
    let widget: any;
    if (typeof tag === "function") {
      widget = new tag(props);
    } else {
      const { Gtk } = require("@astal/gtk3");
      const mapping: any = {
        window: Gtk.Window,
        box: Gtk.Box,
        label: Gtk.Label,
        button: Gtk.Button,
        entry: Gtk.Entry,
        revealer: Gtk.Revealer
      };
      const Cls = mapping[tag] || GtkWidget;
      widget = new Cls(props);
    }
    
    if (children && children.length > 0) {
      for (const child of children) {
        if (child instanceof GtkWidget) {
          widget.add(child);
        } else if (Array.isArray(child)) {
          for (const c of child) {
            if (c instanceof GtkWidget) {
              widget.add(c);
            }
          }
        }
      }
    }
    
    return widget;
  }
};
