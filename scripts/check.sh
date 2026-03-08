#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# shellcheck source=scripts/python-env.sh
source "$ROOT_DIR/scripts/python-env.sh"

print_header() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

require_cmd() {
  local cmd="$1"
  local install_hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' was not found."
    echo "Install hint: $install_hint"
    exit 1
  fi
}

require_python_module() {
  local module="$1"
  local install_hint="$2"
  if ! "$PYTHON_BIN" -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec(\"$module\") else 1)"; then
    echo "ERROR: required python module '$module' was not found for $PYTHON_BIN."
    echo "Install hint: $install_hint"
    exit 1
  fi
}

has_npm_script() {
  local name="$1"
  node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
process.exit(pkg.scripts && Object.prototype.hasOwnProperty.call(pkg.scripts, process.argv[1]) ? 0 : 1);
' "$name"
}

has_python() {
  [[ -f "pyproject.toml" || -f "setup.cfg" ]] && return 0
  compgen -G "requirements*.txt" >/dev/null 2>&1 && return 0
  return 1
}

has_js() {
  [[ -f "package.json" ]]
}

should_run_mypy() {
  [[ -f "mypy.ini" || -f ".mypy.ini" ]] && return 0
  [[ -f "pyproject.toml" ]] && rg -q "^\[tool\.mypy\]" pyproject.toml && return 0
  return 1
}

if has_python; then
  print_header "Python checks"
  if activate_shared_python; then
    echo "[python] activated shared env: $(shared_python_venv)"
  else
    echo "[python] shared env not found at $(shared_python_venv); using system Python"
  fi

  PYTHON_BIN="$(detect_python_bin || true)"
  if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "ERROR: Python is required but neither 'python' nor 'python3' was found."
    exit 1
  fi
  echo "[python] interpreter: $PYTHON_BIN"

  require_python_module "pytest" "$PYTHON_BIN -m pip install pytest"
  require_python_module "ruff" "$PYTHON_BIN -m pip install ruff"
  require_python_module "black" "$PYTHON_BIN -m pip install black"

  echo "[python] pytest"
  "$PYTHON_BIN" -m pytest

  echo "[python] ruff check ."
  "$PYTHON_BIN" -m ruff check .

  echo "[python] black --check ."
  "$PYTHON_BIN" -m black --check .

  if should_run_mypy; then
    require_python_module "mypy" "$PYTHON_BIN -m pip install mypy"
    echo "[python] mypy ."
    "$PYTHON_BIN" -m mypy .
  else
    echo "[python] mypy not configured; skipping"
  fi
else
  print_header "Python checks"
  echo "No Python project files detected; skipping"
fi

if has_js; then
  print_header "JavaScript checks"
  require_cmd "npm" "Install Node.js + npm."

  if ! has_npm_script "test"; then
    echo "ERROR: package.json is missing script 'test'"
    exit 1
  fi
  if ! has_npm_script "lint"; then
    echo "ERROR: package.json is missing script 'lint'"
    exit 1
  fi

  echo "[js] npm test"
  npm test

  echo "[js] npm run lint"
  npm run lint

  if has_npm_script "typecheck"; then
    echo "[js] npm run typecheck"
    npm run typecheck
  else
    echo "[js] typecheck script not found; skipping"
  fi
else
  print_header "JavaScript checks"
  echo "No package.json detected; skipping"
fi

echo
print_header "All checks passed"
