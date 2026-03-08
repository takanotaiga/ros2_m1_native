#!/usr/bin/env bash

# Detect whether this file is sourced (bash/zsh) and resolve script path.
SCRIPT_SOURCE="${0}"
if [[ -n "${BASH_VERSION:-}" ]]; then
  SCRIPT_SOURCE="${BASH_SOURCE[0]}"
  if [[ "${SCRIPT_SOURCE}" == "${0}" ]]; then
    echo "ERROR: source this file instead of executing it." >&2
    echo "Usage: source scripts/activate_env.sh" >&2
    exit 1
  fi
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  SCRIPT_SOURCE="${0}"
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file) ;;
    *)
      echo "ERROR: source this file instead of executing it." >&2
      echo "Usage: source scripts/activate_env.sh" >&2
      exit 1
      ;;
  esac
fi

ROOT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")/.." && pwd)"

export ROS2_M1_NATIVE_ROOT="${ROOT_DIR}"
export ROS2_LOCAL_DEPS_PREFIX="${ROOT_DIR}/.local/deps"
export ROS2_THIRD_PARTY_SRC_DIR="${ROOT_DIR}/.deps/third_party"

unset HOMEBREW_PREFIX
unset HOMEBREW_CELLAR
unset HOMEBREW_REPOSITORY

UV_BIN_DIR=""
if command -v uv >/dev/null 2>&1; then
  UV_BIN_DIR="$(cd "$(dirname "$(command -v uv)")" && pwd)"
fi

BASE_PATH="${ROOT_DIR}/.local/tools/cmake/bin:${ROOT_DIR}/.venv/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
if [[ -n "${UV_BIN_DIR}" ]]; then
  BASE_PATH="${UV_BIN_DIR}:${BASE_PATH}"
fi

export PATH="${BASE_PATH}"
export PATH="${ROS2_LOCAL_DEPS_PREFIX}/bin:${PATH}"
export PATH="${ROS2_LOCAL_DEPS_PREFIX}/qt5/bin:${PATH}"
if [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
  PYTHON_HOST_BINDIR="$("${ROOT_DIR}/.venv/bin/python" -c 'import sysconfig; print(sysconfig.get_config_var("BINDIR"))')"
  export PATH="${PYTHON_HOST_BINDIR}:${PATH}"
fi
if command -v xcrun >/dev/null 2>&1; then
  export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
  export CMAKE_OSX_SYSROOT="${CMAKE_OSX_SYSROOT:-${SDKROOT}}"
fi
export CMAKE_PREFIX_PATH="${ROS2_LOCAL_DEPS_PREFIX}/qt5:${ROS2_LOCAL_DEPS_PREFIX}:${CMAKE_PREFIX_PATH:-}"
export CMAKE_LIBRARY_PATH="${ROS2_LOCAL_DEPS_PREFIX}/lib:${CMAKE_LIBRARY_PATH:-}"
export CMAKE_INCLUDE_PATH="${ROS2_LOCAL_DEPS_PREFIX}/include:${CMAKE_INCLUDE_PATH:-}"
export PKG_CONFIG_PATH="${ROS2_LOCAL_DEPS_PREFIX}/qt5/lib/pkgconfig:${ROS2_LOCAL_DEPS_PREFIX}/lib/pkgconfig:${ROS2_LOCAL_DEPS_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export COLCON_EXTENSION_BLOCKLIST="${COLCON_EXTENSION_BLOCKLIST:-colcon_core.event_handler.desktop_notification}"
export PYTHONNOUSERSITE=1

ROS2_M1_NATIVE_PYTHON_EXECUTABLE="${ROOT_DIR}/.venv/bin/python"
if [[ -x "${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" ]]; then
  export ROS2_M1_NATIVE_PYTHON_EXECUTABLE
  export COLCON_PYTHON_EXECUTABLE="${COLCON_PYTHON_EXECUTABLE:-${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}}"

  ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR="$("${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
  ROS2_M1_NATIVE_PYTHON_LIBRARY="$("${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" -c 'import pathlib, sysconfig; print(pathlib.Path(sysconfig.get_config_var("LIBDIR")) / sysconfig.get_config_var("LDLIBRARY"))')"
  export ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR
  export ROS2_M1_NATIVE_PYTHON_LIBRARY

  COLCON_DEFAULTS_DIR="${ROOT_DIR}/.local/colcon"
  mkdir -p "${COLCON_DEFAULTS_DIR}"
  export ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE="${COLCON_DEFAULTS_DIR}/defaults.yaml"
  cat > "${ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE}" <<EOF
build:
  cmake-args:
    - -DPYTHON_EXECUTABLE=${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}
    - -DPython3_EXECUTABLE=${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}
    - -DPYTHON_INCLUDE_DIR=${ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR}
    - -DPYTHON_LIBRARY=${ROS2_M1_NATIVE_PYTHON_LIBRARY}
EOF
  export COLCON_DEFAULTS_FILE="${COLCON_DEFAULTS_FILE:-${ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE}}"
fi

if [[ "${PATH}" == *"/opt/homebrew"* ]] || [[ "${PATH}" == *"/usr/local/Homebrew"* ]]; then
  echo "ERROR: Homebrew path leakage detected in PATH." >&2
  return 1
fi
