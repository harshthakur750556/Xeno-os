# FILE: ~/Xeno-os/desktop/panels/base_panel.py
# PURPOSE: Thread-safe base class for all Xeno OS scientific panels
# RULE: matplotlib.use('Agg') MUST be called before any other matplotlib import
# RULE: All visual values come from desktop/theme.py — never redefine them here

import numpy as np

from PySide6.QtWidgets import QWidget, QVBoxLayout, QApplication
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Slot

from desktop.theme import theme


class BaseWorker(QObject):
    """
    Background computation worker.
    RULE: Never touch any Qt widget or matplotlib object from here.
    RULE: Always emit result_ready or error_occurred before returning.
    """
    result_ready   = Signal(object)
    error_occurred = Signal(str)
    progress       = Signal(int)

    @Slot(tuple)
    def compute_wrapper(self, args_tuple):
        self.compute(*args_tuple)

    def compute(self, *args, **kwargs):
        raise NotImplementedError(
            "Subclass BaseWorker and override compute()"
        )


class BasePanel(QWidget):
    """
    Base class for all Xeno OS scientific panels.
    RULE: Never call canvas.draw() outside of on_result() or on_error().
    RULE: Never do heavy computation in create_ui() or on_result().
    RULE: Always call trigger_compute() to start background work.
    """
    request_compute = Signal(tuple)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("XenoPanel")
        self.setStyleSheet(
            f"QWidget#XenoPanel {{"
            f"  background: {theme.surface};"
            f"  border: 1px solid {theme.border};"
            f"  border-radius: {theme.radius_md}px;"
            f"}}"
        )

        self._thread = QThread()
        self._worker = self.create_worker()
        self._worker.moveToThread(self._thread)
        self._worker.result_ready.connect(
            self.on_result, Qt.QueuedConnection
        )
        self._worker.error_occurred.connect(
            self.on_error, Qt.QueuedConnection
        )
        self._worker.progress.connect(
            self.on_progress, Qt.QueuedConnection
        )
        self.request_compute.connect(
            self._worker.compute_wrapper, Qt.QueuedConnection
        )
        self._thread.start()

        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(
            theme.panel_padding, theme.panel_padding,
            theme.panel_padding, theme.panel_padding
        )
        self._layout.setSpacing(theme.space_md)
        self.create_ui()

    def create_worker(self) -> BaseWorker:
        return BaseWorker()

    def create_ui(self):
        pass

    def on_result(self, result):
        pass

    def on_error(self, error_msg: str):
        print(f"[XenoPanel Error] {error_msg}")

    def on_panel_active(self):
        pass

    def on_progress(self, value: int):
        pass

    def trigger_compute(self, *args):
        self.request_compute.emit(args)

    def make_matplotlib_canvas(self, figsize=(7, 3.5)):
        import matplotlib
        matplotlib.use('Agg')
        from matplotlib.figure import Figure
        from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg
        fig = Figure(figsize=figsize, facecolor=theme.bg)
        canvas = FigureCanvasQTAgg(fig)
        ax = fig.add_subplot(111)
        ax.set_facecolor(theme.bg)
        ax.tick_params(colors=theme.text_dim, labelsize=10)
        ax.xaxis.label.set_color(theme.text_dim)
        ax.yaxis.label.set_color(theme.text_dim)
        for spine in ax.spines.values():
            spine.set_edgecolor(theme.border)
        fig.tight_layout(pad=1.5)
        return canvas, fig, ax

    def closeEvent(self, event):
        self._thread.quit()
        self._thread.wait(3000)
        super().closeEvent(event)


class MatplotlibPanel(BasePanel):
    """
    Convenience subclass for panels that embed a single matplotlib chart.
    Access via self.canvas, self.fig, self.ax.
    Call self.refresh_canvas() after modifying the plot in on_result().
    refresh_canvas() is ONLY safe to call from on_result() on the main thread.
    """

    def __init__(self, parent=None):
        self._canvas = None
        self._fig = None
        self._ax = None
        super().__init__(parent)

    def create_ui(self):
        self._canvas, self._fig, self._ax = self.make_matplotlib_canvas()
        self._layout.addWidget(self._canvas)

    @property
    def canvas(self):
        return self._canvas

    @property
    def fig(self):
        return self._fig

    @property
    def ax(self):
        return self._ax

    def refresh_canvas(self):
        """Call ONLY from on_result() on the main thread."""
        try:
            self._fig.tight_layout(pad=1.5)
            self._canvas.draw()
        except Exception as e:
            print(f"[Canvas refresh error] {e}")
