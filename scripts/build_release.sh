#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

APP_PATH="${APP_PATH:-/Applications/ROS2Native.app}"
RVIZ_APP_PATH="${RVIZ_APP_PATH:-/Applications/RViz 2.app}"
RQT_APP_PATH="${RQT_APP_PATH:-/Applications/rqt.app}"
RUNTIME_PREFIX="${RUNTIME_PREFIX:-${APP_PATH}/Contents/Resources/runtime}"
RELEASE_ROOT="${ROOT_DIR}/.release"
RELEASE_BUILD_ROOT="${RELEASE_ROOT}/build"
RELEASE_LOG_ROOT="${RELEASE_ROOT}/log"
RELEASE_TOOLS_PREFIX="${RUNTIME_PREFIX}/tools/cmake"
RELEASE_NATIVE_DEPS_PREFIX="${RUNTIME_PREFIX}/deps"
RELEASE_PYTHON_HOME="${RUNTIME_PREFIX}/python"
RELEASE_PYTHON_BIN="${RELEASE_PYTHON_HOME}/bin/python3.11"
RELEASE_PYTHON_DYLIB="${RELEASE_PYTHON_HOME}/lib/libpython3.11.dylib"
RELEASE_OPENSSL_CRYPTO_LIBRARY="${RELEASE_NATIVE_DEPS_PREFIX}/lib/libcrypto.3.dylib"
RELEASE_OPENSSL_SSL_LIBRARY="${RELEASE_NATIVE_DEPS_PREFIX}/lib/libssl.3.dylib"
RELEASE_ZSTD_LIBRARY="${RELEASE_NATIVE_DEPS_PREFIX}/lib/libzstd.dylib"
RELEASE_ZSTD_VERSIONED_LIBRARY="${RELEASE_NATIVE_DEPS_PREFIX}/lib/libzstd.1.dylib"
RELEASE_ZMQ_LIBRARY="${RELEASE_NATIVE_DEPS_PREFIX}/lib/libzmq.dylib"
RELEASE_ZMQ_VERSIONED_LIBRARY="${RELEASE_NATIVE_DEPS_PREFIX}/lib/libzmq.5.dylib"
RELEASE_COLCON_BUILD_BASE="${RELEASE_BUILD_ROOT}/ros2"
RELEASE_COLCON_LOG_BASE="${RELEASE_LOG_ROOT}/colcon"
LISTENER_LOG="${RELEASE_LOG_ROOT}/listener.log"
TALKER_LOG="${RELEASE_LOG_ROOT}/talker.log"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
VERSION="$(
  awk -F'"' '/^version = / {print $2; exit}' pyproject.toml
)"

cleanup_process() {
  local pid="$1"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
    wait "${pid}" >/dev/null 2>&1 || true
  fi
}

LISTENER_PID=""
TALKER_PID=""
trap 'cleanup_process "${TALKER_PID}"; cleanup_process "${LISTENER_PID}"' EXIT

if [[ "${CLEAN_RELEASE:-1}" == "1" ]]; then
  rm -rf "${RELEASE_ROOT}" "${APP_PATH}" "${RVIZ_APP_PATH}" "${RQT_APP_PATH}"
fi

mkdir -p "${RELEASE_BUILD_ROOT}" "${RELEASE_LOG_ROOT}"

"${ROOT_DIR}/scripts/bootstrap_python.sh"
"${ROOT_DIR}/scripts/bootstrap_tools.sh"

BUILD_PYTHON="${ROOT_DIR}/.venv/bin/python"
MANAGED_PYTHON_HOME="$("${BUILD_PYTHON}" -c 'import pathlib, sys; print(pathlib.Path(sys.base_prefix))')"
UV_BIN="$(command -v uv || true)"
if [[ -z "${UV_BIN}" ]]; then
  echo "ERROR: uv is required but not found in PATH." >&2
  exit 1
fi
UV_BIN_DIR="$(dirname "${UV_BIN}")"

rm -rf "${RELEASE_PYTHON_HOME}" "${RUNTIME_PREFIX}/bin" "${RUNTIME_PREFIX}/etc" \
  "${RUNTIME_PREFIX}/include" "${RUNTIME_PREFIX}/lib" "${RUNTIME_PREFIX}/opt" "${RUNTIME_PREFIX}/share"
mkdir -p "${RUNTIME_PREFIX}"

uv run python "${ROOT_DIR}/scripts/create_macos_apps.py" \
  --main-app "${APP_PATH}" \
  --rviz-app "${RVIZ_APP_PATH}" \
  --rqt-app "${RQT_APP_PATH}" \
  --runtime-prefix "${RUNTIME_PREFIX}" \
  --version "${VERSION}"

