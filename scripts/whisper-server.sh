#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/python-env.sh
source "$ROOT_DIR/scripts/python-env.sh"

if activate_shared_python; then
  echo "[whisper] activated shared env: $(shared_python_venv)"
else
  echo "[whisper] shared env not found at $(shared_python_venv); using system Python" >&2
fi

PYTHON_BIN="$(detect_python_bin || true)"
if [[ -z "${PYTHON_BIN:-}" ]]; then
  echo "[whisper] ERROR: Python interpreter not found." >&2
  exit 1
fi

exec "$PYTHON_BIN" "$ROOT_DIR/scripts/whisper-server.py" "$@"
