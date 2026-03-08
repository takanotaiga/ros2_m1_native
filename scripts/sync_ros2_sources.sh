#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f "${ROOT_DIR}/ros2.lock.repos" ]]; then
  echo "ERROR: ros2.lock.repos is missing. Run scripts/generate_ros2_lock.sh first." >&2
  exit 1
fi

"${ROOT_DIR}/scripts/bootstrap_python.sh"
uv run python "${ROOT_DIR}/scripts/check_repos_pinned.py" "${ROOT_DIR}/ros2.lock.repos"
uv run python "${ROOT_DIR}/scripts/sync_git_repos.py" \
  --manifest "${ROOT_DIR}/ros2.lock.repos" \
  --root "${ROOT_DIR}/src" \
  --force-clean
