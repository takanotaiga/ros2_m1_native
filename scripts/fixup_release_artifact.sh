#!/usr/bin/env bash

set -euo pipefail

APP_PATH="${APP_PATH:-/Applications/ROS2Native.app}"
RVIZ_APP_PATH="${RVIZ_APP_PATH:-/Applications/RViz 2.app}"
RQT_APP_PATH="${RQT_APP_PATH:-/Applications/rqt.app}"
RUNTIME_PREFIX="${RUNTIME_PREFIX:-${APP_PATH}/Contents/Resources/runtime}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TINYXML_DYLIB="${RUNTIME_PREFIX}/lib/libtinyxml.dylib"
FREETYPE_DYLIB="${RUNTIME_PREFIX}/deps/lib/libfreetype.6.dylib"
OPENSSL_CRYPTO_DYLIB="${RUNTIME_PREFIX}/deps/lib/libcrypto.3.dylib"
OPENSSL_SSL_DYLIB="${RUNTIME_PREFIX}/deps/lib/libssl.3.dylib"
ZSTD_DYLIB="${RUNTIME_PREFIX}/deps/lib/libzstd.1.dylib"
ZMQ_DYLIB="${RUNTIME_PREFIX}/deps/lib/libzmq.5.dylib"

if [[ ! -d "${RUNTIME_PREFIX}" ]]; then
  echo "ERROR: runtime prefix not found at ${RUNTIME_PREFIX}" >&2
  exit 1
fi

MACHO_LIST_FILE="$(mktemp)"
trap 'rm -f "${MACHO_LIST_FILE}"' EXIT

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

while IFS= read -r -d '' candidate; do
  if file "${candidate}" | grep -q 'Mach-O'; then
    printf '%s\0' "${candidate}" >>"${MACHO_LIST_FILE}"
  fi
done < <(find "${MACHO_SCAN_DIRS[@]}" -type f -print0 2>/dev/null)

change_dep() {
  local old_dep="$1"
  local new_dep="$2"

  if [[ -z "${old_dep}" || ! -e "${new_dep}" ]]; then
    return
  fi

  while IFS= read -r -d '' candidate; do
    install_name_tool -change "${old_dep}" "${new_dep}" "${candidate}" 2>/dev/null || true
  done <"${MACHO_LIST_FILE}"
}

# The copied CPython runtime already uses @rpath-relative libpython lookups.
# Rewriting those install names to absolute bundle paths caused runtime crashes on CI.
if [[ -f "${TINYXML_DYLIB}" ]]; then
  OLD_TINYXML_DYLIB="$(otool -D "${TINYXML_DYLIB}" | awk 'NR==2 {print $1}')"
  install_name_tool -id "${TINYXML_DYLIB}" "${TINYXML_DYLIB}" 2>/dev/null || true
  change_dep "${OLD_TINYXML_DYLIB}" "${TINYXML_DYLIB}"
fi

if [[ -f "${FREETYPE_DYLIB}" ]]; then
  install_name_tool -id "${FREETYPE_DYLIB}" "${FREETYPE_DYLIB}" 2>/dev/null || true
  change_dep "/opt/homebrew/opt/freetype/lib/libfreetype.6.dylib" "${FREETYPE_DYLIB}"
fi

if [[ -f "${OPENSSL_CRYPTO_DYLIB}" ]]; then
  install_name_tool -id "${OPENSSL_CRYPTO_DYLIB}" "${OPENSSL_CRYPTO_DYLIB}" 2>/dev/null || true
  change_dep "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib" "${OPENSSL_CRYPTO_DYLIB}"
  change_dep "/opt/homebrew/lib/libcrypto.dylib" "${OPENSSL_CRYPTO_DYLIB}"
fi

if [[ -f "${OPENSSL_SSL_DYLIB}" ]]; then
  install_name_tool -id "${OPENSSL_SSL_DYLIB}" "${OPENSSL_SSL_DYLIB}" 2>/dev/null || true
  change_dep "/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib" "${OPENSSL_SSL_DYLIB}"
  change_dep "/opt/homebrew/lib/libssl.dylib" "${OPENSSL_SSL_DYLIB}"
fi

