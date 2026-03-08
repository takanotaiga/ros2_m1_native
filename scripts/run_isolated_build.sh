#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

env -i \
  HOME="${HOME}" \
  USER="${USER}" \
  LOGNAME="${LOGNAME:-${USER}}" \
  TMPDIR="${TMPDIR:-/tmp}" \
  CLEAN_BUILD="${CLEAN_BUILD:-1}" \
  PATH="${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  /bin/bash -c "cd '${ROOT_DIR}' && ./scripts/build_local.sh"
