#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SCRIPT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PYTHON_BIN="$ROOT_DIR/.venv/bin/python"

die() {
  echo "error: $*" >&2
  exit 1
}

ensure_python_env() {
  if [ ! -x "$PYTHON_BIN" ]; then
    echo "[setup] creating virtual environment: $ROOT_DIR/.venv"
    python3 -m venv "$ROOT_DIR/.venv"
  fi

  if ! "$PYTHON_BIN" -c "import kuksa_client" >/dev/null 2>&1; then
    echo "[setup] installing Python requirements"
    "$PYTHON_BIN" -m pip install -r "$ROOT_DIR/requirements.txt"
  fi
}

resolve_docker_cmd() {
  command -v docker >/dev/null 2>&1 || die "docker command not found"

  if docker info >/dev/null 2>&1; then
    DOCKER_CMD=(docker)
  else
    DOCKER_CMD=(sudo docker)
  fi
}

wait_for_tcp() {
  local host="$1"
  local port="$2"
  local timeout="${3:-30}"

  python3 - "$host" "$port" "$timeout" <<'PY'
import socket
import sys
import time

host = sys.argv[1]
port = int(sys.argv[2])
timeout = float(sys.argv[3])
deadline = time.monotonic() + timeout

while time.monotonic() < deadline:
    try:
        with socket.create_connection((host, port), timeout=1):
            sys.exit(0)
    except OSError:
        time.sleep(0.25)

sys.exit(1)
PY
}
