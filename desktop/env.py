import os
import subprocess
import sys

def init_qt_environment():
    """
    Ensure PySide6 / Qt / WebEngine / Matplotlib / VTK apps run reliably
    without blank screens in Virtual Machines (QEMU/KVM/VirtualBox) or standalone terminals.
    """
    # 1. Detect if running in VM or if software rendering is requested
    is_vm = False
    try:
        res = subprocess.run(["systemd-detect-virt"], capture_output=True, text=True, timeout=1)
        if res.returncode == 0 and res.stdout.strip() not in ("none", ""):
            is_vm = True
    except Exception:
        is_vm = True

    if is_vm or os.environ.get("XENO_FORCE_SOFTWARE_RENDER") == "1":
        os.environ.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
        os.environ.setdefault("QT_QUICK_BACKEND", "software")
        os.environ.setdefault("GALLIUM_DRIVER", "llvmpipe")
        os.environ.setdefault("MESA_LOADER_DRIVER_OVERRIDE", "softpipe")
        os.environ.setdefault("QTWEBENGINE_DISABLE_GPU", "1")
        os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu --disable-software-rasterizer=false")

    # 2. QPA Platform fallback
    if "QT_QPA_PLATFORM" not in os.environ:
        if os.environ.get("WAYLAND_DISPLAY"):
            os.environ["QT_QPA_PLATFORM"] = "wayland;xcb"
        elif os.environ.get("DISPLAY"):
            os.environ["QT_QPA_PLATFORM"] = "xcb"
        else:
            # Unset display (e.g. TTY3 without export) -> default to offscreen to prevent silent crashes
            os.environ["QT_QPA_PLATFORM"] = "offscreen"
