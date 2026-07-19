#!/usr/bin/env python3
import sys
import socket
import json

SOCKET_PATH = "/tmp/xeno-ipc.sock"

def send_ipc(payload):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps(payload).encode('utf-8'))
        s.shutdown(socket.SHUT_WR)
        chunks = []
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
        resp = b"".join(chunks)
        s.close()
        return json.loads(resp.decode('utf-8'))
    except Exception as e:
        print(f"Error connecting to IPC socket at {SOCKET_PATH}: {e}")
        print("Make sure the desktop shell is running (bash sandbox.sh)")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 trigger.py toggle      - Toggles the app launcher overlay")
        print("  python3 trigger.py notify TITLE BODY - Sends a neon toast notification")
        sys.exit(1)
        
    action = sys.argv[1]
    if action == "toggle":
        res = send_ipc({"command": "status_bar:toggle_launcher"})
        print("Response:", res)
    elif action == "notify":
        if len(sys.argv) < 4:
            print("Usage: python3 trigger.py notify TITLE BODY")
            sys.exit(1)
        title = sys.argv[2]
        body = sys.argv[3]
        res = send_ipc({"command": "notification:send", "params": {"title": title, "body": body}})
        print("Response:", res)
    else:
        print(f"Unknown action: {action}")

if __name__ == "__main__":
    main()
