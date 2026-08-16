import json
import os
import socket
from PySide6.QtCore import QObject, Signal, QTimer

class AvatarController(QObject):
    """
    State machine for the 3D AI Avatar.
    Bridges backend AI Voice/Command events with visual animation states.
    """
    state_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.current_state = "idle" # idle | active | thinking | threat
        self.ipc_socket = "/tmp/xeno-sense.sock"
        
        self.poll_timer = QTimer(self)
        self.poll_timer.timeout.connect(self._poll_backend)
        self.poll_timer.start(1000)

    def set_state(self, state: str):
        if state != self.current_state:
            self.current_state = state
            self.state_changed.emit(state)
            self._sync_to_shell(state)

    def _sync_to_shell(self, state: str):
        # Sync the avatar state to Astal shell state.ts via xeno-notify or IPC
        try:
            payload = json.dumps({"command": "ai:set_avatar_state", "params": {"state": state}})
            # Since shell listens on its own IPC, we'd send it if needed.
        except Exception:
            pass

    def _poll_backend(self):
        # Poll XenoSense multimodal AI backend for state changes
        if not os.path.exists(self.ipc_socket):
            return
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                s.connect(self.ipc_socket)
                s.sendall(b'{"command": "get_avatar_state"}\n')
                data = s.recv(1024)
                if data:
                    resp = json.loads(data.decode('utf-8'))
                    if "state" in resp:
                        self.set_state(resp["state"])
        except Exception:
            pass

