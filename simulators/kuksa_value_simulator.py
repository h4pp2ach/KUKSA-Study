#!/usr/bin/env python3
import os
import sys
from datetime import datetime, timezone

from kuksa_client.grpc import Datapoint, VSSClient, VSSClientError


DEFAULT_HOST = os.environ.get("KUKSA_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("KUKSA_PORT", "55555"))

BACK_COMMANDS = {"b", "back", "뒤로"}
EXIT_COMMANDS = {"q", "quit", "exit", "종료"}


def load_token(token=None, token_file=None):
    if token_file:
        return token_file.read_text(encoding="utf-8").strip()

    return token


def make_datapoint(value):
    return Datapoint(value=value, timestamp=datetime.now(timezone.utc))


def publish_values(client, values, use_target_values=False):
    updates = {path: make_datapoint(value) for path, value in values.items()}

    if use_target_values:
        client.set_target_values(updates)
    else:
        client.set_current_values(updates)


def parse_float(value, label):
    try:
        return float(value)
    except (TypeError, ValueError):
        raise ValueError(f"{label} 값은 숫자로 입력해주세요.")


def parse_speed(value):
    speed = parse_float(value, "Speed")
    if speed < 0:
        raise ValueError("Speed 값은 0 이상이어야 합니다.")

    return speed


def parse_battery(value):
    battery = parse_float(value, "Battery")
    if not 0 <= battery <= 100:
        raise ValueError("Battery 값은 0부터 100 사이여야 합니다.")

    return battery


def parse_gear(value):
    gear_values = {
        "P": 126,
        "R": -1,
        "N": 0,
        "D": 127,
    }
    gear = str(value).strip().upper()

    if gear not in gear_values:
        raise ValueError("Gear 값은 P, R, N, D 중 하나로 입력해주세요.")

    return gear_values[gear]


SIGNALS = {
    "1": {
        "label": "Speed",
        "path": os.environ.get("KUKSA_SPEED_PATH", "Vehicle.Speed"),
        "parse": parse_speed,
    },
    "2": {
        "label": "Battery",
        "path": os.environ.get(
            "KUKSA_BATTERY_PATH",
            "Vehicle.Powertrain.TractionBattery.StateOfCharge.Current",
        ),
        "parse": parse_battery,
    },
    "3": {
        "label": "Gear",
        "path": os.environ.get(
            "KUKSA_GEAR_PATH",
            "Vehicle.Powertrain.Transmission.CurrentGear",
        ),
        "parse": parse_gear,
    },
}


def print_menu():
    print()
    print("KUKSA Value Simulator")
    print("---------------------")
    for key, signal in SIGNALS.items():
        print(f"{key}. {signal['label']} ({signal['path']})")
    print("q. 종료")


def read_input(prompt):
    return input(prompt).strip()


def is_exit(value):
    return value.lower() in EXIT_COMMANDS


def is_back(value):
    return value.lower() in BACK_COMMANDS


def send_signal(client, signal):
    label = signal["label"]
    path = signal["path"]

    while True:
        value = read_input(f"{label} 값 입력 (b=뒤로, q=종료): ")

        if is_exit(value):
            return "exit"

        if is_back(value):
            return "back"

        if value == "":
            print("값을 입력해주세요.")
            continue

        try:
            parsed_value = signal["parse"](value)
        except ValueError as exc:
            print(f"입력 오류: {exc}")
            continue

        try:
            publish_values(client, {path: parsed_value})
        except (ValueError, VSSClientError, OSError) as exc:
            print(f"전송 실패: {exc}")
            continue

        print(f"sent: {path}={parsed_value}")


def run_cli(client):
    while True:
        print_menu()
        choice = read_input("선택: ")

        if is_exit(choice):
            return

        if choice not in SIGNALS:
            print("1, 2, 3 또는 q를 입력해주세요.")
            continue

        result = send_signal(client, SIGNALS[choice])
        if result == "exit":
            return


def main():
    host = DEFAULT_HOST
    port = DEFAULT_PORT

    print(f"Connecting to KUKSA Databroker: {host}:{port}")

    try:
        with VSSClient(host, port) as client:
            print("Connected.")
            run_cli(client)

    except KeyboardInterrupt:
        print("\nStopped.")
        return 0
    except VSSClientError as exc:
        print(f"KUKSA error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"Connection error: {exc}", file=sys.stderr)
        return 1

    print("Bye.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
