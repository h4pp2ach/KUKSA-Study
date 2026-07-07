#!/usr/bin/env bash
set -euo pipefail

resolve_script_dir() {
  local source="$1"
  while [ -L "$source" ]; do
    local dir
    dir="$(cd -P -- "$(dirname -- "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  cd -P -- "$(dirname -- "$source")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common.sh"

KUKSA_HOST="${KUKSA_HOST:-127.0.0.1}"
KUKSA_PORT="${KUKSA_PORT:-55555}"
KUKSA_BRIDGE_HOST="${KUKSA_BRIDGE_HOST:-127.0.0.1}"
KUKSA_BRIDGE_PORT="${KUKSA_BRIDGE_PORT:-55556}"
KUKSA_DATABROKER_IMAGE="${KUKSA_DATABROKER_IMAGE:-ghcr.io/eclipse-kuksa/kuksa-databroker:main}"
KUKSA_CONTAINER_NAME="${KUKSA_CONTAINER_NAME:-kuksa-databroker-dev}"

DATABROKER_PID=""
BRIDGE_PID=""

cleanup() {
  echo
  echo "[core] stopping..."

  if [ -n "${KUKSA_CORE_READY_FILE:-}" ]; then
    rm -f "$KUKSA_CORE_READY_FILE"
  fi

  if [ -n "$BRIDGE_PID" ]; then
    kill "$BRIDGE_PID" >/dev/null 2>&1 || true
  fi

  if [ -n "${DOCKER_CMD[*]:-}" ]; then
    "${DOCKER_CMD[@]}" rm -f "$KUKSA_CONTAINER_NAME" >/dev/null 2>&1 || true
  fi

  if [ -n "$DATABROKER_PID" ]; then
    wait "$DATABROKER_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

ensure_python_env
resolve_docker_cmd

if "${DOCKER_CMD[@]}" ps -a --format '{{.Names}}' | grep -qx "$KUKSA_CONTAINER_NAME"; then
  die "container '$KUKSA_CONTAINER_NAME' already exists"
fi

echo "[core] starting databroker: $KUKSA_DATABROKER_IMAGE"
"${DOCKER_CMD[@]}" run --rm \
  --name "$KUKSA_CONTAINER_NAME" \
  -p "$KUKSA_PORT:55555" \
  "$KUKSA_DATABROKER_IMAGE" \
  --insecure &
DATABROKER_PID="$!"

echo "[core] waiting for KUKSA Databroker on $KUKSA_HOST:$KUKSA_PORT"
if ! wait_for_tcp "$KUKSA_HOST" "$KUKSA_PORT" 45; then
  die "databroker did not become reachable on $KUKSA_HOST:$KUKSA_PORT"
fi

export KUKSA_HOST
export KUKSA_PORT
export KUKSA_BRIDGE_HOST
export KUKSA_BRIDGE_PORT

echo "[core] starting bridge on $KUKSA_BRIDGE_HOST:$KUKSA_BRIDGE_PORT"
"$PYTHON_BIN" "$ROOT_DIR/bridges/kuksa_to_tcp.py" &
BRIDGE_PID="$!"

echo "[core] ready"
if [ -n "${KUKSA_CORE_READY_FILE:-}" ]; then
  mkdir -p "$(dirname "$KUKSA_CORE_READY_FILE")"
  : > "$KUKSA_CORE_READY_FILE"
fi

sleep 2
echo "[core] run cluster:          ./run-cluster"
echo "[core] run KUKSA simulator:  ./run-kuksa-simulator"
echo "[core] press Ctrl+C to stop databroker and bridge"

wait -n "$DATABROKER_PID" "$BRIDGE_PID"
