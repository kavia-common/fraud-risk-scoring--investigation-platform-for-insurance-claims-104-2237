#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/fraud-risk-scoring--investigation-platform-for-insurance-claims-104-2237/BackendAPI(FastAPI)"
cd "$WS"
mkdir -p "$WS/tests"
# unit test using TestClient (requests-backed)
cat > "$WS/tests/test_health.py" <<'PY'
from fastapi.testclient import TestClient
from main import app

def test_health():
    client = TestClient(app)
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json().get('status') == 'ok'
PY
# optional guidance file for integration test (server must be running)
cat > "$WS/tests/INTEGRATION.md" <<'MD'
# Integration test guidance
# Use httpx to probe the running server: httpx.get('http://127.0.0.1:8000/health')
# Example (uncomment when server is running in CI):
# import httpx
# def test_health_integration():
#     r = httpx.get('http://127.0.0.1:8000/health', timeout=5)
#     assert r.status_code == 200
#     assert r.json().get('status') == 'ok'
MD
# Run pytest using venv binary
if [ -x "$WS/.venv/bin/pytest" ]; then
  "$WS/.venv/bin/pytest" tests -q || { echo "ERROR: pytest failed" >&2; exit 2; }
else
  echo "ERROR: venv pytest not found at $WS/.venv/bin/pytest" >&2
  exit 3
fi
exit 0
