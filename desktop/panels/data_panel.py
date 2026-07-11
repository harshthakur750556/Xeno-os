# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QLineEdit, QPushButton, QComboBox, QFormLayout, 
                               QFileDialog, QTableWidget, QTableWidgetItem, QSplitter, 
                               QTextEdit, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

try:
    from PySide6.QtWebEngineWidgets import QWebEngineView
    HAS_WEBENGINE = True
except ImportError:
    HAS_WEBENGINE = False
    QWebEngineView = None

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import pandas as pd
import plotly.express as px
import sympy as sp

# STEP 6: Standard library
import sys
import os

from desktop.panels.base_panel import BasePanel, BaseWorker


class DataWorker(BaseWorker):
    """
    Background worker for reading files and computing plots using Pandas and Plotly.
    """
    def compute(self, file_path, action, x_col=None, y_col=None, plot_type=None):
        try:
            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: {file_path}")
            
            df = pd.read_csv(file_path)
            columns = list(df.columns)
            
            if action == "Load":
                summary = df.describe(include='all').to_string()
                head_data = df.head(10).to_dict(orient='split')
                self.result_ready.emit({
                    "action": "Load",
                    "columns": columns,
                    "summary": summary,
                    "head_data": head_data
                })
            elif action == "Plot":
                plot_data = {}
                if HAS_WEBENGINE:
                    fig = None
                    if plot_type == "Scatter":
                        fig = px.scatter(df, x=x_col, y=y_col, template="plotly_dark")
                    elif plot_type == "Line":
                        fig = px.line(df, x=x_col, y=y_col, template="plotly_dark")
                    elif plot_type == "Bar":
                        fig = px.bar(df, x=x_col, y=y_col, template="plotly_dark")
                    elif plot_type == "Histogram":
                        fig = px.histogram(df, x=x_col, template="plotly_dark")
                    
                    if fig is not None:
                        fig.update_layout(
                            paper_bgcolor=theme.bg,
                            plot_bgcolor=theme.bg,
                            font_color=theme.text
                        )
                        plot_html = fig.to_html(include_plotlyjs='cdn', full_html=True)
                        plot_data["html"] = plot_html
                else:
                    # Provide series data for Matplotlib rendering fallback
                    plot_data["x_values"] = df[x_col].values.tolist() if x_col in df.columns else []
                    if y_col and y_col in df.columns:
                        plot_data["y_values"] = df[y_col].values.tolist()
                    else:
                        plot_data["y_values"] = []
                
                self.result_ready.emit({
                    "action": "Plot",
                    "plot_data": plot_data,
                    "x_col": x_col,
                    "y_col": y_col,
                    "plot_type": plot_type
                })
        except Exception as e:
            self.error_occurred.emit(str(e))


PANEL_STYLE = f"""
QWidget#XenoPanel {{
    background-color: {theme.surface};
    color: {theme.text};
    font-family: {theme.font_primary};
    font-size: {theme.size_base}px;
}}
QLineEdit {{
    background-color: {theme.bg};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
    font-size: {theme.size_base}px;
}}
QLineEdit:focus {{
    border-color: {theme.accent};
}}
QPushButton {{
    background-color: {theme.surface_2};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    padding: {theme.space_sm}px {theme.space_md}px;
    font-size: {theme.size_base}px;
    min-height: {theme.touch_target_min}px;
}}
QPushButton:hover {{
    background-color: {theme.accent};
    color: {theme.bg};
    border-color: {theme.accent};
}}
QPushButton:pressed {{
    background-color: {theme.accent_2};
}}
QLabel {{
    color: {theme.text};
    background-color: transparent;
}}
QTableWidget {{
    background-color: {theme.bg};
    color: {theme.text};
    gridline-color: {theme.border};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
}}
QHeaderView::section {{
    background-color: {theme.surface_2};
    color: {theme.text};
    padding: {theme.space_sm}px;
    border: 1px solid {theme.border};
}}
QTextEdit {{
    background-color: {theme.bg};
    color: {theme.text};
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    font-family: {theme.font_mono};
    font-size: {theme.size_sm}px;
}}
"""


