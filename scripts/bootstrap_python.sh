#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/uv.lock" ]]; then
  echo "uv.lock not found. Generating lockfile with Python 3.11..."
  uv lock --python 3.11
fi

uv sync --frozen --python 3.11
uv run python --version
