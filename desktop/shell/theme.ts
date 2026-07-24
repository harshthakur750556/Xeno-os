// XENO OS THEME — mirrors theme.py token names for the Astal/TypeScript side.
// Keep every key here in sync with desktop/theme.py.

export const theme = {
  bg: "#0c0d12",
  surface: "#161821",
  surface2: "#222533",
  border: "#2f3448",
  borderGlow: "#bc13fe40",
  accent: "#88c0d0",
  accent2: "#bc13fe",
  accentHover: "#00ffff",
  text: "#eceff4",
  textDim: "#a0a8b6",
  textMuted: "#5e657a",
  success: "#a3be8c",
  warning: "#ebcb8b",
  error: "#bf616a",
  overlay: "#000000b0",

  fontPrimary: "Inter",
  fontMono: "JetBrains Mono",
  sizeXs: 10,
  sizeSm: 12,
  sizeBase: 14,
  sizeMd: 16,
  sizeLg: 20,
  sizeXl: 24,
  size2xl: 32,
  size3xl: 48,

  radiusSm: 4,
  radiusMd: 8,
  radiusLg: 12,
  radiusFull: 9999,
  spaceXs: 4,
  spaceSm: 8,
  spaceMd: 12,
  spaceLg: 16,
  spaceXl: 24,
  panelPadding: 16,
  sidebarWidth: 280,
  topbarHeight: 48,
  iconSm: 16,
  iconMd: 24,
  iconLg: 32,
  touchTargetMin: 36,
};

export function validateColor(hex: string, fallback: string = "#ffffff"): string {
  if (typeof hex === "string" && /^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6,8})$/.test(hex)) {
    return hex;
  }
  return fallback;
}
