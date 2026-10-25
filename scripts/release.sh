#!/bin/bash
# Local and GitHub Actions entry point. No remote Git or Apple credential operations.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/release.py" "$@"
