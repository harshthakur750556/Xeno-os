import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from desktop.env import init_qt_environment
init_qt_environment()

# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QPushButton, QStackedWidget, QFrame, QButtonGroup, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os
import time

# Custom panels
from desktop.panels.math_panel import MathPanel
from desktop.panels.data_panel import DataPanel
from desktop.panels.code_panel import CodePanel
from desktop.panels.threed_panel import ThreeDPanel
from desktop.panels.signal_panel import SignalPanel


class SysMonitorWorker(QObject):
    """
    Background worker for asynchronous CPU and Memory load calculation.
    """
    stat_updated = Signal(dict)

    def __init__(self):
        super().__init__()
        self._running = True

    def run(self):
        last_idle = 0
        last_total = 0
        while self._running:
            try:
                # Calculate CPU utilization from /proc/stat
                with open("/proc/stat", "r") as f:
                    fields = f.readline().strip().split()
                vals = [float(x) for x in fields[1:8]]
                idle = vals[3] + vals[4]
                total = sum(vals)

                diff_idle = idle - last_idle
                diff_total = total - last_total
                cpu = 100.0 * (1.0 - diff_idle / diff_total) if diff_total > 0 else 0.0

                last_idle = idle
                last_total = total

                # Calculate memory utilization from /proc/meminfo
                mem_total = 0.0
                mem_avail = 0.0
                with open("/proc/meminfo", "r") as f:
                    for line in f:
                        if "MemTotal" in line:
                            mem_total = float(line.split()[1])
                        elif "MemAvailable" in line:
                            mem_avail = float(line.split()[1])
                ram = 100.0 * (1.0 - mem_avail / mem_total) if mem_total > 0 else 0.0

                self.stat_updated.emit({
                    "cpu": cpu,
                    "ram": ram
                })
            except Exception:
                pass
            time.sleep(2.0)

    def stop(self):
        self._running = False


WORKSPACE_STYLE = f"""
/* ═══════════════════════════════════════════════════════════════
   XENO OS — CYBERPUNK NEON WORKSPACE THEME
   ═══════════════════════════════════════════════════════════════ */

QWidget#WorkspaceRoot {{
    background-color: {theme.bg};
    font-family: "{theme.font_primary}", sans-serif;
    font-size: {theme.size_base}px;
    color: {theme.text};
}}

/* ── Sidebar ─────────────────────────────────────────────────── */
QFrame#Sidebar {{
    background-color: {theme.surface};
    border-right: 2px solid {theme.accent_2};
    border-image: none;
}}

/* ── Brand Logo ──────────────────────────────────────────────── */
QLabel#BrandLogo {{
    color: {theme.accent_hover};
    font-family: "{theme.font_mono}", monospace;
    font-weight: 900;
    font-size: {theme.size_xl}px;
    padding: {theme.space_lg}px {theme.space_md}px;
    letter-spacing: 4px;
    border-bottom: 2px solid {theme.accent_2};
    margin-bottom: {theme.space_sm}px;
}}

/* ── Navigation Buttons ──────────────────────────────────────── */
QPushButton.NavBtn {{
    background-color: transparent;
    color: {theme.text_dim};
    border: 1px solid transparent;
    border-left: 3px solid transparent;
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_md}px {theme.space_lg}px;
    text-align: left;
    font-family: "{theme.font_primary}", sans-serif;
    font-size: {theme.size_base}px;
    font-weight: 600;
    min-height: {theme.touch_target_min}px;
    margin: 2px {theme.space_xs}px;
}}
QPushButton.NavBtn:hover {{
    background-color: {theme.surface_2};
    color: {theme.accent_hover};
    border-left: 3px solid {theme.accent_hover};
}}
QPushButton.NavBtn:checked {{
    background-color: {theme.surface_2};
    color: {theme.accent_hover};
    border: 1px solid {theme.accent_2};
    border-left: 3px solid {theme.accent_2};
}}

/* ── Topbar ──────────────────────────────────────────────────── */
QFrame#Topbar {{
    background-color: {theme.surface};
    border-bottom: 2px solid {theme.accent_2};
}}

/* ── Active Panel Title ──────────────────────────────────────── */
QLabel#ActiveTitle {{
    color: {theme.accent_hover};
    font-family: "{theme.font_mono}", monospace;
    font-size: {theme.size_md}px;
    font-weight: bold;
    letter-spacing: 2px;
}}

/* ── System Metric Badges ────────────────────────────────────── */
QLabel#MetricLabel {{
    color: {theme.accent_hover};
    font-family: "{theme.font_mono}", monospace;
    font-size: {theme.size_sm}px;
    background-color: {theme.bg};
    border: 1px solid {theme.accent_2};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_xs}px {theme.space_sm}px;
    margin-left: {theme.space_sm}px;
}}

/* ── Stacked Panel Container ─────────────────────────────────── */
QStackedWidget {{
    background-color: {theme.bg};
    border: none;
}}

/* ── Global Scrollbars ───────────────────────────────────────── */
QScrollBar:vertical {{
    background-color: {theme.bg};
    width: 8px;
    border: none;
}}
QScrollBar::handle:vertical {{
    background-color: {theme.accent_2};
    border-radius: 4px;
    min-height: 30px;
}}
QScrollBar::handle:vertical:hover {{
    background-color: {theme.accent_hover};
}}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
    height: 0px;
}}

QScrollBar:horizontal {{
    background-color: {theme.bg};
    height: 8px;
    border: none;
}}
QScrollBar::handle:horizontal {{
    background-color: {theme.accent_2};
    border-radius: 4px;
    min-width: 30px;
}}
QScrollBar::handle:horizontal:hover {{
    background-color: {theme.accent_hover};
}}
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {{
    width: 0px;
}}
"""


