#!/usr/bin/env python3

from __future__ import annotations

import argparse
import plistlib
import stat
from pathlib import Path


def write_text(path: Path, content: str, *, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    if executable:
        mode = path.stat().st_mode
        path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def write_plist(path: Path, *, bundle_id: str, executable: str, name: str, version: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "CFBundleDevelopmentRegion": "English",
        "CFBundleExecutable": executable,
        "CFBundleIdentifier": bundle_id,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": name,
        "CFBundleDisplayName": name,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "LSMinimumSystemVersion": "14.0",
        "NSHighResolutionCapable": True,
    }
    with path.open("wb") as handle:
        plistlib.dump(payload, handle, sort_keys=False)


def make_runtime_app(main_app: Path, runtime_prefix: Path, version: str) -> None:
    resources_dir = main_app / "Contents" / "Resources"
    scripts_dir = resources_dir / "scripts"
    runtime_share_dir = runtime_prefix / "share" / "ros2native"

    write_plist(
        main_app / "Contents" / "Info.plist",
        bundle_id="io.github.taiga.ros2native.runtime",
        executable="ros2native",
        name="ROS2 Native",
        version=version,
    )

    write_text(
        main_app / "Contents" / "MacOS" / "ros2native",
        """#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(cd "${SCRIPT_DIR}/../Resources" && pwd)"

exec /usr/bin/open "${RESOURCES_DIR}/scripts/open_shell.command"
""",
        executable=True,
    )

    write_text(
        scripts_dir / "run_with_runtime_env.sh",
        """#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $(basename "$0") <command> [args...]" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNTIME_PREFIX="${RESOURCES_DIR}/runtime"
ACTIVATE_SCRIPT="${RUNTIME_PREFIX}/share/ros2native/activate.sh"
SETUP_SCRIPT="${RUNTIME_PREFIX}/setup.bash"

if [[ ! -f "${ACTIVATE_SCRIPT}" ]]; then
  echo "ERROR: runtime activation script not found at ${ACTIVATE_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${SETUP_SCRIPT}" ]]; then
  echo "ERROR: ROS 2 runtime is not built yet at ${RUNTIME_PREFIX}" >&2
  exit 1
fi

source "${ACTIVATE_SCRIPT}"
set +u
source "${SETUP_SCRIPT}"
set -u

exec "$@"
""",
        executable=True,
    )

    write_text(
        scripts_dir / "open_shell.command",
        """#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_BIN="${SHELL:-/bin/zsh}"

exec "${SCRIPT_DIR}/run_with_runtime_env.sh" "${SHELL_BIN}" -i
""",
        executable=True,
    )

    write_text(
        scripts_dir / "uninstall_ros2native.sh",
        """#!/usr/bin/env bash
set -euo pipefail

MANAGED_MARKER="ros2native-managed"
ASSUME_YES=0
DRY_RUN=0
ORIGINAL_ARGS=("$@")

usage() {
  cat <<'EOF'
Usage: uninstall_ros2native.sh [--yes] [--dry-run]

Removes the ROS2 Native app bundles, managed CLI wrappers, and package receipts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      ASSUME_YES=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_BUNDLE="$(cd "${RESOURCES_DIR}/../.." && pwd)"
INSTALL_ROOT="$(cd "${APP_BUNDLE}/../.." && pwd)"
APPLICATIONS_DIR="${INSTALL_ROOT}/Applications"
BIN_DIR="${INSTALL_ROOT}/usr/local/bin"

TARGET_APPS=(
  "${APPLICATIONS_DIR}/ROS2Native.app"
  "${APPLICATIONS_DIR}/RViz 2.app"
  "${APPLICATIONS_DIR}/rqt.app"
)
TARGET_CLI=(
  "${BIN_DIR}/ros2"
  "${BIN_DIR}/ros2native"
  "${BIN_DIR}/rviz2"
  "${BIN_DIR}/ros2native-rviz2"
  "${BIN_DIR}/colcon"
  "${BIN_DIR}/ros2native-colcon"
  "${BIN_DIR}/ros2native-uninstall"
)

bundle_identifier() {
  local app_path="$1"
  local plist_path="${app_path}/Contents/Info.plist"
  if [[ ! -f "${plist_path}" ]]; then
    return 1
  fi
  /usr/bin/plutil -extract CFBundleIdentifier raw -o - "${plist_path}" 2>/dev/null
}

is_managed_app() {
  local app_path="$1"
  local bundle_id
  bundle_id="$(bundle_identifier "${app_path}" || true)"
  [[ "${bundle_id}" == io.github.taiga.ros2native.* ]]
}

is_managed_cli() {
  local target="$1"
  [[ -f "${target}" ]] && /usr/bin/grep -Fq "${MANAGED_MARKER}" "${target}"
}

needs_privilege() {
  local target
  for target in "$@"; do
    local parent_dir
    parent_dir="$(dirname "${target}")"
    if [[ ! -w "${parent_dir}" ]]; then
      return 0
    fi
  done
  return 1
}

remove_path() {
  local target="$1"
  if [[ ! -e "${target}" && ! -L "${target}" ]]; then
    return 0
  fi

  if (( DRY_RUN )); then
    echo "Would remove ${target}"
    return 0
  fi

  chmod -R u+w "${target}" 2>/dev/null || true
  rm -rf "${target}"
  echo "Removed ${target}"
}

if needs_privilege "${TARGET_APPS[@]}" "${TARGET_CLI[@]}"; then
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo "${BASH_SOURCE[0]}" "${ORIGINAL_ARGS[@]}"
  fi
fi

if (( ! ASSUME_YES )); then
  echo "This will remove ROS2 Native from ${INSTALL_ROOT}." >&2
  printf 'Continue? [y/N] ' >&2
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Aborted." >&2
      exit 1
      ;;
  esac
fi

for cli_target in "${TARGET_CLI[@]}"; do
  if is_managed_cli "${cli_target}"; then
    remove_path "${cli_target}"
  fi
done

for app_target in "${TARGET_APPS[@]}"; do
  if is_managed_app "${app_target}"; then
    remove_path "${app_target}"
  fi
done

if [[ "${INSTALL_ROOT}" == "/" ]] && [[ "${DRY_RUN}" -eq 0 ]] && [[ "${EUID}" -eq 0 ]]; then
  /usr/sbin/pkgutil --forget io.github.taiga.ros2native.payload >/dev/null 2>&1 || true
  /usr/sbin/pkgutil --forget io.github.taiga.ros2native >/dev/null 2>&1 || true
fi
""",
        executable=True,
    )

    write_text(
        runtime_share_dir / "activate.sh",
        """#!/usr/bin/env bash

# Detect whether this file is sourced (bash/zsh) and resolve script path.
SCRIPT_SOURCE="${0}"
if [[ -n "${BASH_VERSION:-}" ]]; then
  SCRIPT_SOURCE="${BASH_SOURCE[0]}"
  if [[ "${SCRIPT_SOURCE}" == "${0}" ]]; then
    echo "ERROR: source this file instead of executing it." >&2
    echo "Usage: source /Applications/ROS2Native.app/Contents/Resources/runtime/share/ros2native/activate.sh" >&2
    exit 1
  fi
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  SCRIPT_SOURCE="${0}"
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file) ;;
    *)
      echo "ERROR: source this file instead of executing it." >&2
      echo "Usage: source /Applications/ROS2Native.app/Contents/Resources/runtime/share/ros2native/activate.sh" >&2
      exit 1
      ;;
  esac
fi

RUNTIME_PREFIX="$(cd "$(dirname "${SCRIPT_SOURCE}")/../.." && pwd)"

export ROS2_M1_NATIVE_ROOT="${RUNTIME_PREFIX}"
export ROS2_LOCAL_DEPS_PREFIX="${RUNTIME_PREFIX}/deps"
export FREETYPE_HOME="${ROS2_LOCAL_DEPS_PREFIX}"
export OPENSSL_ROOT_DIR="${ROS2_LOCAL_DEPS_PREFIX}"
export OPENSSL_INCLUDE_DIR="${ROS2_LOCAL_DEPS_PREFIX}/include"
export OPENSSL_CRYPTO_LIBRARY="${ROS2_LOCAL_DEPS_PREFIX}/lib/libcrypto.3.dylib"
export OPENSSL_SSL_LIBRARY="${ROS2_LOCAL_DEPS_PREFIX}/lib/libssl.3.dylib"
export zstd_ROOT_DIR="${ROS2_LOCAL_DEPS_PREFIX}"
export ZMQ_INCLUDE_DIR="${ROS2_LOCAL_DEPS_PREFIX}/include"
export ZMQ_LIBRARY="${ROS2_LOCAL_DEPS_PREFIX}/lib/libzmq.dylib"
export ZeroMQ_DIR="${ROS2_LOCAL_DEPS_PREFIX}/lib/cmake/ZeroMQ"
unset HOMEBREW_PREFIX
unset HOMEBREW_CELLAR
unset HOMEBREW_REPOSITORY

BASE_PATH="${RUNTIME_PREFIX}/tools/cmake/bin:${RUNTIME_PREFIX}/python/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="${BASE_PATH}"
export PATH="${ROS2_LOCAL_DEPS_PREFIX}/bin:${PATH}"
export PATH="${ROS2_LOCAL_DEPS_PREFIX}/qt5/bin:${PATH}"

if command -v xcrun >/dev/null 2>&1; then
  export SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
  export CMAKE_OSX_SYSROOT="${CMAKE_OSX_SYSROOT:-${SDKROOT}}"
fi

export CMAKE_PREFIX_PATH="${ROS2_LOCAL_DEPS_PREFIX}/qt5:${ROS2_LOCAL_DEPS_PREFIX}:${CMAKE_PREFIX_PATH:-}"
export CMAKE_LIBRARY_PATH="${ROS2_LOCAL_DEPS_PREFIX}/lib:${CMAKE_LIBRARY_PATH:-}"
export CMAKE_INCLUDE_PATH="${ROS2_LOCAL_DEPS_PREFIX}/include:${CMAKE_INCLUDE_PATH:-}"
export PKG_CONFIG_PATH="${ROS2_LOCAL_DEPS_PREFIX}/qt5/lib/pkgconfig:${ROS2_LOCAL_DEPS_PREFIX}/lib/pkgconfig:${ROS2_LOCAL_DEPS_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export BOOST_ROOT="${ROS2_LOCAL_DEPS_PREFIX}"
export PCL_DIR="${ROS2_LOCAL_DEPS_PREFIX}/lib/cmake/pcl"
export COLCON_EXTENSION_BLOCKLIST="${COLCON_EXTENSION_BLOCKLIST:-colcon_core.event_handler.desktop_notification}"
export PYTHONNOUSERSITE=1
export ROS_VERSION="${ROS_VERSION:-2}"
export ROS_PYTHON_VERSION="${ROS_PYTHON_VERSION:-3}"

ROS2_M1_NATIVE_PYTHON_EXECUTABLE="${RUNTIME_PREFIX}/python/bin/python"
if [[ -x "${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" ]]; then
  export ROS2_M1_NATIVE_PYTHON_EXECUTABLE
  export COLCON_PYTHON_EXECUTABLE="${COLCON_PYTHON_EXECUTABLE:-${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}}"

  ROS2_M1_NATIVE_PYTHON_ROOT_DIR="$("${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" -c 'import sys; print(sys.prefix)')"
  ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR="$("${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
  ROS2_M1_NATIVE_PYTHON_LIBRARY_NAME="$("${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_config_var("LDLIBRARY"))')"
  ROS2_M1_NATIVE_PYTHON_LIBRARY="${RUNTIME_PREFIX}/python/lib/${ROS2_M1_NATIVE_PYTHON_LIBRARY_NAME}"
  if [[ ! -f "${ROS2_M1_NATIVE_PYTHON_LIBRARY}" ]]; then
  ROS2_M1_NATIVE_PYTHON_LIBRARY="$("${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}" -c 'import pathlib, sysconfig; print(pathlib.Path(sysconfig.get_config_var("LIBDIR")) / sysconfig.get_config_var("LDLIBRARY"))')"
  fi
  export ROS2_M1_NATIVE_PYTHON_ROOT_DIR
  export ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR
  export ROS2_M1_NATIVE_PYTHON_LIBRARY

  if [[ -n "${ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE:-}" ]]; then
    COLCON_DEFAULTS_PATH="${ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE}"
  elif [[ -n "${HOME:-}" ]]; then
    COLCON_DEFAULTS_PATH="${HOME}/Library/Application Support/ros2native/colcon-defaults.yaml"
  else
    COLCON_DEFAULTS_PATH="${TMPDIR:-/tmp}/ros2native/colcon-defaults.yaml"
  fi

  COLCON_DEFAULTS_DIR="$(dirname "${COLCON_DEFAULTS_PATH}")"
  mkdir -p "${COLCON_DEFAULTS_DIR}"
  export ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE="${COLCON_DEFAULTS_PATH}"
  cat > "${ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE}" <<EOF
build:
  cmake-args:
    - -DPYTHON_EXECUTABLE=${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}
    - -DPython3_EXECUTABLE=${ROS2_M1_NATIVE_PYTHON_EXECUTABLE}
    - -DPython3_ROOT_DIR=${ROS2_M1_NATIVE_PYTHON_ROOT_DIR}
    - -DPython3_FIND_VIRTUALENV=ONLY
    - -DPython3_FIND_STRATEGY=LOCATION
    - -DPython3_INCLUDE_DIR=${ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR}
    - -DPython3_LIBRARY=${ROS2_M1_NATIVE_PYTHON_LIBRARY}
    - -DPYTHON_INCLUDE_DIR=${ROS2_M1_NATIVE_PYTHON_INCLUDE_DIR}
    - -DPYTHON_LIBRARY=${ROS2_M1_NATIVE_PYTHON_LIBRARY}
    - -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}
    - -DOPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR}
    - -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_CRYPTO_LIBRARY}
    - -DOPENSSL_SSL_LIBRARY=${OPENSSL_SSL_LIBRARY}
    - -Dzstd_ROOT_DIR=${zstd_ROOT_DIR}
    - -Dzstd_INCLUDE_DIR=${ROS2_LOCAL_DEPS_PREFIX}/include
    - -Dzstd_LIBRARY=${ROS2_LOCAL_DEPS_PREFIX}/lib/libzstd.dylib
    - -DZMQ_INCLUDE_DIR=${ZMQ_INCLUDE_DIR}
    - -DZMQ_LIBRARY=${ZMQ_LIBRARY}
    - -DZeroMQ_DIR=${ZeroMQ_DIR}
EOF
  export COLCON_DEFAULTS_FILE="${COLCON_DEFAULTS_FILE:-${ROS2_M1_NATIVE_COLCON_DEFAULTS_FILE}}"
fi

if [[ "${PATH}" == *"/opt/homebrew"* ]] || [[ "${PATH}" == *"/usr/local/Homebrew"* ]]; then
  echo "ERROR: Homebrew path leakage detected in PATH." >&2
  return 1
fi
""",
        executable=True,
    )

    write_text(
        resources_dir / "README.txt",
        """ROS2 Native installs its runtime inside this application bundle.

To open a pre-configured shell:
  open /Applications/ROS2Native.app

After installing ros2native.pkg:
  ros2 --help
  ros2native --help
  rviz2 --help
  colcon --help

To uninstall:
  ros2native-uninstall --yes

To load the environment manually:
  source /Applications/ROS2Native.app/Contents/Resources/runtime/share/ros2native/activate.sh
  source /Applications/ROS2Native.app/Contents/Resources/runtime/setup.bash

GUI launchers:
  /Applications/RViz 2.app
  /Applications/rqt.app
""",
    )


def make_wrapper_app(path: Path, *, bundle_id: str, executable: str, name: str, command: str, version: str) -> None:
    write_plist(
        path / "Contents" / "Info.plist",
        bundle_id=bundle_id,
        executable=executable,
        name=name,
        version=version,
    )
    write_text(
        path / "Contents" / "MacOS" / executable,
        f"""#!/usr/bin/env bash
set -euo pipefail

RUNNER="/Applications/ROS2Native.app/Contents/Resources/scripts/run_with_runtime_env.sh"

if [[ ! -x "${{RUNNER}}" ]]; then
  echo "ERROR: ROS2Native runtime launcher not found at ${{RUNNER}}" >&2
  exit 1
fi

exec "${{RUNNER}}" {command} "$@"
""",
        executable=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Create macOS app bundles for the packaged ROS 2 runtime.")
    parser.add_argument("--main-app", type=Path, required=True)
    parser.add_argument("--rviz-app", type=Path, required=True)
    parser.add_argument("--rqt-app", type=Path, required=True)
    parser.add_argument("--runtime-prefix", type=Path, required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    make_runtime_app(args.main_app, args.runtime_prefix, args.version)
    make_wrapper_app(
        args.rviz_app,
        bundle_id="io.github.taiga.ros2native.rviz2",
        executable="rviz2-launcher",
        name="RViz 2",
        command="rviz2",
        version=args.version,
    )
    make_wrapper_app(
        args.rqt_app,
        bundle_id="io.github.taiga.ros2native.rqt",
        executable="rqt-launcher",
        name="rqt",
        command="rqt",
        version=args.version,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
