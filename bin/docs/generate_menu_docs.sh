#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"

if ! command -v "$PYTHON" >/dev/null 2>&1; then
    if command -v python >/dev/null 2>&1; then
        PYTHON="python"
    else
        echo "[ERROR] Python 3 not found in PATH." >&2
        exit 1
    fi
fi

exec "$PYTHON" "$SCRIPT_DIR/generate_menu_docs.py" "$@"
