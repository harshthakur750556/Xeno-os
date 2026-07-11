# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QLineEdit, QPushButton, QTabWidget, QFormLayout, 
                               QSpinBox, QDoubleSpinBox, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os
import json

from desktop.panels.base_panel import BasePanel, BaseWorker


class SettingsWorker(BaseWorker):
    """
    Background worker for asynchronous read/write of settings files.
    """
    def compute(self, action, config_data=None):
        try:
            config_dir = os.path.expanduser("~/.config")
            os.makedirs(config_dir, exist_ok=True)
            config_path = os.path.join(config_dir, "xeno-settings.json")

            if action == "Load":
                # Default fallback values
                settings = {
                    "hypr_sens": 0.0,
                    "hypr_border": 2,
                    "hypr_gaps_in": 5,
                    "hypr_gaps_out": 15,
                    "poll_clock": 1,
                    "poll_net": 15,
                    "poll_battery": 30,
                    "socket_path": "/tmp/xeno-sense.sock"
                }
                if os.path.exists(config_path):
                    with open(config_path, "r") as f:
                        saved = json.load(f)
                        settings.update(saved)
                
                self.result_ready.emit({"action": "Load", "settings": settings})

            elif action == "Save" and config_data:
                with open(config_path, "w") as f:
                    json.dump(config_data, f, indent=4)
                self.result_ready.emit({"action": "Save", "success": True})

        except Exception as e:
            self.error_occurred.emit(str(e))


PANEL_STYLE = f"""
QWidget#XenoPanel {{
    background-color: {theme.surface};
    color: {theme.text};
    font-family: {theme.font_primary};
    font-size: {theme.size_base}px;
}}
QTabWidget::pane {{
    border: 1px solid {theme.border};
    background: {theme.bg};
    border-radius: {theme.radius_md}px;
    padding: {theme.space_lg}px;
}}
QTabBar::tab {{
    background: {theme.surface_2};
    color: {theme.text_dim};
    border: 1px solid {theme.border};
    border-bottom: none;
    border-top-left-radius: {theme.radius_sm}px;
    border-top-right-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_lg}px;
    margin-right: {theme.space_xs}px;
}}
QTabBar::tab:selected, QTabBar::tab:hover {{
    background: {theme.bg};
    color: {theme.text};
    border-color: {theme.border};
}}
QLineEdit {{
    background-color: {theme.surface_2};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
}}
QSpinBox, QDoubleSpinBox {{
    background-color: {theme.surface_2};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px;
    min-height: {theme.touch_target_min}px;
}}
QPushButton {{
    background-color: {theme.surface_2};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
    min-height: {theme.touch_target_min}px;
}}
QPushButton:hover {{
    background-color: {theme.accent};
    color: {theme.bg};
    border-color: {theme.accent};
}}
QLabel {{
    color: {theme.text};
    background-color: transparent;
}}
"""


