#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: source this file instead of executing it." >&2
  echo "Usage: source scripts/activate_env.sh" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export ROS2_M1_NATIVE_ROOT="${ROOT_DIR}"
export ROS2_LOCAL_DEPS_PREFIX="${ROOT_DIR}/.local/deps"

unset HOMEBREW_PREFIX
unset HOMEBREW_CELLAR
unset HOMEBREW_REPOSITORY

export PATH="${ROOT_DIR}/.local/tools/cmake/bin:${ROOT_DIR}/.venv/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="${ROS2_LOCAL_DEPS_PREFIX}/bin:${PATH}"
if [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
  PYTHON_HOST_BINDIR="$("${ROOT_DIR}/.venv/bin/python" -c 'import sysconfig; print(sysconfig.get_config_var("BINDIR"))')"
  export PATH="${PYTHON_HOST_BINDIR}:${PATH}"
fi
export CMAKE_PREFIX_PATH="${ROS2_LOCAL_DEPS_PREFIX}:${CMAKE_PREFIX_PATH:-}"
export CMAKE_LIBRARY_PATH="${ROS2_LOCAL_DEPS_PREFIX}/lib:${CMAKE_LIBRARY_PATH:-}"
export CMAKE_INCLUDE_PATH="${ROS2_LOCAL_DEPS_PREFIX}/include:${CMAKE_INCLUDE_PATH:-}"
export PKG_CONFIG_PATH="${ROS2_LOCAL_DEPS_PREFIX}/lib/pkgconfig:${ROS2_LOCAL_DEPS_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export COLCON_EXTENSION_BLOCKLIST="${COLCON_EXTENSION_BLOCKLIST:-colcon_core.event_handler.desktop_notification}"
export PYTHONNOUSERSITE=1

if [[ "${PATH}" == *"/opt/homebrew"* ]] || [[ "${PATH}" == *"/usr/local/Homebrew"* ]]; then
  echo "ERROR: Homebrew path leakage detected in PATH." >&2
  return 1
fi