class XenoWorkspace(QWidget):
    """
    Main desktop workspace aggregator. Integrates sidebar menus,
    live hardware diagnostic labels, and the panel stacked displays.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("WorkspaceRoot")
        self.setStyleSheet(WORKSPACE_STYLE)

        # 1. Start Telemetry Monitor
        self._monitor_thread = QThread()
        self._monitor_worker = SysMonitorWorker()
        self._monitor_worker.moveToThread(self._monitor_thread)
        self._monitor_worker.stat_updated.connect(self.on_telemetry_update, Qt.QueuedConnection)
        self._monitor_thread.started.connect(self._monitor_worker.run)
        self._monitor_thread.start()

        self.create_ui()

    def create_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # 2. Sidebar Navigation Panel
        self.sidebar = QFrame()
        self.sidebar.setObjectName("Sidebar")
        self.sidebar.setFixedWidth(theme.sidebar_width)
        sidebar_layout = QVBoxLayout(self.sidebar)
        sidebar_layout.setContentsMargins(theme.space_sm, theme.space_sm, theme.space_sm, theme.space_sm)
        sidebar_layout.setSpacing(theme.space_xs)

        self.logo = QLabel("XENO OS")
        self.logo.setObjectName("BrandLogo")
        self.logo.setAlignment(Qt.AlignCenter)
        sidebar_layout.addWidget(self.logo)

        # Subtitle
        self.subtitle = QLabel("SCIENTIFIC INTERFACE v2.0")
        self.subtitle.setStyleSheet(f"color: {theme.accent_2}; font-family: '{theme.font_mono}'; font-size: {theme.size_xs}px; letter-spacing: 2px; padding: 0 {theme.space_md}px {theme.space_sm}px; background: transparent;")
        self.subtitle.setAlignment(Qt.AlignCenter)
        sidebar_layout.addWidget(self.subtitle)

        # Create Navigation Group
        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)

        self.btn_math = QPushButton("  ▸ MATH SOLVER")
        self.btn_data = QPushButton("  ▸ DATA ANALYST")
        self.btn_code = QPushButton("  ▸ JUPYTER CODE")
        self.btn_3d = QPushButton("  ▸ 3D RENDERER")
        self.btn_sig = QPushButton("  ▸ DSP SIGNAL")

        buttons = [self.btn_math, self.btn_data, self.btn_code, self.btn_3d, self.btn_sig]
        for idx, btn in enumerate(buttons):
            btn.setCheckable(True)
            btn.setProperty("class", "NavBtn")
            self.nav_group.addButton(btn, idx)
            sidebar_layout.addWidget(btn)

        sidebar_layout.addStretch()

        # XenoSense Socket Status label
        self.socket_status = QLabel("◈ SENSE LINK: OFFLINE")
        self.socket_status.setStyleSheet(f"color: {theme.accent_2}; font-family: '{theme.font_mono}'; font-size: {theme.size_xs}px; padding: {theme.space_sm}px; letter-spacing: 1px; background: transparent;")
        sidebar_layout.addWidget(self.socket_status)

        # 3. Content Panel (Topbar + Stack)
        self.content_widget = QWidget()
        content_layout = QVBoxLayout(self.content_widget)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(0)

        # 4. Topbar Dashboard
        self.topbar = QFrame()
        self.topbar.setObjectName("Topbar")
        self.topbar.setFixedHeight(theme.topbar_height)
        topbar_layout = QHBoxLayout(self.topbar)
        topbar_layout.setContentsMargins(theme.space_lg, 0, theme.space_lg, 0)

        self.active_title = QLabel("Workspace")
        self.active_title.setObjectName("ActiveTitle")
        
        self.metric_cpu = QLabel("CPU: 0.0%")
        self.metric_cpu.setObjectName("MetricLabel")
        
        self.metric_ram = QLabel("RAM: 0.0%")
        self.metric_ram.setObjectName("MetricLabel")

        topbar_layout.addWidget(self.active_title)
        topbar_layout.addStretch()
        topbar_layout.addWidget(self.metric_cpu)
        topbar_layout.addWidget(self.metric_ram)

        content_layout.addWidget(self.topbar)

        # 5. Core Panels Stack Widget
        self.stacked_widget = QStackedWidget()
        
        self.panel_math = MathPanel()
        self.panel_data = DataPanel()
        self.panel_code = CodePanel()
        self.panel_3d = ThreeDPanel()
        self.panel_sig = SignalPanel()

        self.stacked_widget.addWidget(self.panel_math)
        self.stacked_widget.addWidget(self.panel_data)
        self.stacked_widget.addWidget(self.panel_code)
        self.stacked_widget.addWidget(self.panel_3d)
        self.stacked_widget.addWidget(self.panel_sig)

        content_layout.addWidget(self.stacked_widget)

        # Assemble main window
        main_layout.addWidget(self.sidebar)
        main_layout.addWidget(self.content_widget)

        # Event connections
        self.nav_group.idClicked.connect(self.on_nav_clicked)

        # Select first panel as active default
        self.btn_math.setChecked(True)
        self.on_nav_clicked(0)

    def on_nav_clicked(self, panel_idx):
        self.stacked_widget.setCurrentIndex(panel_idx)
        titles = ["▸ MATH SOLVER WORKSPACE", "▸ DATA ANALYSIS SUITE", "▸ JUPYTER INTERACTIVE KERNEL", "▸ VTK 3D RENDER ENGINE", "▸ DSP SIGNAL ANALYZER"]
        self.active_title.setText(titles[panel_idx])
        
        active_widget = self.stacked_widget.currentWidget()
        if hasattr(active_widget, "on_panel_active"):
            active_widget.on_panel_active()

    def on_telemetry_update(self, stats):
        self.metric_cpu.setText(f"CPU: {stats['cpu']:.1f}%")
        self.metric_ram.setText(f"RAM: {stats['ram']:.1f}%")

    def closeEvent(self, event):
        # Shutdown telemetry worker cleanly
        self._monitor_worker.stop()
        self._monitor_thread.quit()
        self._monitor_thread.wait(2000)
        super().closeEvent(event)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = XenoWorkspace()
    w.resize(1200, 800)
    w.setWindowTitle("Xeno OS — Scientific Workspace")
    w.show()
    sys.exit(app.exec())