class SettingsCenter(BasePanel):
    """
    Control dashboard for managing workspace environments, shell layouts, and service daemons.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet(PANEL_STYLE)
        
        # Load settings immediately
        self.trigger_compute("Load")

    def create_worker(self) -> BaseWorker:
        return SettingsWorker()

    def create_ui(self):
        # 1. Main tabs layout
        self.tabs = QTabWidget()
        
        # Tab A: Compositor
        self.tab_compositor = QWidget()
        self.comp_layout = QFormLayout(self.tab_compositor)
        self.comp_layout.setSpacing(theme.space_md)

        self.input_sens = QDoubleSpinBox()
        self.input_sens.setRange(-1.0, 1.0)
        self.input_sens.setSingleStep(0.1)

        self.input_border = QSpinBox()
        self.input_border.setRange(0, 10)

        self.input_gaps_in = QSpinBox()
        self.input_gaps_in.setRange(0, 50)

        self.input_gaps_out = QSpinBox()
        self.input_gaps_out.setRange(0, 100)

        self.comp_layout.addRow(QLabel("Cursor Sensitivity:"), self.input_sens)
        self.comp_layout.addRow(QLabel("Active Window Border (px):"), self.input_border)
        self.comp_layout.addRow(QLabel("Inner Window Gaps (px):"), self.input_gaps_in)
        self.comp_layout.addRow(QLabel("Outer Window Gaps (px):"), self.input_gaps_out)

        self.tabs.addTab(self.tab_compositor, "Compositor")

        # Tab B: Diagnostics & Daemon
        self.tab_daemon = QWidget()
        self.daemon_layout = QFormLayout(self.tab_daemon)
        self.daemon_layout.setSpacing(theme.space_md)

        self.input_clock = QSpinBox()
        self.input_clock.setRange(1, 10)
        
        self.input_net = QSpinBox()
        self.input_net.setRange(1, 120)

        self.input_battery = QSpinBox()
        self.input_battery.setRange(1, 300)

        self.input_socket = QLineEdit()

        self.daemon_layout.addRow(QLabel("Clock Update Interval (s):"), self.input_clock)
        self.daemon_layout.addRow(QLabel("Network Polling Rate (s):"), self.input_net)
        self.daemon_layout.addRow(QLabel("Battery Status Polling (s):"), self.input_battery)
        self.daemon_layout.addRow(QLabel("XenoSense Socket Path:"), self.input_socket)

        self.tabs.addTab(self.tab_daemon, "Daemon Control")

        # Tab C: Theme Schema (Read Only info)
        self.tab_theme = QWidget()
        self.theme_layout = QFormLayout(self.tab_theme)
        self.theme_layout.setSpacing(theme.space_sm)

        self.theme_layout.addRow(QLabel("Theme Palette:"), QLabel("Cyber-Nord (Hybrid Dark)"))
        self.theme_layout.addRow(QLabel("Background Color:"), QLabel(f"{theme.bg}"))
        self.theme_layout.addRow(QLabel("Surface Color:"), QLabel(f"{theme.surface}"))
        self.theme_layout.addRow(QLabel("Accent Highlight:"), QLabel(f"{theme.accent}"))
        self.theme_layout.addRow(QLabel("Secondary Accent:"), QLabel(f"{theme.accent_2}"))
        self.theme_layout.addRow(QLabel("Primary Font:"), QLabel(f"'{theme.font_primary}'"))
        self.theme_layout.addRow(QLabel("Monospace Font:"), QLabel(f"'{theme.font_mono}'"))

        self.tabs.addTab(self.tab_theme, "Theme Details")

        self._layout.addWidget(self.tabs)

        # 2. Bottom save buttons
        self.buttons_widget = QWidget()
        buttons_layout = QHBoxLayout(self.buttons_widget)
        buttons_layout.setContentsMargins(0, 0, 0, 0)
        
        self.save_btn = QPushButton("Save Settings")
        self.save_btn.clicked.connect(self.on_save_clicked)
        self.status_label = QLabel("")
        self.status_label.setStyleSheet(f"color: {theme.accent_2}; font-weight: bold;")

        buttons_layout.addWidget(self.save_btn)
        buttons_layout.addWidget(self.status_label)
        buttons_layout.addStretch()

        self._layout.addWidget(self.buttons_widget)

    def on_save_clicked(self):
        config_data = {
            "hypr_sens": self.input_sens.value(),
            "hypr_border": self.input_border.value(),
            "hypr_gaps_in": self.input_gaps_in.value(),
            "hypr_gaps_out": self.input_gaps_out.value(),
            "poll_clock": self.input_clock.value(),
            "poll_net": self.input_net.value(),
            "poll_battery": self.input_battery.value(),
            "socket_path": self.input_socket.text().strip()
        }
        self.save_btn.setEnabled(False)
        self.status_label.setText("Saving configurations...")
        self.trigger_compute("Save", config_data)

    def on_result(self, result):
        action = result["action"]
        if action == "Load":
            settings = result["settings"]
            self.input_sens.setValue(settings["hypr_sens"])
            self.input_border.setValue(settings["hypr_border"])
            self.input_gaps_in.setValue(settings["hypr_gaps_in"])
            self.input_gaps_out.setValue(settings["hypr_gaps_out"])
            self.input_clock.setValue(settings["poll_clock"])
            self.input_net.setValue(settings["poll_net"])
            self.input_battery.setValue(settings["poll_battery"])
            self.input_socket.setText(settings["socket_path"])
        elif action == "Save":
            self.save_btn.setEnabled(True)
            self.status_label.setText("Settings saved successfully!")
            # Clear status message after 3 seconds
            QTimer = QApplication.instance().metaObject() # Or simple PySide timer
            from PySide6.QtCore import QTimer
            QTimer.singleShot(3000, lambda: self.status_label.setText(""))

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.save_btn.setEnabled(True)
        self.status_label.setText(f"Error: {error_msg}")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = SettingsCenter()
    w.resize(800, 600)
    w.setWindowTitle("Xeno OS — Settings Center Test")
    w.show()
    sys.exit(app.exec())
