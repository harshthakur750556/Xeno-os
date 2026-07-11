# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QLineEdit, QPushButton, QTreeView, QFileSystemModel, 
                               QSplitter, QTextEdit, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG, QModelIndex

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os
import shutil

from desktop.panels.base_panel import BasePanel, BaseWorker


class FileWorker(BaseWorker):
    """
    Background worker for offloading slow file operations (deletes, reading previews).
    """
    def compute(self, action, target_path, dest_path=None):
        try:
            if not os.path.exists(target_path):
                raise FileNotFoundError(f"Path does not exist: {target_path}")

            if action == "Delete":
                if os.path.isdir(target_path):
                    shutil.rmtree(target_path)
                else:
                    os.remove(target_path)
                self.result_ready.emit({"action": "Delete", "success": True, "target": target_path})

            elif action == "Preview":
                # Only read files smaller than 10MB to avoid memory starvation
                size = os.path.getsize(target_path)
                if size > 10 * 1024 * 1024:
                    text = f"File too large to preview ({size / 1024 / 1024:.1f} MB)."
                else:
                    try:
                        with open(target_path, "r", encoding="utf-8", errors="ignore") as f:
                            text = f.read(4000)
                            if size > 4000:
                                text += "\n... [TRUNCATED] ..."
                    except Exception:
                        text = f"Binary or unreadable file format.\nSize: {size} bytes."
                self.result_ready.emit({"action": "Preview", "text": text, "target": target_path})

        except Exception as e:
            self.error_occurred.emit(str(e))


PANEL_STYLE = f"""
QWidget#XenoPanel {{
    background-color: {theme.surface};
    color: {theme.text};
    font-family: {theme.font_primary};
    font-size: {theme.size_base}px;
}}
QTreeView {{
    background-color: {theme.bg};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
}}
QTreeView::item:hover {{
    background-color: {theme.surface_2};
}}
QTreeView::item:selected {{
    background-color: {theme.accent};
    color: {theme.bg};
}}
QHeaderView::section {{
    background-color: {theme.surface_2};
    color: {theme.text};
    border: 1px solid {theme.border};
    padding: {theme.space_sm}px;
}}
QTextEdit {{
    background-color: {theme.bg};
    color: {theme.text_dim};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    font-family: {theme.font_mono};
    font-size: {theme.size_sm}px;
}}
QLineEdit {{
    background-color: {theme.bg};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
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
"""


class FileManager(BasePanel):
    """
    Scientific file explorer with live text previews and thread-safe file deletion.
    """
    def __init__(self, parent=None):
        self.model = None
        super().__init__(parent)
        self.setStyleSheet(PANEL_STYLE)

    def create_worker(self) -> BaseWorker:
        return FileWorker()

    def create_ui(self):
        # 1. Location Bar
        self.location_widget = QWidget()
        loc_layout = QHBoxLayout(self.location_widget)
        loc_layout.setContentsMargins(0, 0, 0, 0)
        loc_layout.setSpacing(theme.space_md)

        self.path_input = QLineEdit(os.path.expanduser("~"))
        self.path_input.returnPressed.connect(self.on_path_entered)

        self.up_btn = QPushButton("Up")
        self.up_btn.clicked.connect(self.on_up_clicked)

        self.delete_btn = QPushButton("Delete")
        self.delete_btn.clicked.connect(self.on_delete_clicked)

        loc_layout.addWidget(QLabel("Location:"))
        loc_layout.addWidget(self.path_input)
        loc_layout.addWidget(self.up_btn)
        loc_layout.addWidget(self.delete_btn)

        self._layout.addWidget(self.location_widget)

        # 2. Main Explorer Splitter
        self.splitter = QSplitter(Qt.Horizontal)

        # Left: Filesystem Tree Model
        self.model = QFileSystemModel()
        self.model.setRootPath(os.path.expanduser("~"))
        
        self.tree = QTreeView()
        self.tree.setModel(self.model)
        self.tree.setRootIndex(self.model.index(os.path.expanduser("~")))
        self.tree.clicked.connect(self.on_item_clicked)
        self.tree.setColumnWidth(0, 250)

        self.splitter.addWidget(self.tree)

        # Right: File Previewer
        self.preview = QTextEdit()
        self.preview.setReadOnly(True)
        self.preview.setPlaceholderText("Select a text file to view its preview.")

        self.splitter.addWidget(self.preview)
        self._layout.addWidget(self.splitter)

    def on_path_entered(self):
        target = self.path_input.text().strip()
        if os.path.isdir(target):
            self.tree.setRootIndex(self.model.index(target))

    def on_up_clicked(self):
        current_root = self.model.filePath(self.tree.rootIndex())
        parent_dir = os.path.dirname(current_root)
        if os.path.exists(parent_dir):
            self.tree.setRootIndex(self.model.index(parent_dir))
            self.path_input.setText(parent_dir)

    def on_item_clicked(self, index: QModelIndex):
        path = self.model.filePath(index)
        self.path_input.setText(path)
        
        if os.path.isfile(path):
            self.preview.setText("Loading preview...")
            self.trigger_compute("Preview", path)
        else:
            self.preview.clear()

    def on_delete_clicked(self):
        path = self.path_input.text().strip()
        if not path or path == os.path.expanduser("~"):
            return
            
        self.delete_btn.setEnabled(False)
        self.delete_btn.setText("Deleting...")
        self.trigger_compute("Delete", path)

    def on_result(self, result):
        action = result["action"]
        if action == "Delete":
            self.delete_btn.setEnabled(True)
            self.delete_btn.setText("Delete")
            self.preview.setText(f"Deleted: {result['target']}")
            # Force filesystem model refresh
            self.model.setRootPath("")
            self.model.setRootPath(os.path.expanduser("~"))
        elif action == "Preview":
            self.preview.setText(result["text"])

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.preview.setText(f"[ERROR] {error_msg}")
        self.delete_btn.setEnabled(True)
        self.delete_btn.setText("Delete")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = FileManager()
    w.resize(1000, 600)
    w.setWindowTitle("Xeno OS — File Explorer Test")
    w.show()
    sys.exit(app.exec())
