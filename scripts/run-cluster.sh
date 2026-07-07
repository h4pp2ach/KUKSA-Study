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

APP_DIR="$ROOT_DIR/apps/cluster-qt"
BUILD_DIR="${CLUSTER_BUILD_DIR:-$ROOT_DIR/build/cluster-qt}"
QMAKE_BIN="${QMAKE_BIN:-}"

if [ -z "$QMAKE_BIN" ]; then
  if command -v qmake6 >/dev/null 2>&1; then
    QMAKE_BIN="qmake6"
  elif command -v qmake >/dev/null 2>&1; then
    QMAKE_BIN="qmake"
  else
    die "qmake6 or qmake is required to build the Qt cluster app"
  fi
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[cluster] configuring with $QMAKE_BIN"
"$QMAKE_BIN" "$APP_DIR/Car_1.pro"
echo "[cluster] building"
make -j"$(nproc)"

exec "$BUILD_DIR/Car_1"
