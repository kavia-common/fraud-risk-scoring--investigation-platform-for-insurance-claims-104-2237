#!/usr/bin/env bash
set -euo pipefail
# Validation: start server in own process group, probe with venv python+httpx (fallback curl), capture logs, terminate PG
WS="/home/kavia/workspace/code-generation/fraud-risk-scoring--investigation-platform-for-insurance-claims-104-2237/BackendAPI(FastAPI)"
cd "$WS"
LOG="$WS/server.log"
UV_BIN="$WS/.venv/bin/uvicorn"
PY_VENV="$WS/.venv/bin/python"
# if venv python missing, try system python3
PY_SYS="$(command -v python3 || true)"
export PYTHONUNBUFFERED=1
# Start server in its own process group and redirect logs
if [ -x "$UV_BIN" ]; then
  setsid "$UV_BIN" main:app --host 0.0.0.0 --port 8000 >"$LOG" 2>&1 &
else
  # prefer system uvicorn if available on PATH
  if command -v uvicorn >/dev/null 2>&1; then
    setsid uvicorn main:app --host 0.0.0.0 --port 8000 >"$LOG" 2>&1 &
  else
    echo "ERROR: uvicorn not found in .venv or PATH" >&2
    exit 2
  fi
fi
PID=$!
# capture process group id
PGID=$(ps -o pgid= -p "$PID" | tr -d ' ')
# ensure cleanup of entire process group on exit
trap 'if [ -n "${PGID:-}" ]; then kill -TERM -"$PGID" 2>/dev/null || true; fi; wait "$PID" 2>/dev/null || true' EXIT
# readiness probe: prefer venv python+httpx; fallback to curl
READY=0
for i in $(seq 1 40); do
  if [ -x "$PY_VENV" ]; then
    # run probe in venv
    "$PY_VENV" - <<'PY' && PROBE=0 || PROBE=$?
import sys
try:
    import httpx
    r = httpx.get('http://127.0.0.1:8000/health', timeout=1.0)
    sys.exit(0 if r.status_code==200 else 2)
except Exception:
    sys.exit(2)
PY
    if [ "${PROBE:-1}" -eq 0 ]; then READY=1; break; fi
  else
    if command -v curl >/dev/null 2>&1; then
      if curl -sS --fail http://127.0.0.1:8000/health >/dev/null 2>&1; then READY=1; break; fi
    fi
  fi
  sleep 0.5
  # if server died, abort and show logs
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "ERROR: server process exited prematurely; see log:" >&2
    tail -n 200 "$LOG" >&2 || true
    exit 3
  fi
done
if [ "$READY" -ne 1 ]; then
  echo "ERROR: server not responding after timeout; log tail:" >&2
  tail -n 200 "$LOG" >&2 || true
  exit 4
fi
# final health check using venv python if available
if [ -x "$PY_VENV" ]; then
  "$PY_VENV" - <<'PY' || { echo "ERROR: final probe failed" >&2; exit 5; }
import httpx, sys
try:
    r = httpx.get('http://127.0.0.1:8000/health', timeout=2.0)
    print('status_code=', r.status_code)
    print('body=', r.text)
except Exception as e:
    print('probe failed:', e, file=sys.stderr); sys.exit(2)
PY
else
  echo "INFO: venv python not available for final probe; using curl" >&2
  curl -sS --fail http://127.0.0.1:8000/health || { echo "ERROR: curl probe failed" >&2; exit 6; }
fi
# stop server process group
if [ -n "${PGID:-}" ]; then
  kill -TERM -"$PGID" 2>/dev/null || true
fi
wait "$PID" 2>/dev/null || true
# show log excerpt for inspection
tail -n 200 "$LOG" || true
exit 0
