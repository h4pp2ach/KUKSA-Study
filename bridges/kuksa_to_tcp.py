import json
import math
import socket
import time

from kuksa_client.grpc import VSSClient

HOST = "127.0.0.1"
PORT = 55556

KUKSA_HOST = "127.0.0.1"
KUKSA_PORT = 55555

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((HOST, PORT))
server.listen(1)

print(f"[KUKSA Bridge] Listening on {HOST}:{PORT}")
conn, addr = server.accept()
print(f"[KUKSA Bridge] Qt client connected: {addr}")

t = 0

try:
    with VSSClient(KUKSA_HOST, KUKSA_PORT) as client:
        for updates in client.subscribe_current_values(["Vehicle.Speed"]):
            speed = updates["Vehicle.Speed"].value

            if speed is None:
                speed = 0
            battery = 10
            gear = "P"

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
    print("[KUKSA Bridge] Qt client disconnected")

except KeyboardInterrupt:
    print("\n[KUKSA Bridge] Stopped")

finally:
    conn.close()
    server.close()
