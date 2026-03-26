#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/fraud-risk-scoring--investigation-platform-for-insurance-claims-104-2237/BackendAPI(FastAPI)"
mkdir -p "$WS"/scripts "$WS"/tests "$WS"/data && cd "$WS"
BAK_TS=$(date +%s)
backup_if_exists(){ for f in "$@"; do [ -f "$f" ] && mv "$f" "$f".bak.$BAK_TS || true; done }
# main.py
if [ -f "$WS"/main.py ]; then backup_if_exists "$WS"/main.py; fi
cat > "$WS"/main.py <<'PY'
from fastapi import FastAPI
from pydantic import BaseModel
app = FastAPI()

class Health(BaseModel):
    status: str

@app.get("/health", response_model=Health)
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "BackendAPI FastAPI scaffold"}
PY
# celery app (optional)
if [ -f "$WS"/celery_app.py ]; then backup_if_exists "$WS"/celery_app.py; fi
cat > "$WS"/celery_app.py <<'PY'
import os
try:
    from celery import Celery
except Exception:
    Celery = None

if Celery:
    broker = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0')
    app = Celery('backend', broker=broker)
else:
    app = None
PY
# requirements - include pydantic explicitly; keep unpinned minimal for dev
if [ -f "$WS"/requirements.txt ]; then backup_if_exists "$WS"/requirements.txt; fi
cat > "$WS"/requirements.txt <<'TXT'
fastapi
pydantic
uvicorn[standard]
python-dotenv
pytest
httpx
requests
celery
TXT
# .env (only create if missing)
if [ ! -f "$WS"/.env ]; then
cat > "$WS"/.env <<'ENV'
APP_ENV=development
DATABASE_URL=sqlite:///./data/data.db
CELERY_BROKER_URL=redis://localhost:6379/0
ENVIRONMENT=dev
ENV_VAR_PLACEHOLDER=1
ENV
fi
# .env.example
if [ -f "$WS"/.env.example ]; then backup_if_exists "$WS"/.env.example; fi
cat > "$WS"/.env.example <<'ENV'
APP_ENV=development
DATABASE_URL=sqlite:///./data/data.db
CELERY_BROKER_URL=redis://localhost:6379/0
ENVIRONMENT=dev
ENV_VAR_PLACEHOLDER=1
ENV
# .gitignore
if [ -f "$WS"/.gitignore ]; then backup_if_exists "$WS"/.gitignore; fi
cat > "$WS"/.gitignore <<'TXT'
.venv/
server.log
data/data.db
.env
*.bak.*
TXT
# scripts/start.sh - prefer explicit venv uvicorn binary when present
if [ -f "$WS"/scripts/start.sh ]; then backup_if_exists "$WS"/scripts/start.sh; fi
cat > "$WS"/scripts/start.sh <<'SH'
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
SH
chmod +x "$WS"/scripts/start.sh
# scripts/run_celery.sh
if [ -f "$WS"/scripts/run_celery.sh ]; then backup_if_exists "$WS"/scripts/run_celery.sh; fi
cat > "$WS"/scripts/run_celery.sh <<'SH'
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
SH
chmod +x "$WS"/scripts/run_celery.sh
# scripts/init_db.sh - optional helper to create sqlite file
if [ -f "$WS"/scripts/init_db.sh ]; then backup_if_exists "$WS"/scripts/init_db.sh; fi
cat > "$WS"/scripts/init_db.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WS="${PROJECT_WORKSPACE:-$PWD}"
mkdir -p "$WS"/data && chmod 755 "$WS"/data
DB="$WS"/data/data.db
if [ ! -f "$DB" ]; then
  sqlite3 "$DB" "PRAGMA user_version = 1;" || { echo "ERROR: failed to create sqlite db" >&2; exit 2; }
  echo "INFO: created $DB"
else
  echo "INFO: $DB already exists"
fi
SH
chmod +x "$WS"/scripts/init_db.sh
exit 0