rsync -a --delete "${MANAGED_PYTHON_HOME}/" "${RELEASE_PYTHON_HOME}/"
ln -sf python3.11 "${RELEASE_PYTHON_HOME}/bin/python"
if [[ -f "${RELEASE_PYTHON_DYLIB}" ]]; then
  install_name_tool -id "${RELEASE_PYTHON_DYLIB}" "${RELEASE_PYTHON_DYLIB}"
fi
UV_LINK_MODE=copy \
uv export --frozen --no-editable --no-emit-project --format requirements-txt | \
  uv pip install --break-system-packages --python "${RELEASE_PYTHON_BIN}" -r -

rm -rf "${RELEASE_TOOLS_PREFIX}"
mkdir -p "$(dirname "${RELEASE_TOOLS_PREFIX}")"
rsync -a --delete "${ROOT_DIR}/.local/tools/cmake/" "${RELEASE_TOOLS_PREFIX}/"

ROS2_M1_NATIVE_NATIVE_DEPS_PREFIX="${RELEASE_NATIVE_DEPS_PREFIX}" \
ROS2_M1_NATIVE_BUILD_ROOT="${RELEASE_BUILD_ROOT}/native_deps" \
ROS2_M1_NATIVE_PYTHON_EXECUTABLE="${RELEASE_PYTHON_BIN}" \
"${ROOT_DIR}/scripts/bootstrap_native_deps.sh"

source "${RUNTIME_PREFIX}/share/ros2native/activate.sh"
export PATH="${ROOT_DIR}/.venv/bin:${UV_BIN_DIR}:${PATH}"

uv run python "${ROOT_DIR}/scripts/check_repos_pinned.py" \
  "${ROOT_DIR}/third_party.repos" \
  "${ROOT_DIR}/ros2.lock.repos"

"${ROOT_DIR}/scripts/sync_ros2_sources.sh"
"${ROOT_DIR}/scripts/apply_local_patches.sh"

if [[ "${CLEAN_BUILD:-1}" == "1" ]]; then
  rm -rf "${RELEASE_COLCON_BUILD_BASE}" "${RELEASE_COLCON_LOG_BASE}"
fi

mkdir -p "${RELEASE_COLCON_BUILD_BASE}" "${RELEASE_COLCON_LOG_BASE}"

SKIP_PACKAGES=()
if [[ -n "${PACKAGES_SKIP:-}" ]]; then
  for pkg in ${PACKAGES_SKIP}; do
    if [[ -n "${pkg}" ]]; then
      SKIP_PACKAGES+=("${pkg}")
    fi
  done
fi

