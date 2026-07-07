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

ensure_python_env

exec "$PYTHON_BIN" "$ROOT_DIR/simulators/kuksa_value_simulator.py"
