#!/usr/bin/env bash
set -euo pipefail
WS="${PROJECT_WORKSPACE:-$PWD}"
PY="$WS/.venv/bin/python"
CELERY_BIN="$WS/.venv/bin/celery"
if [ ! -x "$PY" ]; then
  PY="$(command -v python3 || true)"
fi
# validate celery_app.import
if [ -x "$PY" ]; then
  "$PY" - <<'PY' || { echo "ERROR: celery_app.app is not importable or is None" >&2; exit 2; }
import sys
try:
    import celery_app
    if getattr(celery_app, 'app', None) is None:
        print('celery_app.app is None', file=sys.stderr); sys.exit(2)
except Exception as e:
    print('import error:', e, file=sys.stderr); sys.exit(2)
sys.exit(0)
PY
else
  echo "ERROR: no python available to validate celery_app" >&2; exit 3
fi
# probe Redis
"$PY" - <<'PY' || PROBE_EXIT=$?
import socket,sys
s=socket.socket()
try:
    s.settimeout(0.5)
    s.connect(('127.0.0.1', 6379))
    sys.exit(0)
except Exception:
    sys.exit(2)
finally:
    try: s.close()
    except: pass
PY
PROBE_EXIT=${PROBE_EXIT:-0}
if [ "$PROBE_EXIT" -eq 0 ]; then
  if [ -x "$CELERY_BIN" ]; then
    exec "$CELERY_BIN" -A celery_app.app worker --loglevel=info
  else
    if command -v celery >/dev/null 2>&1; then
      exec celery -A celery_app.app worker --loglevel=info
    else
      echo "ERROR: celery binary not found; cannot start worker" >&2; exit 4
    fi
  fi
else
  echo "INFO: Redis not reachable; skipping celery worker. Tasks should execute synchronously in this dev environment." >&2
  exit 0
fi
