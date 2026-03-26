#!/usr/bin/env bash
set -euo pipefail
# Prepare Python venv and persist dev env vars (idempotent)
WORKSPACE="/home/kavia/workspace/code-generation/fraud-risk-scoring--investigation-platform-for-insurance-claims-104-2237/BackendAPI(FastAPI)"
VENV_DIR="$WORKSPACE/.venv"
mkdir -p "$WORKSPACE"
# Ensure python3-venv package exists (idempotent)
if ! dpkg -s python3-venv >/dev/null 2>&1; then sudo apt-get update -q && sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq python3-venv; fi
# Create venv if missing
if [ ! -d "$VENV_DIR" ]; then python3 -m venv "$VENV_DIR"; fi
# Ensure pip/tooling inside venv
"$VENV_DIR/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null
# If running as root and SUDO_USER is set, chown venv to that user (guarded, non-fatal)
if [ "${SUDO_USER-}" ] && [ "$(id -u)" -eq 0 ]; then
  sudo chown -R "$SUDO_USER":"$SUDO_USER" "$VENV_DIR" || true
fi
# Persist development env vars with expanded absolute paths (safe under sudo)
PROFILE_FILE="/etc/profile.d/fastapi_dev.sh"
sudo tee "$PROFILE_FILE" >/dev/null <<EOF
# FastAPI development environment (dev only)
export FASTAPI_ENV=development
export DATABASE_URL="sqlite:///$WORKSPACE/dev.db"
export PATH="$VENV_DIR/bin:$PATH"
EOF
sudo chmod 644 "$PROFILE_FILE"
# Validate venv python is usable
"$VENV_DIR/bin/python" -V >/dev/null
