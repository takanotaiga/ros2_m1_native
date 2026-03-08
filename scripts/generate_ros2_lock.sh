#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

"${ROOT_DIR}/scripts/bootstrap_python.sh"

mkdir -p "${ROOT_DIR}/src"

uv run python "${ROOT_DIR}/scripts/sync_git_repos.py" \
  --manifest "${ROOT_DIR}/ros2.repos" \
  --root "${ROOT_DIR}/src" \
  --allow-non-pinned

uv run vcs export --exact "${ROOT_DIR}/src" > "${ROOT_DIR}/ros2.lock.repos"
uv run python "${ROOT_DIR}/scripts/check_repos_pinned.py" "${ROOT_DIR}/ros2.lock.repos"

echo "Generated ${ROOT_DIR}/ros2.lock.repos"
