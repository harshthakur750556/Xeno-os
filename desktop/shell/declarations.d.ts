declare module "gi://AstalHyprland" {
  const Hyprland: any;
  export default Hyprland;
}

declare module "gi://AstalNetwork" {
  const Network: any;
  export default Network;
}

declare module "gi://AstalBattery" {
  const Battery: any;
  export default Battery;
}

declare module "gi://AstalWp" {
  const Wp: any;
  export default Wp;
}

declare namespace JSX {
  interface IntrinsicElements {
    [elemName: string]: any;
  }
}

declare var Bun: any;
declare var process: any;
declare var require: any;

declare module "fs" {
  export function writeFileSync(path: string, content: string): void;
  export function existsSync(path: string): boolean;
  export function unlinkSync(path: string): void;
}