if [[ -f "${ZSTD_DYLIB}" ]]; then
  install_name_tool -id "${ZSTD_DYLIB}" "${ZSTD_DYLIB}" 2>/dev/null || true
  change_dep "/opt/homebrew/opt/zstd/lib/libzstd.1.dylib" "${ZSTD_DYLIB}"
  change_dep "/opt/homebrew/lib/libzstd.dylib" "${ZSTD_DYLIB}"
fi

if [[ -f "${ZMQ_DYLIB}" ]]; then
  install_name_tool -id "${ZMQ_DYLIB}" "${ZMQ_DYLIB}" 2>/dev/null || true
  change_dep "/opt/homebrew/opt/zeromq/lib/libzmq.5.dylib" "${ZMQ_DYLIB}"
  change_dep "/opt/homebrew/lib/libzmq.dylib" "${ZMQ_DYLIB}"
fi

if [[ -f "${RUNTIME_PREFIX}/lib/libfastrtps.2.6.11.dylib" ]]; then
  rm -f "${RUNTIME_PREFIX}/bin/fast-discovery-server-1.0.0"
fi

while IFS= read -r -d '' prl_file; do
  perl -0pi -e 's/^QMAKE_PRL_BUILD_DIR = .*$/QMAKE_PRL_BUILD_DIR =/mg' "${prl_file}"
done < <(find "${RUNTIME_PREFIX}" -type f -name '*.prl' -print0)

while IFS= read -r -d '' pc_file; do
  old_prefix="$(awk -F= '/^prefix=/{print $2; exit}' "${pc_file}")"
  if [[ -n "${old_prefix}" && "${old_prefix}" == "${ROOT_DIR}"* ]]; then
    python_prefix="${RUNTIME_PREFIX}"
    perl -0pi -e "s#\\Q${old_prefix}\\E#${python_prefix}#g" "${pc_file}"
  fi
done < <(find "${RUNTIME_PREFIX}/lib/pkgconfig" "${RUNTIME_PREFIX}/opt" -type f -name '*.pc' -print0 2>/dev/null)

while IFS= read -r -d '' cmake_file; do
  perl -0pi -e "s#\\Q/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib\\E#${OPENSSL_CRYPTO_DYLIB}#g; s#\\Q/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib\\E#${OPENSSL_SSL_DYLIB}#g; s#\\Q/opt/homebrew/opt/zstd/lib/libzstd.1.dylib\\E#${ZSTD_DYLIB}#g; s#\\Q/opt/homebrew/opt/zeromq/lib/libzmq.5.dylib\\E#${ZMQ_DYLIB}#g; s#\\Q/opt/homebrew/lib/libcrypto.dylib\\E#${OPENSSL_CRYPTO_DYLIB}#g; s#\\Q/opt/homebrew/lib/libssl.dylib\\E#${OPENSSL_SSL_DYLIB}#g; s#\\Q/opt/homebrew/lib/libzstd.dylib\\E#${ZSTD_DYLIB}#g; s#\\Q/opt/homebrew/lib/libzmq.dylib\\E#${ZMQ_DYLIB}#g" "${cmake_file}"
done < <(find "${RUNTIME_PREFIX}/lib" "${RUNTIME_PREFIX}/share" "${RUNTIME_PREFIX}/deps" -type f \( -name '*.cmake' -o -name '*.pc' \) -print0 2>/dev/null)

DYNAMICEDT_TARGETS="${RUNTIME_PREFIX}/deps/share/dynamicEDT3D/dynamicEDT3DTargets.cmake"
if [[ -f "${DYNAMICEDT_TARGETS}" ]]; then
  perl -0pi -e 's#/Users/[^";\n]*/octomap/lib/liboctomap\.dylib;/Users/[^";\n]*/octomap/lib/liboctomath\.dylib#${_IMPORT_PREFIX}/lib/liboctomap.dylib;${_IMPORT_PREFIX}/lib/liboctomath.dylib#g' "${DYNAMICEDT_TARGETS}"
fi

PCL_CONFIG="${RUNTIME_PREFIX}/deps/share/pcl-1.12/PCLConfig.cmake"
if [[ -f "${PCL_CONFIG}" ]]; then
  perl -0pi -e 's#set\(PCL_SOURCES_TREE ".*"\)#set(PCL_SOURCES_TREE "")#g' "${PCL_CONFIG}"
fi

echo "Fixed up release artifact at ${RUNTIME_PREFIX}"
