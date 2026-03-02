#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

run() {
  log "RUN: $*"
  "$@"
}

log "OpenClaw ops check start"

run docker compose ps
run docker compose run --rm openclaw-cli status --all
run docker compose run --rm openclaw-cli doctor
run docker compose run --rm openclaw-cli security audit --deep
run docker compose run --rm openclaw-cli devices list --json

log "Recent gateway warnings (if any)"
docker compose logs --tail=200 openclaw-gateway | rg -n "pairing required|Unhandled stop reason| 402 " || true

log "OpenClaw ops check complete"
