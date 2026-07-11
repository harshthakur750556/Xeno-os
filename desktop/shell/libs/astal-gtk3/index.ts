import { Variable } from "astal";

export const App: any = {
  cssPath: "",
  apply_css(path: string) {
    this.cssPath = path;
  },
  start(config: { instanceName?: string, css?: string, main: () => void }) {
    if (config.css) {
      this.apply_css(config.css);
    }
    config.main();
  }
};

export const Astal: any = {
  WindowAnchor: {
    TOP: 1,
    BOTTOM: 2,
    LEFT: 4,
    RIGHT: 8
  },
  Exclusivity: {
    EXCLUSIVE: 1,
    NORMAL: 0
  },
  Window: class extends GtkWidget {
    get visible(): boolean {
      return this.properties.visible instanceof Variable ? this.properties.visible.get() : this.properties.visible;
    }
  }
};

export const Gdk: any = {};

export class GtkWidget {
  public properties: any;
  public children: GtkWidget[] = [];
  
  constructor(properties?: any) {
    this.properties = properties || {};
  }
  
  add(child: GtkWidget) {
    this.children.push(child);
  }
}

export const Gtk: any = {
  Align: {
    FILL: 0,
    CENTER: 1,
    START: 2,
    END: 3
  },
  Box: class extends GtkWidget {},
  Label: class extends GtkWidget {
    get text(): string {
      return this.properties.label instanceof Variable ? this.properties.label.get() : this.properties.label;
    }
  },
  Button: class extends GtkWidget {
    get label(): string {
      return this.properties.label instanceof Variable ? this.properties.label.get() : this.properties.label;
    }
    click() {
      if (this.properties.onClicked) {
        this.properties.onClicked();
      }
    }
  },
  Window: class extends GtkWidget {
    get visible(): boolean {
      return this.properties.visible instanceof Variable ? this.properties.visible.get() : this.properties.visible;
    }
  },
  Entry: class extends GtkWidget {
    get text(): string {
      return this.properties.text instanceof Variable ? this.properties.text.get() : this.properties.text;
    }
  },
  Revealer: class extends GtkWidget {
    get revealChild(): boolean {
      return this.properties.revealChild instanceof Variable ? this.properties.revealChild.get() : this.properties.revealChild;
    }
  }
};
