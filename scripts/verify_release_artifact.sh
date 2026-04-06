#!/usr/bin/env bash

set -euo pipefail

APP_PATH="${APP_PATH:-/Applications/ROS2Native.app}"
RVIZ_APP_PATH="${RVIZ_APP_PATH:-/Applications/RViz 2.app}"
RQT_APP_PATH="${RQT_APP_PATH:-/Applications/rqt.app}"
RUNTIME_PREFIX="${RUNTIME_PREFIX:-${APP_PATH}/Contents/Resources/runtime}"
RUNNER="${APP_PATH}/Contents/Resources/scripts/run_with_runtime_env.sh"
UNINSTALLER="${APP_PATH}/Contents/Resources/scripts/uninstall_ros2native.sh"
FORBIDDEN_REPO_PATH="${FORBIDDEN_REPO_PATH:-}"
RG_EXCLUDE_ARGS=(
  --glob '!**/tools/cmake/**'
  --glob '!**/*.dist-info/**'
  --glob '!**/share/ros2native/activate.sh'
)
MACHO_SCAN_DIRS=(
  "${APP_PATH}/Contents/MacOS"
  "${RVIZ_APP_PATH}/Contents/MacOS"
  "${RQT_APP_PATH}/Contents/MacOS"
  "${RUNTIME_PREFIX}/bin"
  "${RUNTIME_PREFIX}/lib"
  "${RUNTIME_PREFIX}/opt"
  "${RUNTIME_PREFIX}/python/lib"
  "${RUNTIME_PREFIX}/deps/lib"
)

for required_path in "${APP_PATH}" "${RVIZ_APP_PATH}" "${RQT_APP_PATH}" "${RUNTIME_PREFIX}/setup.bash" "${RUNNER}" "${UNINSTALLER}"; do
  if [[ ! -e "${required_path}" ]]; then
    echo "ERROR: required release artifact missing: ${required_path}" >&2
    exit 1
  fi
done

if rg -n "${RG_EXCLUDE_ARGS[@]}" '/opt/homebrew|/usr/local/Homebrew' "${APP_PATH}" "${RVIZ_APP_PATH}" "${RQT_APP_PATH}"; then
  echo "ERROR: Homebrew path leakage detected in packaged apps." >&2
  exit 1
fi

if [[ -n "${FORBIDDEN_REPO_PATH}" ]]; then
  if rg -n "${RG_EXCLUDE_ARGS[@]}" --fixed-strings "${FORBIDDEN_REPO_PATH}" "${APP_PATH}" "${RVIZ_APP_PATH}" "${RQT_APP_PATH}"; then
    echo "ERROR: repository path leakage detected in packaged apps." >&2
    exit 1
  fi
fi

while IFS= read -r -d '' candidate; do
  if ! file "${candidate}" | rg -q 'Mach-O'; then
    continue
  fi

  if otool -L "${candidate}" | rg -q '/opt/homebrew|/usr/local/Homebrew'; then
    echo "ERROR: Homebrew library reference detected in ${candidate}" >&2
    otool -L "${candidate}" >&2
    exit 1
  fi

  if [[ -n "${FORBIDDEN_REPO_PATH}" ]] && otool -L "${candidate}" | rg -q --fixed-strings "${FORBIDDEN_REPO_PATH}"; then
    echo "ERROR: repository path leakage detected in ${candidate}" >&2
    otool -L "${candidate}" >&2
    exit 1
  fi
done < <(find "${MACHO_SCAN_DIRS[@]}" -type f -print0 2>/dev/null)

"${RUNNER}" ros2 --help >/dev/null
"${RUNNER}" python -c 'import rclpy'
"${RUNNER}" ros2 topic list >/dev/null

echo "Release artifact verification passed for ${APP_PATH}"
