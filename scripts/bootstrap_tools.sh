#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
THIRD_PARTY_SRC_DIR="${ROOT_DIR}/.deps/third_party"
CMAKE_SRC_DIR="${THIRD_PARTY_SRC_DIR}/kitware/cmake"
CMAKE_PREFIX="${ROOT_DIR}/.local/tools/cmake"
CMAKE_BIN="${CMAKE_PREFIX}/bin/cmake"
CMAKE_BUILD_DIR="${ROOT_DIR}/.build/cmake"

"${ROOT_DIR}/scripts/bootstrap_python.sh"
uv run python "${ROOT_DIR}/scripts/check_repos_pinned.py" "${ROOT_DIR}/third_party.repos"
uv run python "${ROOT_DIR}/scripts/sync_git_repos.py" \
  --manifest "${ROOT_DIR}/third_party.repos" \
  --root "${THIRD_PARTY_SRC_DIR}"

if [[ -x "${CMAKE_BIN}" ]]; then
  "${CMAKE_BIN}" --version
  echo "Local CMake already present. Skipping rebuild."
  exit 0
fi

rm -rf "${CMAKE_BUILD_DIR}"
mkdir -p "${CMAKE_BUILD_DIR}" "${CMAKE_PREFIX}"
cd "${CMAKE_BUILD_DIR}"

"${CMAKE_SRC_DIR}/bootstrap" \
  --prefix="${CMAKE_PREFIX}" \
  --parallel="${JOBS}" \
  -- \
  -DCMAKE_USE_OPENSSL=OFF

make -j"${JOBS}"
make install

"${CMAKE_BIN}" --version
