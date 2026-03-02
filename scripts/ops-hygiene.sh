#!/usr/bin/env bash
set -euo pipefail
cd "/Users/pavelk/Documents/GitHub/openclaw"
docker compose run --rm openclaw-cli sessions cleanup --enforce --fix-missing
docker compose run --rm openclaw-cli doctor --fix