PYTHON_EXECUTABLE="${RELEASE_PYTHON_HOME}/bin/python"
PYTHON_CONFIG_EXECUTABLE="${RELEASE_PYTHON_HOME}/bin/python3-config"
PYTHON_ROOT_DIR="$("${PYTHON_EXECUTABLE}" -c 'import sys; print(sys.prefix)')"
PYTHON_INCLUDE_DIR="$("${PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
PYTHON_LIBRARY_NAME="$("${PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_config_var("LDLIBRARY"))')"
PYTHON_LIBRARY="${RELEASE_PYTHON_HOME}/lib/${PYTHON_LIBRARY_NAME}"
if [[ ! -f "${PYTHON_LIBRARY}" ]]; then
  PYTHON_LIBRARY="$("${PYTHON_EXECUTABLE}" -c 'import pathlib, sysconfig; print(pathlib.Path(sysconfig.get_config_var("LIBDIR")) / sysconfig.get_config_var("LDLIBRARY"))')"
fi

BUILD_CMD=(
  "${PYTHON_EXECUTABLE}"
  -c
  'import sys; from colcon_core.command import main; sys.argv[0] = "colcon"; raise SystemExit(main())'
  --log-base "${RELEASE_COLCON_LOG_BASE}"
  build
  --base-paths "${ROOT_DIR}/src"
  --build-base "${RELEASE_COLCON_BUILD_BASE}"
  --install-base "${RUNTIME_PREFIX}"
  --merge-install
  --parallel-workers "${JOBS}"
)

if (( ${#SKIP_PACKAGES[@]} > 0 )); then
  BUILD_CMD+=(--packages-skip "${SKIP_PACKAGES[@]}")
fi

BUILD_CMD+=(
  --cmake-args
  -DBUILD_TESTING=OFF
  -DBUILD_UNIT_TESTS=OFF
  -DBUILD_TOOLS=OFF
  -DBUILD_EXAMPLES=OFF
  -DCMAKE_BUILD_TYPE=Release
  -DNO_TLS=ON
  "-DPYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}"
  "-DPython3_EXECUTABLE=${PYTHON_EXECUTABLE}"
  "-DPython3_ROOT_DIR=${PYTHON_ROOT_DIR}"
  -DPython3_FIND_VIRTUALENV=ONLY
  -DPython3_FIND_STRATEGY=LOCATION
  "-DPython3_INCLUDE_DIR=${PYTHON_INCLUDE_DIR}"
  "-DPython3_LIBRARY=${PYTHON_LIBRARY}"
  "-DPYTHON_INCLUDE_DIR=${PYTHON_INCLUDE_DIR}"
  "-DPYTHON_LIBRARY=${PYTHON_LIBRARY}"
  "-DPYTHON_CONFIG_EXECUTABLE=${PYTHON_CONFIG_EXECUTABLE}"
  "-DPythonExtra_INCLUDE_DIRS=${PYTHON_INCLUDE_DIR}"
  "-DPythonExtra_LIBRARIES=${PYTHON_LIBRARY}"
  -Wno-dev
)

if [[ -f "${RELEASE_OPENSSL_CRYPTO_LIBRARY}" && -f "${RELEASE_OPENSSL_SSL_LIBRARY}" ]]; then
  BUILD_CMD+=(
    "-DOPENSSL_ROOT_DIR=${RELEASE_NATIVE_DEPS_PREFIX}"
    "-DOPENSSL_INCLUDE_DIR=${RELEASE_NATIVE_DEPS_PREFIX}/include"
    "-DOPENSSL_CRYPTO_LIBRARY=${RELEASE_OPENSSL_CRYPTO_LIBRARY}"
    "-DOPENSSL_SSL_LIBRARY=${RELEASE_OPENSSL_SSL_LIBRARY}"
  )
fi

if [[ -f "${RELEASE_ZSTD_LIBRARY}" || -f "${RELEASE_ZSTD_VERSIONED_LIBRARY}" ]]; then
  if [[ ! -f "${RELEASE_ZSTD_LIBRARY}" ]]; then
    RELEASE_ZSTD_LIBRARY="${RELEASE_ZSTD_VERSIONED_LIBRARY}"
  fi
  BUILD_CMD+=(
    "-Dzstd_ROOT_DIR=${RELEASE_NATIVE_DEPS_PREFIX}"
    "-Dzstd_INCLUDE_DIR=${RELEASE_NATIVE_DEPS_PREFIX}/include"
    "-Dzstd_LIBRARY=${RELEASE_ZSTD_LIBRARY}"
  )
fi

if [[ -f "${RELEASE_ZMQ_LIBRARY}" || -f "${RELEASE_ZMQ_VERSIONED_LIBRARY}" ]]; then
  if [[ ! -f "${RELEASE_ZMQ_LIBRARY}" ]]; then
    RELEASE_ZMQ_LIBRARY="${RELEASE_ZMQ_VERSIONED_LIBRARY}"
  fi
  BUILD_CMD+=(
    "-DZMQ_INCLUDE_DIR=${RELEASE_NATIVE_DEPS_PREFIX}/include"
    "-DZMQ_LIBRARY=${RELEASE_ZMQ_LIBRARY}"
    "-DZeroMQ_DIR=${RELEASE_NATIVE_DEPS_PREFIX}/lib/cmake/ZeroMQ"
  )
fi

"${BUILD_CMD[@]}"
"${ROOT_DIR}/scripts/fixup_release_artifact.sh"

set +u
source "${RUNTIME_PREFIX}/setup.bash"
set -u

ros2 doctor --report || true

rm -f "${LISTENER_LOG}" "${TALKER_LOG}"
/bin/bash -lc "
  set -euo pipefail
  source '${RUNTIME_PREFIX}/share/ros2native/activate.sh'
  set +u
  source '${RUNTIME_PREFIX}/setup.bash'
  set -u
  exec ros2 run demo_nodes_py listener
" >"${LISTENER_LOG}" 2>&1 &
LISTENER_PID="$!"

sleep 8

/bin/bash -lc "
  set -euo pipefail
  source '${RUNTIME_PREFIX}/share/ros2native/activate.sh'
  set +u
  source '${RUNTIME_PREFIX}/setup.bash'
  set -u
  exec ros2 run demo_nodes_cpp talker
" >"${TALKER_LOG}" 2>&1 &
TALKER_PID="$!"

sleep 12

cleanup_process "${TALKER_PID}"
cleanup_process "${LISTENER_PID}"
TALKER_PID=""
LISTENER_PID=""

if ! grep -q 'I heard: \[Hello World:' "${LISTENER_LOG}"; then
  echo "ERROR: talker/listener smoke test failed." >&2
  echo "--- listener log ---" >&2
  cat "${LISTENER_LOG}" >&2
  echo "--- talker log ---" >&2
  cat "${TALKER_LOG}" >&2
  exit 1
fi

echo "Release build completed at ${RUNTIME_PREFIX}"
