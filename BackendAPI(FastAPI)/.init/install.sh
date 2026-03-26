#!/usr/bin/env bash
set -euo pipefail

# Workspace from container info
WS="/home/kavia/workspace/code-generation/fraud-risk-scoring--investigation-platform-for-insurance-claims-104-2237/BackendAPI(FastAPI)"
cd "$WS"

# Ensure apt lists are reasonably fresh if we need to install packages
need_install=0
# check python3 venv support
if ! python3 -c "import venv" >/dev/null 2>&1; then
  need_install=1
fi
# check sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
  need_install=1
fi
if [ "$need_install" -eq 1 ]; then
  sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends python3-venv sqlite3 >/dev/null
fi
# verify python -m pip exists
if ! python3 -m pip --version >/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends python3-pip >/dev/null
fi
# write workspace export if absent (idempotent)
PROFILE=/etc/profile.d/backendapi_workspace.sh
if [ ! -f "$PROFILE" ]; then
  sudo bash -c "cat >'$PROFILE' <<'BASH'
# expose project workspace
export PROJECT_WORKSPACE='$WS'
BASH
"
fi

# create venv if missing
if [ ! -d "$WS/.venv" ]; then
  python3 -m venv "$WS/.venv" || { echo "ERROR: python3 -m venv failed" >&2; exit 3; }
fi
PY="$WS/.venv/bin/python"
PIP="$WS/.venv/bin/pip"
if [ ! -x "$PY" ]; then
  echo "ERROR: venv python missing at $PY" >&2; exit 4
fi
# upgrade pip tooling inside venv
"$PY" -m pip install --disable-pip-version-check --no-input --no-warn-script-location --upgrade pip setuptools wheel >/dev/null || { echo "ERROR: failed to upgrade pip in venv" >&2; exit 5; }
# ensure requirements.txt exists (create minimal if absent)
if [ ! -f "$WS/requirements.txt" ]; then
  cat >"$WS/requirements.txt" <<EOF
fastapi
uvicorn[standard]
httpx
pytest
pydantic
requests
EOF
fi
# install requirements deterministically
"$PIP" install --disable-pip-version-check --no-input --no-warn-script-location -r "$WS/requirements.txt" >/dev/null || { echo "ERROR: pip install -r requirements.txt failed" >&2; exit 6; }
# optional export of venv PATH
if [ "${BACKENDAPI_EXPORT_VENV:-0}" = "1" ]; then
  VENV_PROFILE=/etc/profile.d/backendapi_venv.sh
  if [ ! -f "$VENV_PROFILE" ]; then
    sudo bash -c "cat >'$VENV_PROFILE' <<'BASH'
# Add project venv to PATH (optional)
export PATH='$WS/.venv/bin:$PATH'
BASH
" || { echo "ERROR: failed to write $VENV_PROFILE" >&2; exit 7; }
  fi
fi
# validate installs via venv python
"$PY" - <<'PY'
import sys
try:
    import fastapi, pydantic, uvicorn, httpx, requests
except Exception as e:
    print('Validation import failed:', e, file=sys.stderr)
    sys.exit(2)
sys.exit(0)
PY

exit 0
