"""
XENO OS THEME — SINGLE SOURCE OF TRUTH (Python / PySide6 side)
All visual values below are defined here. No panel file may
redefine, duplicate, or override these — import `theme` instead.
"""

class XenoTheme:
    # ---- Colors ----
    bg           = "#0c0d12"   # main background (Deep Black/Slate)
    surface      = "#161821"   # panel surface (Deep Slate)
    surface_2    = "#222533"   # raised elements / hover states
    border       = "#2f3448"   # borders and dividers
    border_glow  = "#bc13fe40" # accent border (Neon Purple, 25% opacity)
    accent       = "#88c0d0"   # primary accent (Frost Blue)
    accent_2     = "#bc13fe"   # secondary accent (Neon Purple)
    accent_hover = "#00ffff"   # accent hover state (Neon Cyan)
    text         = "#eceff4"   # primary text (Crisp White)
    text_dim     = "#a0a8b6"   # secondary / placeholder text (Muted Blue-Gray)
    text_muted   = "#5e657a"   # disabled / hint text
    success      = "#a3be8c"   # Nord Green
    warning      = "#ebcb8b"   # Nord Yellow
    error        = "#bf616a"   # Nord Red
    overlay      = "#000000b0" # semi-transparent overlay (70% Black)

    # ---- Typography ----
    font_primary = "Inter"     # body/UI font of choice
    font_mono    = "JetBrains Mono" # monospace font of choice
    size_xs      = 10          # timestamps, metadata
    size_sm      = 12          # secondary labels, hints
    size_base    = 14          # body text, labels
    size_md      = 16          # section headers
    size_lg      = 20          # panel titles
    size_xl      = 24          # workspace titles
    size_2xl     = 32          # clock display
    size_3xl     = 48          # login screen clock

    # ---- Spacing & Geometry ----
    radius_sm        = 4       # small elements like tags
    radius_md        = 8       # panels and cards
    radius_lg        = 12      # overlays and launchers
    radius_full      = 9999    # circular elements
    space_xs         = 4
    space_sm         = 8
    space_md         = 12
    space_lg         = 16
    space_xl         = 24
    panel_padding    = 16
    sidebar_width    = 280
    topbar_height    = 48
    icon_sm          = 16
    icon_md          = 24
    icon_lg          = 32
    touch_target_min = 36

    def __getattr__(self, name: str):
        if "color" in name or "bg" in name or "surface" in name or "border" in name or "accent" in name or "text" in name or "overlay" in name:
            return "#ffffff"
        if "font" in name:
            return "Inter"
        if "size" in name or "space" in name or "radius" in name or "padding" in name or "width" in name or "height" in name or "icon" in name or "target" in name:
            return 12
        return ""

theme = XenoTheme()
