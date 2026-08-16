# PySide6 imports
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                               QLineEdit, QPushButton, QComboBox, QFormLayout, QApplication)
from PySide6.QtCore import QThread, Signal, QObject, Qt, QMetaObject, Q_ARG

# STEP 4: Central theme — never hardcode colors/fonts/spacing in this file
from desktop.theme import theme

# STEP 5: Scientific libraries
import numpy as np
import sympy as sp

# STEP 6: Standard library
import sys
import os

from desktop.panels.base_panel import MatplotlibPanel, BaseWorker


class MathWorker(BaseWorker):
    """
    Background worker for mathematical computations using SymPy.
    Computes limits, derivatives, integrals, and equation roots.
    """
    def compute(self, expr_str, op, var_str="x"):
        try:
            var = sp.Symbol(var_str)
            expr = sp.sympify(expr_str)
            
            result_expr = None
            plot_data = None
            
            if op == "Solve":
                result_expr = sp.solve(expr, var)
            elif op == "Differentiate":
                result_expr = sp.diff(expr, var)
            elif op == "Integrate":
                result_expr = sp.integrate(expr, var)
            elif op == "Plot":
                result_expr = expr
                # Generate values for plotting in range [-10, 10]
                f_lambdified = sp.lambdify(var, expr, "numpy")
                x_vals = np.linspace(-10, 10, 400)
                
                try:
                    y_vals = f_lambdified(x_vals)
                    if isinstance(y_vals, (int, float, np.number)):
                        y_vals = np.full_like(x_vals, float(y_vals))
                    else:
                        y_vals = np.array(y_vals, dtype=float)
                        y_vals = np.nan_to_num(y_vals, nan=0.0, posinf=100.0, neginf=-100.0)
                except Exception:
                    # Fallback evaluation item-by-item if vectorized lambdify fails
                    y_vals_list = []
                    for xv in x_vals:
                        try:
                            val = float(expr.subs(var, xv).evalf())
                        except Exception:
                            val = np.nan
                        y_vals_list.append(val)
                    y_vals = np.array(y_vals_list, dtype=float)
                    y_vals = np.nan_to_num(y_vals, nan=0.0, posinf=100.0, neginf=-100.0)
                
                plot_data = (x_vals.tolist(), y_vals.tolist())
            else:
                raise ValueError(f"Unknown operation: {op}")
            
            # Format outputs as LaTeX string
            if isinstance(result_expr, list):
                if len(result_expr) == 0:
                    latex_str = r"\emptyset"
                    plain_str = "No solution"
                else:
                    latex_str = ", ".join([sp.latex(r) for r in result_expr])
                    plain_str = ", ".join([str(r) for r in result_expr])
            else:
                latex_str = sp.latex(result_expr)
                plain_str = str(result_expr)
                
            self.result_ready.emit({
                "op": op,
                "expr_latex": sp.latex(expr),
                "result_latex": latex_str,
                "result_plain": plain_str,
                "plot_data": plot_data,
                "var_str": var_str
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
"""


class MathPanel(MatplotlibPanel):
    """
    Math Solver panel utilizing PySide6 UI and SymPy mathematical backend.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet(PANEL_STYLE)

    def create_worker(self) -> BaseWorker:
        return MathWorker()

    def create_ui(self):
        # Create control inputs
        self.controls_widget = QWidget()
        self.controls_layout = QHBoxLayout(self.controls_widget)
        self.controls_layout.setContentsMargins(0, 0, 0, 0)
        self.controls_layout.setSpacing(theme.space_md)

        self.form_layout = QFormLayout()
        self.form_layout.setSpacing(theme.space_sm)

        self.expr_input = QLineEdit("x**2 - 4")
        self.expr_input.setPlaceholderText("e.g. x**2 - 4")
        
        self.var_input = QLineEdit("x")
        self.var_input.setFixedWidth(60)

        self.op_combo = QComboBox()
        self.op_combo.addItems(["Plot", "Solve", "Differentiate", "Integrate"])
        self.op_combo.setStyleSheet(f"""
            QComboBox {{
                background-color: {theme.surface_2};
                color: {theme.text};
                border: 1px solid {theme.border};
                border-radius: {theme.radius_sm}px;
                padding: {theme.space_sm}px {theme.space_md}px;
                font-size: {theme.size_base}px;
                min-height: {theme.touch_target_min}px;
            }}
            QComboBox::drop-down {{
                border: 0px;
            }}
            QComboBox QAbstractItemView {{
                background-color: {theme.surface_2};
                color: {theme.text};
                selection-background-color: {theme.accent};
                selection-color: {theme.bg};
            }}
        """)

        self.form_layout.addRow(QLabel("Expression:"), self.expr_input)
        self.form_layout.addRow(QLabel("Variable:"), self.var_input)
        self.form_layout.addRow(QLabel("Operation:"), self.op_combo)

        self.compute_btn = QPushButton("Compute")
        self.compute_btn.clicked.connect(self.on_compute_clicked)

        self.controls_layout.addLayout(self.form_layout)
        self.controls_layout.addWidget(self.compute_btn, alignment=Qt.AlignBottom)

        # Call MatplotlibPanel create_ui to setup the canvas
        super().create_ui()

        # Insert controls layout at the top of the panel layout
        self._layout.insertWidget(0, self.controls_widget)

        # Configure initial blank state of the plot
        self.ax.axis('off')
        self.ax.text(
            0.5, 0.5,
            r"$\text{Enter expression and click Compute}$",
            horizontalalignment='center',
            verticalalignment='center',
            fontsize=12,
            color=theme.text_dim,
            transform=self.ax.transAxes
        )
        self.refresh_canvas()

    def on_compute_clicked(self):
        expr = self.expr_input.text().strip()
        op = self.op_combo.currentText()
        var = self.var_input.text().strip()
        
        if not expr or not var:
            return
            
        self.compute_btn.setEnabled(False)
        self.compute_btn.setText("Computing...")
        self.trigger_compute(expr, op, var)

    def on_result(self, result):
        op = result["op"]
        expr_latex = result["expr_latex"]
        result_latex = result["result_latex"]
        plot_data = result["plot_data"]
        var_str = result["var_str"]

        try:
            import matplotlib.pyplot as plt
            plt.close('all')
        except Exception:
            pass
        self.ax.clear()
        
        # Restore styles
        self.ax.set_facecolor(theme.bg)
        self.ax.tick_params(colors=theme.text_dim, labelsize=10)
        self.ax.xaxis.label.set_color(theme.text_dim)
        self.ax.yaxis.label.set_color(theme.text_dim)
        for spine in self.ax.spines.values():
            spine.set_edgecolor(theme.border)

        if op == "Plot" and plot_data:
            self.ax.axis('on')
            x, y = plot_data
            self.ax.grid(True, color=theme.border, linestyle="--", linewidth=0.5)
            self.ax.plot(x, y, color=theme.accent, linewidth=2, label=f"$f({var_str}) = {expr_latex}$")
            self.ax.legend(facecolor=theme.surface_2, edgecolor=theme.border, labelcolor=theme.text)
            self.ax.set_xlabel(var_str)
            self.ax.set_ylabel(f"f({var_str})")
        else:
            self.ax.axis('off')
            if op == "Solve":
                formula = f"\\text{{Solve: }} {expr_latex} = 0 \\\\ \\implies {var_str} = {result_latex}"
            elif op == "Differentiate":
                formula = f"\\frac{{d}}{{d{var_str}}} \\left( {expr_latex} \\right) = {result_latex}"
            elif op == "Integrate":
                formula = f"\\int \\left( {expr_latex} \\right) d{var_str} = {result_latex} + C"
            else:
                formula = f"{expr_latex} \\implies {result_latex}"

            self.ax.text(
                0.5, 0.5, 
                f"${formula}$", 
                horizontalalignment='center',
                verticalalignment='center',
                fontsize=14,
                color=theme.text,
                transform=self.ax.transAxes
            )

        self.refresh_canvas()
        self.compute_btn.setEnabled(True)
        self.compute_btn.setText("Compute")

    def on_error(self, error_msg: str):
        super().on_error(error_msg)
        self.ax.clear()
        self.ax.axis('off')
        self.ax.text(
            0.5, 0.5,
            f"Error: {error_msg}",
            horizontalalignment='center',
            verticalalignment='center',
            fontsize=12,
            color=theme.error,
            transform=self.ax.transAxes
        )
        self.refresh_canvas()
        self.compute_btn.setEnabled(True)
        self.compute_btn.setText("Compute")


if __name__ == "__main__":
    from desktop.env import init_qt_environment
    init_qt_environment()
    app = QApplication(sys.argv)
    w = MathPanel()
    w.resize(900, 600)
    w.setWindowTitle("Xeno OS — Math Panel Test")
    w.show()
    sys.exit(app.exec())
