# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QSlider, QPushButton, QComboBox, QFormLayout, 
                               QSplitter, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

# VTK widgets (lazy loaded)
QVTKRenderWindowInteractor = None
vtk = None

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os

from desktop.panels.base_panel import BasePanel, BaseWorker


class ThreeDWorker(BaseWorker):
    """
    Background worker for offloading 3D calculations or parameter configuration.
    """
    def compute(self, shape_type, radius, height, res):
        try:
            # Safely prepare rendering parameters
            params = {
                "radius": float(radius),
                "height": float(height),
                "res": int(res)
            }
            self.result_ready.emit({
                "shape_type": shape_type,
                "params": params
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
QSlider::groove:horizontal {{
    border: 1px solid {theme.border};
    height: 6px;
    background: {theme.bg};
    border-radius: 3px;
}}
QSlider::handle:horizontal {{
    background: {theme.accent};
    width: 14px;
    margin: -4px 0;
    border-radius: 7px;
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
QLabel {{
    color: {theme.text};
    background-color: transparent;
}}
"""


class ThreeDPanel(BasePanel):
    """
    3D visualization workspace panel using VTK rendering pipeline.
    """
    def __init__(self, parent=None):
        self.vtkWidget = None
        self.renderer = None
        self._vtk_initialized = False
        super().__init__(parent)
        self.setStyleSheet(PANEL_STYLE)

    def create_worker(self) -> BaseWorker:
        return ThreeDWorker()

    def create_ui(self):
        # Setup splitter for layout
        self.splitter = QSplitter(Qt.Horizontal)

        # Left panel: parameters form
        self.params_widget = QWidget()
        self.form_layout = QFormLayout(self.params_widget)
        self.form_layout.setContentsMargins(0, 0, 0, 0)
        self.form_layout.setSpacing(theme.space_md)

        self.shape_combo = QComboBox()
        self.shape_combo.addItems(["Sphere", "Cone", "Cylinder", "Cube"])

        # Param 1: Radius Slider (0.1 to 5.0, represented as 1 to 50)
        self.radius_slider = QSlider(Qt.Horizontal)
        self.radius_slider.setRange(1, 50)
        self.radius_slider.setValue(15)
        self.radius_label = QLabel("1.5")

        # Param 2: Height Slider (0.1 to 5.0, represented as 1 to 50)
        self.height_slider = QSlider(Qt.Horizontal)
        self.height_slider.setRange(1, 50)
        self.height_slider.setValue(20)
        self.height_label = QLabel("2.0")

        # Param 3: Resolution Slider (3 to 60)
        self.res_slider = QSlider(Qt.Horizontal)
        self.res_slider.setRange(3, 60)
        self.res_slider.setValue(24)
        self.res_label = QLabel("24")

        # Visual mode
        self.rep_combo = QComboBox()
        self.rep_combo.addItems(["Surface", "Wireframe", "Points"])

        self.compute_btn = QPushButton("Render")
        self.compute_btn.clicked.connect(self.on_render_clicked)

        # Connect slider changes to updating labels
        self.radius_slider.valueChanged.connect(lambda v: self.radius_label.setText(f"{v/10.0:.1f}"))
        self.height_slider.valueChanged.connect(lambda v: self.height_label.setText(f"{v/10.0:.1f}"))
        self.res_slider.valueChanged.connect(lambda v: self.res_label.setText(str(v)))

        # Form assembly
        self.form_layout.addRow(QLabel("Primitive Type:"), self.shape_combo)
        
        r_layout = QHBoxLayout()
        r_layout.addWidget(self.radius_slider)
        r_layout.addWidget(self.radius_label)
        self.form_layout.addRow(QLabel("Radius / Size:"), r_layout)

        h_layout = QHBoxLayout()
        h_layout.addWidget(self.height_slider)
        h_layout.addWidget(self.height_label)
        self.form_layout.addRow(QLabel("Height:"), h_layout)

        res_layout = QHBoxLayout()
        res_layout.addWidget(self.res_slider)
        res_layout.addWidget(self.res_label)
        self.form_layout.addRow(QLabel("Mesh Quality:"), res_layout)
        
        self.form_layout.addRow(QLabel("Draw Style:"), self.rep_combo)
        self.form_layout.addRow(self.compute_btn)

        # Right panel: VTK Viewport placeholder
        # NOTE: VTK widget construction is deferred to _lazy_init_vtk()
        # because QVTKRenderWindowInteractor creates an X11 window on
        # construction. If the panel is hidden inside a QStackedWidget,
        # the native window handle doesn't exist yet → BadWindow crash.
        self.vtk_placeholder = QWidget(self)

        self.splitter.addWidget(self.params_widget)
        self.splitter.addWidget(self.vtk_placeholder)
        self._layout.addWidget(self.splitter)

    def showEvent(self, event):
        super().showEvent(event)
        if self.parent() is None:
            from PySide6.QtCore import QTimer
            QTimer.singleShot(50, self._lazy_init_vtk)

    def on_panel_active(self):
        from PySide6.QtCore import QTimer
        QTimer.singleShot(50, self._lazy_init_vtk)

    def _lazy_init_vtk(self):
        global QVTKRenderWindowInteractor, vtk
        if not self._vtk_initialized:
            try:
                # Lazy load VTK dependencies
                from vtkmodules.qt.QVTKRenderWindowInteractor import QVTKRenderWindowInteractor as VTKWidget
                import vtkmodules.all as vtk_lib
                QVTKRenderWindowInteractor = VTKWidget
                vtk = vtk_lib

                # Construct VTK widget NOW (when the panel is visible and mapped)
                self.vtkWidget = QVTKRenderWindowInteractor(self)
                self.renderer = vtk.vtkRenderer()
                self.vtkWidget.GetRenderWindow().AddRenderer(self.renderer)

                # Synchronize viewport background with theme background
                bg_rgb = self.hex_to_rgb(theme.bg)
                self.renderer.SetBackground(*bg_rgb)

                # Replace the placeholder with the real VTK widget
                self.splitter.replaceWidget(1, self.vtkWidget)
                self.vtk_placeholder.deleteLater()
                self.vtk_placeholder = None

                self.vtkWidget.Initialize()
                self._vtk_initialized = True
                self.on_render_clicked()
            except Exception as e:
                print(f"[VTK Lazy Init Error] {e}")

    def hex_to_rgb(self, hex_str):
        hex_str = hex_str.lstrip('#')
        if len(hex_str) == 8:  # RRGGBBAA -> RRGGBB
            hex_str = hex_str[:6]
        return [int(hex_str[i:i+2], 16) / 255.0 for i in (0, 2, 4)]

    def on_render_clicked(self):
        shape = self.shape_combo.currentText()
        r = self.radius_slider.value() / 10.0
        h = self.height_slider.value() / 10.0
        res = self.res_slider.value()

        self.compute_btn.setEnabled(False)
        self.compute_btn.setText("Rendering...")
        self.trigger_compute(shape, r, h, res)

    def on_result(self, result):
        shape_type = result["shape_type"]
        params = result["params"]

        self.renderer.RemoveAllViewProps()

        # 2.2 Adaptive mesh resolution based on hardware capabilities
        is_software = os.environ.get("LIBGL_ALWAYS_SOFTWARE") == "1"
        if is_software and "res" in params:
            # Force lower resolution to avoid locking up software pixman thread
            params["res"] = max(3, params["res"] // 2)

        # Map shape type to VTK Source
        if shape_type == "Sphere":
            source = vtk.vtkSphereSource()
            source.SetRadius(params["radius"])
            source.SetThetaResolution(params["res"])
            source.SetPhiResolution(params["res"])
        elif shape_type == "Cone":
            source = vtk.vtkConeSource()
            source.SetRadius(params["radius"])
            source.SetHeight(params["height"])
            source.SetResolution(params["res"])
        elif shape_type == "Cylinder":
            source = vtk.vtkCylinderSource()
            source.SetRadius(params["radius"])
            source.SetHeight(params["height"])
            source.SetResolution(params["res"])
        elif shape_type == "Cube":
            source = vtk.vtkCubeSource()
            sz = params["radius"] * 2.0
            source.SetXLength(sz)
            source.SetYLength(sz)
            source.SetZLength(sz)
        else:
            return

        mapper = vtk.vtkPolyDataMapper()
        mapper.SetInputConnection(source.GetOutputPort())

        # Use LOD Actor for software rendering to keep UI responsive
        if is_software:
            actor = vtk.vtkLODActor()
            actor.SetNumberOfCloudPoints(500)
            actor.GetProperty().SetInterpolationToFlat()
        else:
            actor = vtk.vtkActor()
            
        actor.SetMapper(mapper)

        # Style mesh with accent color
        actor_color = self.hex_to_rgb(theme.accent)
        actor.GetProperty().SetColor(*actor_color)

        # Configure display style
        rep = self.rep_combo.currentText()
        if rep == "Wireframe":
            actor.GetProperty().SetRepresentationToWireframe()
        elif rep == "Points":
            actor.GetProperty().SetRepresentationToPoints()
            actor.GetProperty().SetPointSize(4)
        else:
            actor.GetProperty().SetRepresentationToSurface()

        self.renderer.AddActor(actor)
        self.renderer.ResetCamera()
        self.vtkWidget.GetRenderWindow().Render()

        self.compute_btn.setEnabled(True)
        self.compute_btn.setText("Render")

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.compute_btn.setEnabled(True)
        self.compute_btn.setText("Render")


if __name__ == "__main__":
    from desktop.env import init_qt_environment
    init_qt_environment()
    app = QApplication(sys.argv)
    w = ThreeDPanel()
    w.resize(1000, 600)
    w.setWindowTitle("Xeno OS — 3D Viewer Panel Test")
    w.show()
    sys.exit(app.exec())
