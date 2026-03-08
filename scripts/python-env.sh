#!/usr/bin/env bash

shared_python_venv() {
  if [[ -n "${SHARED_PYTHON_VENV:-}" ]]; then
    printf "%s\n" "$SHARED_PYTHON_VENV"
  else
    printf "%s\n" "$HOME/.virtualenvs/shared-python"
  fi
}

activate_shared_python() {
  local venv
  venv="$(shared_python_venv)"
  if [[ -f "$venv/bin/activate" ]]; then
    # shellcheck disable=SC1090
    source "$venv/bin/activate"
    return 0
  fi
  return 1
}

detect_python_bin() {
  if command -v python >/dev/null 2>&1; then
    command -v python
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return 0
  fi
  return 1
}
