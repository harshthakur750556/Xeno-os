# Ensure root workspace is in sys.path when running app.py directly
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Configure Qt environment for VMs & standalone runs
from desktop.env import init_qt_environment
init_qt_environment()

# PySide6 imports
from PySide6.QtWidgets import QWidget, QVBoxLayout, QStackedWidget, QApplication
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os

from desktop.loginscreen import LoginScreen
from desktop.workspace import XenoWorkspace


class XenoApp(QWidget):
    """
    Top-level application shell coordinating authentication states and workspace rendering.
    """
    def __init__(self):
        super().__init__()
        self.setObjectName("XenoAppRoot")
        self.setStyleSheet(f"QWidget#XenoAppRoot {{ background-color: {theme.bg}; }}")
        
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setSpacing(0)

        # Core Stack
        self.stack = QStackedWidget()
        self.layout.addWidget(self.stack)

        # 1. Login View
        self.login_view = LoginScreen()
        self.login_view.login_success.connect(self.on_login_success)
        self.stack.addWidget(self.login_view)

        # Configure initial state
        self.resize(1000, 650)
        self.setWindowTitle("XENO OS — DECRYPTION TERMINAL")
        self.stack.setCurrentWidget(self.login_view)

    def on_login_success(self):
        # 2. Instantiate and show Workspace
        self.workspace_view = XenoWorkspace()
        self.stack.addWidget(self.workspace_view)
        
        # Switch views
        self.stack.setCurrentWidget(self.workspace_view)
        self.setWindowTitle("XENO OS — SCIENTIFIC DESKTOP")
        
        # Grow to default workspace dimensions
        self.resize(1300, 850)
        
        # Center on screen
        screen = QApplication.primaryScreen().geometry()
        self.move((screen.width() - self.width()) // 2, (screen.height() - self.height()) // 2)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = XenoApp()
    w.show()
    sys.exit(app.exec())
