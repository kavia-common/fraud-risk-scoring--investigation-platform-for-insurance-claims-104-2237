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
