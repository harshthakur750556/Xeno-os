# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QSlider, QPushButton, QComboBox, QFormLayout, 
                               QCheckBox, QSplitter, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp
import scipy.signal as sig
import scipy.fft as fft

# STEP 6: Standard library
import sys
import os

from desktop.panels.base_panel import BasePanel, BaseWorker


class SignalWorker(BaseWorker):
    """
    Background worker for DSP operations.
    Synthesizes signals, injects noise, filters using SciPy Butter, and runs FFT.
    """
    def compute(self, wave_type, freq, amp, noise, apply_filter, filter_cutoff):
        try:
            fs = 1000.0  # sampling rate (Hz)
            duration = 1.0  # duration (seconds)
            t = np.linspace(0, duration, int(fs * duration), endpoint=False)
            
            # Synthesize wave
            if wave_type == "Sine":
                y = amp * np.sin(2 * np.pi * freq * t)
            elif wave_type == "Square":
                y = amp * sig.square(2 * np.pi * freq * t)
            elif wave_type == "Sawtooth":
                y = amp * sig.sawtooth(2 * np.pi * freq * t)
            else:
                y = np.zeros_like(t)
                
            # Add Gaussian noise
            if noise > 0:
                y += np.random.normal(0, noise, size=t.shape)
                
            y_raw = y.copy()
            
            # Butterworth lowpass filter
            y_filtered = None
            if apply_filter and filter_cutoff < fs / 2:
                nyq = 0.5 * fs
                normal_cutoff = filter_cutoff / nyq
                b, a = sig.butter(4, normal_cutoff, btype='low', analog=False)
                y_filtered = sig.lfilter(b, a, y)
                y = y_filtered
                
            # Perform Fast Fourier Transform (FFT)
            n = len(t)
            yf = fft.fft(y)
            xf = fft.fftfreq(n, 1/fs)[:n//2]
            yf_magnitude = 2.0/n * np.abs(yf[:n//2])
            
            self.result_ready.emit({
                "t": t.tolist(),
                "y_raw": y_raw.tolist(),
                "y_filtered": y_filtered.tolist() if y_filtered is not None else [],
                "freqs": xf.tolist(),
                "mags": yf_magnitude.tolist(),
                "wave_type": wave_type,
                "fs": fs
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
QCheckBox {{
    color: {theme.text};
    spacing: {theme.space_sm}px;
}}
QCheckBox::indicator {{
    width: 16px;
    height: 16px;
    border: 1px solid {theme.border};
    border-radius: {theme.radius_sm}px;
    background: {theme.bg};
}}
QCheckBox::indicator:checked {{
    background: {theme.accent};
    image: none;
}}
"""


class SignalPanel(BasePanel):
    """
    DSP Signal Analysis panel featuring real-time synthesis, lowpass filtering, and FFT spectral plots.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet(PANEL_STYLE)

    def create_worker(self) -> BaseWorker:
        return SignalWorker()

    def create_ui(self):
        # 1. Main visual layout divider
        self.splitter = QSplitter(Qt.Horizontal)

        # 2. Left side: control board
        self.controls_widget = QWidget()
        self.form_layout = QFormLayout(self.controls_widget)
        self.form_layout.setContentsMargins(0, 0, 0, 0)
        self.form_layout.setSpacing(theme.space_md)

        self.wave_combo = QComboBox()
        self.wave_combo.addItems(["Sine", "Square", "Sawtooth"])

        # Frequency Slider (1 to 200 Hz)
        self.freq_slider = QSlider(Qt.Horizontal)
        self.freq_slider.setRange(1, 200)
        self.freq_slider.setValue(20)
        self.freq_label = QLabel("20 Hz")

        # Amplitude Slider (0.1 to 5.0, represented as 1 to 50)
        self.amp_slider = QSlider(Qt.Horizontal)
        self.amp_slider.setRange(1, 50)
        self.amp_slider.setValue(15)
        self.amp_label = QLabel("1.5 V")

        # Noise level Slider (0.0 to 3.0, represented as 0 to 30)
        self.noise_slider = QSlider(Qt.Horizontal)
        self.noise_slider.setRange(0, 30)
        self.noise_slider.setValue(5)
        self.noise_label = QLabel("0.5 σ")

        # Filter Options
        self.filter_checkbox = QCheckBox("Apply Lowpass Filter")
        
        # Cutoff frequency (10 to 450 Hz)
        self.cutoff_slider = QSlider(Qt.Horizontal)
        self.cutoff_slider.setRange(10, 450)
        self.cutoff_slider.setValue(50)
        self.cutoff_label = QLabel("50 Hz")

        self.compute_btn = QPushButton("Analyze Signal")
        self.compute_btn.clicked.connect(self.on_analyze_clicked)

        # Synchronize Sliders with UI Labels
        self.freq_slider.valueChanged.connect(lambda v: self.freq_label.setText(f"{v} Hz"))
        self.amp_slider.valueChanged.connect(lambda v: self.amp_label.setText(f"{v/10.0:.1f} V"))
        self.noise_slider.valueChanged.connect(lambda v: self.noise_label.setText(f"{v/10.0:.1f} σ"))
        self.cutoff_slider.valueChanged.connect(lambda v: self.cutoff_label.setText(f"{v} Hz"))

        self.form_layout.addRow(QLabel("Waveform:"), self.wave_combo)
        
        freq_layout = QHBoxLayout()
        freq_layout.addWidget(self.freq_slider)
        freq_layout.addWidget(self.freq_label)
        self.form_layout.addRow(QLabel("Frequency:"), freq_layout)

        amp_layout = QHBoxLayout()
        amp_layout.addWidget(self.amp_slider)
        amp_layout.addWidget(self.amp_label)
        self.form_layout.addRow(QLabel("Amplitude:"), amp_layout)

        noise_layout = QHBoxLayout()
        noise_layout.addWidget(self.noise_slider)
        noise_layout.addWidget(self.noise_label)
        self.form_layout.addRow(QLabel("Noise Level:"), noise_layout)

        self.form_layout.addRow(self.filter_checkbox)
        
        cutoff_layout = QHBoxLayout()
        cutoff_layout.addWidget(self.cutoff_slider)
        cutoff_layout.addWidget(self.cutoff_label)
        self.form_layout.addRow(QLabel("Filter Cutoff:"), cutoff_layout)
        
        self.form_layout.addRow(self.compute_btn)

        # 3. Right side: Double Matplotlib Subplots
        self.canvas_widget = QWidget()
        self.canvas_layout = QVBoxLayout(self.canvas_widget)
        self.canvas_layout.setContentsMargins(0, 0, 0, 0)

        # Create dual-axes Matplotlib Canvas
        import matplotlib
        matplotlib.use('Agg')
        from matplotlib.figure import Figure
        from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg
        self.fig = Figure(figsize=(7, 5), facecolor=theme.bg)
        self.canvas = FigureCanvasQTAgg(self.fig)
        
        self.ax_time = self.fig.add_subplot(211)
        self.ax_freq = self.fig.add_subplot(212)
        
        for ax in [self.ax_time, self.ax_freq]:
            ax.set_facecolor(theme.bg)
            ax.tick_params(colors=theme.text_dim, labelsize=9)
            ax.xaxis.label.set_color(theme.text_dim)
            ax.yaxis.label.set_color(theme.text_dim)
            for spine in ax.spines.values():
                spine.set_edgecolor(theme.border)
        
        self.fig.tight_layout(pad=2.0)
        self.canvas_layout.addWidget(self.canvas)

        self.splitter.addWidget(self.controls_widget)
        self.splitter.addWidget(self.canvas_widget)
        self._layout.addWidget(self.splitter)

        # Set default state and run initial plot
        self.on_analyze_clicked()

    def on_analyze_clicked(self):
        w_type = self.wave_combo.currentText()
        freq = self.freq_slider.value()
        amp = self.amp_slider.value() / 10.0
        noise = self.noise_slider.value() / 10.0
        apply_filter = self.filter_checkbox.isChecked()
        cutoff = self.cutoff_slider.value()

        self.compute_btn.setEnabled(False)
        self.compute_btn.setText("Analyzing...")
        self.trigger_compute(w_type, freq, amp, noise, apply_filter, cutoff)

    def on_result(self, result):
        t = result["t"]
        y_raw = result["y_raw"]
        y_filtered = result["y_filtered"]
        freqs = result["freqs"]
        mags = result["mags"]
        wave_type = result["wave_type"]

        # 1. Update Time Domain Plot
        self.ax_time.clear()
        self.ax_time.set_title("Time Domain Signal", color=theme.text, fontsize=10)
        self.ax_time.grid(True, color=theme.border, linestyle="--", linewidth=0.5)
        
        if len(y_filtered) > 0:
            self.ax_time.plot(t[:200], y_raw[:200], color=theme.text_muted, alpha=0.6, label="Noisy Signal")
            self.ax_time.plot(t[:200], y_filtered[:200], color=theme.accent, linewidth=2, label="Filtered Signal")
        else:
            self.ax_time.plot(t[:200], y_raw[:200], color=theme.accent, linewidth=1.5, label="Raw Signal")
            
        self.ax_time.legend(facecolor=theme.surface_2, edgecolor=theme.border, labelcolor=theme.text, fontsize=8)
        self.ax_time.set_xlabel("Time (s)", fontsize=8)
        self.ax_time.set_ylabel("Amplitude (V)", fontsize=8)

        # 2. Update Frequency Domain Plot
        self.ax_freq.clear()
        self.ax_freq.set_title("Frequency Spectrum (FFT)", color=theme.text, fontsize=10)
        self.ax_freq.grid(True, color=theme.border, linestyle="--", linewidth=0.5)
        self.ax_freq.plot(freqs, mags, color=theme.accent_2, linewidth=1.5)
        
        self.ax_freq.set_xlabel("Frequency (Hz)", fontsize=8)
        self.ax_freq.set_ylabel("Magnitude", fontsize=8)
        self.ax_freq.set_xlim(0, 250)  # limit viewport for better detail visibility

        # Set facecolors and spines for new plots
        for ax in [self.ax_time, self.ax_freq]:
            ax.set_facecolor(theme.bg)
            ax.tick_params(colors=theme.text_dim, labelsize=9)
            ax.xaxis.label.set_color(theme.text_dim)
            ax.yaxis.label.set_color(theme.text_dim)
            for spine in ax.spines.values():
                spine.set_edgecolor(theme.border)

        self.fig.tight_layout(pad=2.0)
        self.canvas.draw()

        self.compute_btn.setEnabled(True)
        self.compute_btn.setText("Analyze Signal")

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.compute_btn.setEnabled(True)
        self.compute_btn.setText("Analyze Signal")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = SignalPanel()
    w.resize(1000, 600)
    w.setWindowTitle("Xeno OS — Signal Analysis Panel Test")
    w.show()
    sys.exit(app.exec())