class DataPanel(BasePanel):
    """
    Data Analysis Panel supporting CSV upload, DataFrame preview, statistics logging,
    and high-performance chart plotting.
    """
    def __init__(self, parent=None):
        self.csv_path = None
        super().__init__(parent)
        self.setStyleSheet(PANEL_STYLE)

    def create_worker(self) -> BaseWorker:
        return DataWorker()

    def create_ui(self):
        # 1. Controls bar
        self.controls_widget = QWidget()
        self.controls_layout = QHBoxLayout(self.controls_widget)
        self.controls_layout.setContentsMargins(0, 0, 0, 0)
        self.controls_layout.setSpacing(theme.space_md)

        self.load_btn = QPushButton("Open CSV")
        self.load_btn.clicked.connect(self.on_load_clicked)

        self.x_combo = QComboBox()
        self.y_combo = QComboBox()
        for cb in [self.x_combo, self.y_combo]:
            cb.setStyleSheet(f"""
                QComboBox {{
                    background-color: {theme.surface_2};
                    color: {theme.text};
                    border: 1px solid {theme.border};
                    border-radius: {theme.radius_sm}px;
                    padding: {theme.space_sm}px {theme.space_md}px;
                    font-size: {theme.size_base}px;
                    min-height: {theme.touch_target_min}px;
                }}
                QComboBox::drop-down {{ border: 0px; }}
            """)

        self.plot_combo = QComboBox()
        self.plot_combo.addItems(["Line", "Scatter", "Bar", "Histogram"])
        self.plot_combo.setStyleSheet(self.x_combo.styleSheet())

        self.plot_btn = QPushButton("Plot")
        self.plot_btn.setEnabled(False)
        self.plot_btn.clicked.connect(self.on_plot_clicked)

        self.controls_layout.addWidget(self.load_btn)
        self.controls_layout.addWidget(QLabel("X Axis:"))
        self.controls_layout.addWidget(self.x_combo)
        self.controls_layout.addWidget(QLabel("Y Axis:"))
        self.controls_layout.addWidget(self.y_combo)
        self.controls_layout.addWidget(QLabel("Type:"))
        self.controls_layout.addWidget(self.plot_combo)
        self.controls_layout.addWidget(self.plot_btn)
        self.controls_layout.addStretch()

        self._layout.addWidget(self.controls_widget)

        # 2. Main content splitter
        self.splitter = QSplitter(Qt.Horizontal)

        # Left side: preview table and summary stats
        self.left_widget = QWidget()
        self.left_layout = QVBoxLayout(self.left_widget)
        self.left_layout.setContentsMargins(0, 0, 0, 0)
        self.left_layout.setSpacing(theme.space_sm)

        self.table_view = QTableWidget()
        self.stats_view = QTextEdit()
        self.stats_view.setReadOnly(True)
        self.stats_view.setPlaceholderText("Descriptive statistics will be shown here.")

        self.left_layout.addWidget(QLabel("DataFrame Preview (Top 10 rows):"))
        self.left_layout.addWidget(self.table_view, 2)
        self.left_layout.addWidget(QLabel("Summary Statistics:"))
        self.left_layout.addWidget(self.stats_view, 1)

        self.splitter.addWidget(self.left_widget)

        # Right side: Chart viewport
        if HAS_WEBENGINE:
            self.chart_view = QWebEngineView()
            self.splitter.addWidget(self.chart_view)
        else:
            # Matplotlib canvas fallback
            self.chart_canvas, self.fig, self.ax = self.make_matplotlib_canvas()
            self.ax.axis('off')
            self.ax.text(
                0.5, 0.5,
                r"$\text{Matplotlib rendering fallback (No WebEngine)}$",
                horizontalalignment='center',
                verticalalignment='center',
                fontsize=11,
                color=theme.text_dim,
                transform=self.ax.transAxes
            )
            self.splitter.addWidget(self.chart_canvas)

        self._layout.addWidget(self.splitter)

    def on_load_clicked(self):
        file_path, _ = QFileDialog.getOpenFileName(self, "Open CSV", "", "CSV Files (*.csv)")
        if not file_path:
            return
        
        self.csv_path = file_path
        self.load_btn.setText("Loading...")
        self.load_btn.setEnabled(False)
        self.trigger_compute(self.csv_path, "Load")

    def on_plot_clicked(self):
        if not self.csv_path:
            return
        x_col = self.x_combo.currentText()
        y_col = self.y_combo.currentText()
        plot_type = self.plot_combo.currentText()
        
        self.plot_btn.setText("Plotting...")
        self.plot_btn.setEnabled(False)
        self.trigger_compute(self.csv_path, "Plot", x_col, y_col, plot_type)

    def on_result(self, result):
        action = result["action"]
        
        if action == "Load":
            columns = result["columns"]
            summary = result["summary"]
            head_data = result["head_data"]

            # Update column dropdowns
            self.x_combo.clear()
            self.y_combo.clear()
            self.x_combo.addItems(columns)
            self.y_combo.addItems(columns)

            # Update Table Widget
            self.table_view.clear()
            self.table_view.setColumnCount(len(head_data["columns"]))
            self.table_view.setRowCount(len(head_data["data"]))
            self.table_view.setHorizontalHeaderLabels(head_data["columns"])

            for r_idx, row in enumerate(head_data["data"]):
                for c_idx, cell in enumerate(row):
                    self.table_view.setItem(r_idx, c_idx, QTableWidgetItem(str(cell)))

            self.table_view.resizeColumnsToContents()

            # Update text log
            self.stats_view.setText(summary)

            # Re-enable inputs
            self.load_btn.setText("Open CSV")
            self.load_btn.setEnabled(True)
            self.plot_btn.setEnabled(True)

        elif action == "Plot":
            plot_data = result["plot_data"]
            plot_type = result["plot_type"]
            x_col = result["x_col"]
            y_col = result["y_col"]

            if HAS_WEBENGINE:
                html = plot_data.get("html", "")
                self.chart_view.setHtml(html)
            else:
                # Render inside Matplotlib canvas fallback
                self.ax.clear()
                self.ax.set_facecolor(theme.bg)
                self.ax.tick_params(colors=theme.text_dim, labelsize=9)
                self.ax.xaxis.label.set_color(theme.text_dim)
                self.ax.yaxis.label.set_color(theme.text_dim)
                for spine in self.ax.spines.values():
                    spine.set_edgecolor(theme.border)
                self.ax.grid(True, color=theme.border, linestyle="--", linewidth=0.5)

                x = plot_data["x_values"]
                y = plot_data["y_values"]

                if plot_type == "Scatter":
                    self.ax.scatter(x, y, color=theme.accent, alpha=0.8, edgecolors="none")
                    self.ax.set_ylabel(y_col)
                elif plot_type == "Line":
                    self.ax.plot(x, y, color=theme.accent, linewidth=1.5)
                    self.ax.set_ylabel(y_col)
                elif plot_type == "Bar":
                    self.ax.bar(x[:50], y[:50], color=theme.accent_2, edgecolor=theme.border)
                    self.ax.set_ylabel(y_col)
                elif plot_type == "Histogram":
                    self.ax.hist(x, bins=20, color=theme.accent, edgecolor=theme.bg)
                    self.ax.set_ylabel("Count")

                self.ax.set_xlabel(x_col)
                self.fig.tight_layout(pad=1.5)
                self.chart_canvas.draw()

            self.plot_btn.setText("Plot")
            self.plot_btn.setEnabled(True)

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.stats_view.setText(f"[ERROR] {error_msg}")
        self.load_btn.setText("Open CSV")
        self.load_btn.setEnabled(True)
        self.plot_btn.setText("Plot")
        self.plot_btn.setEnabled(True)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = DataPanel()
    w.resize(1000, 600)
    w.setWindowTitle("Xeno OS — Data Analysis Panel Test")
    w.show()
    sys.exit(app.exec())
