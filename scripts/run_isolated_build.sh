#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

UV_BIN_PATH="$(command -v uv || true)"
if [[ -z "${UV_BIN_PATH}" ]]; then
  echo "ERROR: uv is required but not found in current PATH before isolation." >&2
  exit 1
fi
UV_BIN_DIR="$(cd "$(dirname "${UV_BIN_PATH}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
ISOLATED_BUILD_LOG="${BUILD_DIR}/isolated_build.log"

mkdir -p "${BUILD_DIR}"
rm -f "${ISOLATED_BUILD_LOG}"

env -i \
  HOME="${HOME}" \
  USER="${USER}" \
  LOGNAME="${LOGNAME:-${USER}}" \
  TMPDIR="${TMPDIR:-/tmp}" \
  CLEAN_BUILD="${CLEAN_BUILD:-1}" \
  PATH="${HOME}/.local/bin:${UV_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin" \
  /bin/bash -c "cd '${ROOT_DIR}' && ./scripts/build_local.sh" \
  2>&1 | tee "${ISOLATED_BUILD_LOG}"
