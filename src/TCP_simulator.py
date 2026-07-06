#tcp_simulator.py

import json
import math
import socket
import time

HOST = "127.0.0.1"
PORT = 55556

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((HOST, PORT))
server.listen(1)

print(f"[TCP Simulator] Listening on {HOST}:{PORT}")
conn, addr = server.accept()
print(f"[TCP Simulator] Qt client connected: {addr}")

t = 0

try:
    while True:
        speed = 80 + 70 * math.sin(t / 30.0)
        battery = 70 + 10 * math.sin(t / 80.0)

        if speed < 1:
            gear = "P"
        else:
            gear = "D"

        payload = {
            "vehicleSpeed": round(max(0, speed), 1),
            "batterySoc": round(max(0, min(100, battery)), 1),
            "gear": gear,
        }

        message = json.dumps(payload) + "\n"
        conn.sendall(message.encode("utf-8"))

        print(payload)

        t += 1
        time.sleep(0.1)

except BrokenPipeError:
    print("[TCP Simulator] Qt client disconnected")

except KeyboardInterrupt:
    print("\n[TCP Simulator] Stopped")

finally:
    conn.close()
    server.close()