# PySide6 imports
from PySide6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QApplication
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

from qtconsole.rich_jupyter_widget import RichJupyterWidget
from qtconsole.inprocess import QtInProcessKernelManager

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os

from desktop.panels.base_panel import BasePanel


class CodePanel(BasePanel):
    """
    Interactive Python Code Notebook console running an in-process Jupyter Kernel.
    Allows instant prototyping and plotting inside the Xeno OS workspace.
    """
    def __init__(self, parent=None):
        self.kernel_manager = None
        self.kernel_client = None
        super().__init__(parent)
        self.setStyleSheet(f"""
            QWidget#XenoPanel {{
                background-color: {theme.surface};
                border: 1px solid {theme.border};
                border-radius: {theme.radius_md}px;
            }}
            QLabel {{
                color: {theme.text_dim};
                font-family: {theme.font_primary};
                font-size: {theme.size_sm}px;
                padding-bottom: {theme.space_xs}px;
            }}
        """)

    def create_ui(self):
        # 1. Info / Guide label
        self.info_label = QLabel("Interactive In-Process Jupyter Kernel. Scientific libraries (NumPy, SciPy, SymPy, Pandas) are pre-loaded.")
        self._layout.addWidget(self.info_label)

        # 2. Setup Jupyter Kernel
        self.kernel_manager = QtInProcessKernelManager()
        self.kernel_manager.start_kernel()
        
        self.kernel = self.kernel_manager.kernel
        self.kernel.gui = 'qt'
        
        self.kernel_client = self.kernel_manager.client()
        self.kernel_client.start_channels()

        # 3. Create console widget
        self.console = RichJupyterWidget()
        self.console.kernel_manager = self.kernel_manager
        self.console.kernel_client = self.kernel_client
        
        # Style Console
        self.console.syntax_style = "monokai"
        self.console.style_sheet = f"""
            QTextEdit {{
                background-color: {theme.bg};
                color: {theme.text};
                font-family: {theme.font_mono};
                font-size: {theme.size_base}px;
                border: 1px solid {theme.border};
                border-radius: {theme.radius_sm}px;
            }}
        """
        
        self._layout.addWidget(self.console)

    def closeEvent(self, event):
        # Gracefully stop channels and shutdown kernel
        try:
            if self.kernel_client:
                self.kernel_client.stop_channels()
            if self.kernel_manager:
                self.kernel_manager.shutdown_kernel()
        except Exception as e:
            print(f"[CodePanel Close Error] {e}")
        super().closeEvent(event)


if __name__ == "__main__":
    from desktop.env import init_qt_environment
    init_qt_environment()
    app = QApplication(sys.argv)
    w = CodePanel()
    w.resize(900, 600)
    w.setWindowTitle("Xeno OS — Code Notebook Test")
    w.show()
    sys.exit(app.exec())
