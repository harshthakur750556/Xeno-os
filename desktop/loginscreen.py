# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QLineEdit, QPushButton, QApplication, QFrame)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG, QTimer, QDateTime

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os
import time

from desktop.panels.base_panel import BasePanel, BaseWorker


class LoginWorker(BaseWorker):
    """
    Background worker for verifying credentials with hashing delay.
    """
    def compute(self, username, password):
        try:
            # Simulate secure cryptographic check delay
            time.sleep(1.0)
            
            # Default credential check for Xeno OS live sessions
            if password == "xeno" or password == "":
                self.result_ready.emit({"success": True})
            else:
                self.result_ready.emit({"success": False, "error": "Access Denied: Invalid key."})
        except Exception as e:
            self.error_occurred.emit(str(e))


PANEL_STYLE = f"""
QWidget#LoginRoot {{
    background-color: {theme.bg};
    font-family: {theme.font_primary};
}}
QFrame#LoginCard {{
    background-color: {theme.surface};
    border: 2px solid {theme.accent_2};
    border-bottom: 2px solid {theme.border_glow};
    border-radius: {theme.radius_lg}px;
    padding: {theme.space_xl}px;
}}
QLabel#ClockLabel {{
    color: {theme.accent_hover};
    font-size: {theme.size_3xl}px;
    font-family: {theme.font_mono};
    font-weight: bold;
    background-color: transparent;
    border-bottom: 2px solid {theme.accent_hover};
    padding-bottom: {theme.space_xs}px;
}}
QLabel#DateLabel {{
    color: {theme.text_dim};
    font-size: {theme.size_md}px;
    background-color: transparent;
    padding-bottom: {theme.space_sm}px;
}}
QLabel#SubtitleLabel {{
    color: {theme.accent_2};
    font-size: {theme.size_sm}px;
    font-family: {theme.font_mono};
    font-weight: bold;
    letter-spacing: 4px;
    background-color: transparent;
    padding-bottom: {theme.space_xl}px;
}}
QLineEdit {{
    background-color: {theme.surface_2};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
    font-size: {theme.size_base}px;
    font-family: {theme.font_mono};
    min-height: {theme.touch_target_min}px;
    selection-background-color: {theme.accent_2};
}}
QLineEdit:hover {{
    border-color: {theme.accent_hover};
}}
QLineEdit:focus {{
    border-color: {theme.accent_2};
    background-color: {theme.surface};
}}
QPushButton {{
    background-color: {theme.accent_2};
    color: {theme.text};
    border: 2px solid {theme.accent_2};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
    font-size: {theme.size_base}px;
    font-family: {theme.font_mono};
    font-weight: bold;
    min-height: {theme.touch_target_min}px;
}}
QPushButton:hover {{
    background-color: {theme.accent_hover};
    color: {theme.bg};
    border-color: {theme.accent_hover};
}}
QPushButton:pressed {{
    background-color: {theme.accent};
    border-color: {theme.accent};
}}
QPushButton:disabled {{
    background-color: {theme.surface_2};
    color: {theme.text_muted};
    border-color: {theme.border};
}}
QLabel {{
    color: {theme.text_dim};
    font-size: {theme.size_base}px;
    font-family: {theme.font_mono};
    background-color: transparent;
}}
"""


class LoginScreen(BasePanel):
    """
    Lock screen overlay validating user desktop credentials and updating system clocks.
    """
    login_success = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("LoginRoot")
        self.setStyleSheet(PANEL_STYLE)

        # Clock updates (low polling: 1 second)
        self.clock_timer = QTimer(self)
        self.clock_timer.timeout.connect(self.update_clock)
        self.clock_timer.start(1000)
        self.update_clock()

    def create_worker(self) -> BaseWorker:
        return LoginWorker()

    def create_ui(self):
        # Configure layout alignment
        self._layout.setAlignment(Qt.AlignCenter)

        # 1. Clock Display
        self.clock_label = QLabel("00:00:00")
        self.clock_label.setObjectName("ClockLabel")
        self.clock_label.setAlignment(Qt.AlignCenter)

        self.date_label = QLabel("Monday, January 1, 2026")
        self.date_label.setObjectName("DateLabel")
        self.date_label.setAlignment(Qt.AlignCenter)

        self.subtitle_label = QLabel("XENO OS")
        self.subtitle_label.setObjectName("SubtitleLabel")
        self.subtitle_label.setAlignment(Qt.AlignCenter)

        self._layout.addWidget(self.clock_label)
        self._layout.addWidget(self.date_label)
        self._layout.addWidget(self.subtitle_label)

        # 2. Login Credentials Card
        self.card = QFrame()
        self.card.setObjectName("LoginCard")
        self.card.setFixedWidth(400)
        card_layout = QVBoxLayout(self.card)
        card_layout.setSpacing(theme.space_md)

        # User Field
        card_layout.addWidget(QLabel("User Session"))
        self.user_input = QLineEdit("xeno")
        self.user_input.setPlaceholderText("OPERATOR ID")
        card_layout.addWidget(self.user_input)

        # Password Field
        card_layout.addWidget(QLabel("Access Key"))
        self.pass_input = QLineEdit()
        self.pass_input.setEchoMode(QLineEdit.Password)
        self.pass_input.setPlaceholderText("ACCESS KEY")
        self.pass_input.returnPressed.connect(self.on_login_clicked)
        card_layout.addWidget(self.pass_input)

        # Status output
        self.status_out = QLabel("")
        self.status_out.setStyleSheet(f"color: {theme.error}; font-size: {theme.size_sm}px;")
        self.status_out.setAlignment(Qt.AlignCenter)
        card_layout.addWidget(self.status_out)

        # Button
        self.login_btn = QPushButton("► INITIALIZE SESSION")
        self.login_btn.clicked.connect(self.on_login_clicked)
        card_layout.addWidget(self.login_btn)

        self._layout.addWidget(self.card)

    def update_clock(self):
        now = QDateTime.currentDateTime()
        self.clock_label.setText(now.toString("hh:mm:ss"))
        self.date_label.setText(now.toString("dddd, MMMM d, yyyy"))

    def on_login_clicked(self):
        user = self.user_input.text().strip()
        pwd = self.pass_input.text()
        
        self.login_btn.setEnabled(False)
        self.login_btn.setText("Decrypting...")
        self.status_out.setText("")
        
        self.trigger_compute(user, pwd)

    def on_result(self, result):
        if result["success"]:
            self.clock_timer.stop()
            self.login_success.emit()
        else:
            self.login_btn.setEnabled(True)
            self.login_btn.setText("Authenticate")
            self.status_out.setText(result["error"])
            self.pass_input.clear()

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.login_btn.setEnabled(True)
        self.login_btn.setText("Authenticate")
        self.status_out.setText(f"System Error: {error_msg}")


if __name__ == "__main__":
    from desktop.env import init_qt_environment
    init_qt_environment()
    app = QApplication(sys.argv)
    w = LoginScreen()
    w.resize(1000, 600)
    w.setWindowTitle("Xeno OS — Login Decryption")
    w.show()
    sys.exit(app.exec())
