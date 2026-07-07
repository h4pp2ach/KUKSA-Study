import json
import os
import socket
import time

from kuksa_client.grpc import VSSClient

HOST = os.environ.get("KUKSA_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("KUKSA_BRIDGE_PORT", "55556"))

KUKSA_HOST = os.environ.get("KUKSA_HOST", "127.0.0.1")
KUKSA_PORT = int(os.environ.get("KUKSA_PORT", "55555"))

SPEED_PATH = os.environ.get("KUKSA_SPEED_PATH", "Vehicle.Speed")
BATTERY_PATH = os.environ.get(
    "KUKSA_BATTERY_PATH",
    "Vehicle.Powertrain.TractionBattery.StateOfCharge.Current",
)
GEAR_PATH = os.environ.get(
    "KUKSA_GEAR_PATH",
    "Vehicle.Powertrain.Transmission.CurrentGear",
)
SUBSCRIBED_PATHS = [SPEED_PATH, BATTERY_PATH, GEAR_PATH]


def to_float(value, fallback):
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


def normalize_gear(value):
    if value is None:
        return "P"

    try:
        gear = int(value)
    except (TypeError, ValueError):
        gear = str(value).strip().upper()
        return gear if gear in ("P", "R", "N", "D") else "P"

    if gear == 0:
        return "N"
    if gear == 126:
        return "P"
    if gear < 0:
        return "R"

    return "D"


def make_payload(state):
    speed = to_float(state.get("speed"), 0)
    battery = to_float(state.get("battery"), 10)
    gear = normalize_gear(state.get("gear"))

    return {
        "vehicleSpeed": round(max(0, speed), 1),
        "batterySoc": round(max(0, min(100, battery)), 1),
        "gear": gear,
    }


def send_payload(conn, payload):
    message = json.dumps(payload) + "\n"
    conn.sendall(message.encode("utf-8"))
    print(payload, flush=True)


def apply_update(state, path, value):
    if path == SPEED_PATH:
        state["speed"] = value
    elif path == BATTERY_PATH:
        state["battery"] = value
    elif path == GEAR_PATH:
        state["gear"] = value


def stream_kuksa_to_qt(conn):
    state = {
        "speed": 0,
        "battery": 10,
        "gear": "P",
    }

    send_payload(conn, make_payload(state))

    with VSSClient(KUKSA_HOST, KUKSA_PORT) as client:
        for updates in client.subscribe_current_values(SUBSCRIBED_PATHS):
            for path, datapoint in updates.items():
                if datapoint is None:
                    continue

                apply_update(state, path, datapoint.value)

            send_payload(conn, make_payload(state))
            time.sleep(0.1)


def serve():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((HOST, PORT))
        server.listen(5)

        print(f"[KUKSA Bridge] Listening on {HOST}:{PORT}", flush=True)

        while True:
            conn, addr = server.accept()
            print(f"[KUKSA Bridge] Qt client connected: {addr}", flush=True)

            with conn:
                try:
                    stream_kuksa_to_qt(conn)
                except (BrokenPipeError, ConnectionResetError):
                    print("[KUKSA Bridge] Qt client disconnected", flush=True)
                except KeyboardInterrupt:
                    raise
                except Exception as exc:
                    print(f"[KUKSA Bridge] Stream error: {exc}", flush=True)
                    time.sleep(1)


if __name__ == "__main__":
    try:
        serve()
    except KeyboardInterrupt:
        print("\n[KUKSA Bridge] Stopped", flush=True)
