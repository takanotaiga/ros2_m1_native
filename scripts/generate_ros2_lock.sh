#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

FULL_UPDATE=0

usage() {
  cat <<'EOF'
Usage: scripts/generate_ros2_lock.sh [--all]

Default behavior:
  Update ros2.lock.repos only for repositories that exist in ros2.repos
  but are missing in ros2.lock.repos.

Options:
  --all    Regenerate lock entries for all repositories in ros2.repos.
EOF
}

while (($# > 0)); do
  case "$1" in
    --all)
      FULL_UPDATE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

"${ROOT_DIR}/scripts/bootstrap_python.sh"

mkdir -p "${ROOT_DIR}/src"

LOCK_ARGS=(
  --manifest "${ROOT_DIR}/ros2.repos" \
  --lock-manifest "${ROOT_DIR}/ros2.lock.repos" \
  --src-root "${ROOT_DIR}/src"
)
if [[ "${FULL_UPDATE}" == "1" ]]; then
  LOCK_ARGS+=(--all)
fi

uv run python "${ROOT_DIR}/scripts/generate_ros2_lock.py" "${LOCK_ARGS[@]}"
uv run python "${ROOT_DIR}/scripts/check_repos_pinned.py" "${ROOT_DIR}/ros2.lock.repos"

if [[ "${FULL_UPDATE}" == "1" ]]; then
  echo "Generated ${ROOT_DIR}/ros2.lock.repos (full update)"
else
  echo "Updated ${ROOT_DIR}/ros2.lock.repos (diff mode)"
fi
