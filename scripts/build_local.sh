#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f "${ROOT_DIR}/ros2.lock.repos" ]]; then
  echo "ERROR: ros2.lock.repos is missing. Generate it with scripts/generate_ros2_lock.sh." >&2
  exit 1
fi

"${ROOT_DIR}/scripts/bootstrap_python.sh"
"${ROOT_DIR}/scripts/bootstrap_tools.sh"
"${ROOT_DIR}/scripts/bootstrap_native_deps.sh"
source "${ROOT_DIR}/scripts/activate_env.sh"

uv run python "${ROOT_DIR}/scripts/check_repos_pinned.py" \
  "${ROOT_DIR}/third_party.repos" \
  "${ROOT_DIR}/ros2.lock.repos"

"${ROOT_DIR}/scripts/sync_ros2_sources.sh"
"${ROOT_DIR}/scripts/apply_local_patches.sh"

if [[ "${CLEAN_BUILD:-1}" == "1" ]]; then
  rm -rf "${ROOT_DIR}/build" "${ROOT_DIR}/install" "${ROOT_DIR}/log"
fi

SKIP_PACKAGES=()
if [[ -n "${PACKAGES_SKIP:-}" ]]; then
  for pkg in ${PACKAGES_SKIP}; do
    if [[ -n "${pkg}" ]]; then
      SKIP_PACKAGES+=("${pkg}")
    fi
  done
fi

JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
PYTHON_EXECUTABLE="${ROOT_DIR}/.venv/bin/python"
PYTHON_ROOT_DIR="$("${PYTHON_EXECUTABLE}" -c 'import sys; print(sys.base_prefix)')"
PYTHON_INCLUDE_DIR="$("${PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
PYTHON_LIBRARY="$("${PYTHON_EXECUTABLE}" -c 'import sysconfig, pathlib; print(pathlib.Path(sysconfig.get_config_var("LIBDIR")) / sysconfig.get_config_var("LDLIBRARY"))')"
BUILD_CMD=(
  uv run colcon build
  --base-paths "${ROOT_DIR}/src"
  --merge-install
  --symlink-install
  --parallel-workers "${JOBS}"
)

if (( ${#SKIP_PACKAGES[@]} > 0 )); then
  echo "Skipping packages:"
  printf '  %s\n' "${SKIP_PACKAGES[@]}"
  BUILD_CMD+=(--packages-skip "${SKIP_PACKAGES[@]}")
fi

BUILD_CMD+=(
  --cmake-args
  -DBUILD_TESTING=OFF
  -DCMAKE_BUILD_TYPE=Release
  "-DPYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}"
  "-DPython3_EXECUTABLE=${PYTHON_EXECUTABLE}"
  "-DPython3_ROOT_DIR=${PYTHON_ROOT_DIR}"
  "-DPython3_INCLUDE_DIR=${PYTHON_INCLUDE_DIR}"
  "-DPython3_LIBRARY=${PYTHON_LIBRARY}"
  "-DPYTHON_INCLUDE_DIR=${PYTHON_INCLUDE_DIR}"
  "-DPYTHON_LIBRARY=${PYTHON_LIBRARY}"
  -Wno-dev
)

"${BUILD_CMD[@]}"

if [[ -f "${ROOT_DIR}/install/setup.bash" ]]; then
  set +u
  source "${ROOT_DIR}/install/setup.bash"
  set -u
elif [[ -f "${ROOT_DIR}/install/setup.zsh" ]]; then
  set +u
  source "${ROOT_DIR}/install/setup.zsh"
  set -u
fi
ros2 doctor --report || true
