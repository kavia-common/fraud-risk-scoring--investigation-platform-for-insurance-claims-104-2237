#!/usr/bin/env bash
set -euo pipefail
export PYTHONUNBUFFERED=1
WS="${PROJECT_WORKSPACE:-$PWD}"
UV_BIN="$WS/.venv/bin/uvicorn"
if [ -x "$UV_BIN" ]; then
  exec "$UV_BIN" main:app --host 0.0.0.0 --port 8000
else
  exec uvicorn main:app --host 0.0.0.0 --port 8000
fi
