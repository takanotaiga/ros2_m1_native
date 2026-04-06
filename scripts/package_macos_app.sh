#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
export COPYFILE_DISABLE=1

APP_PATH="${APP_PATH:-/Applications/ROS2Native.app}"
RVIZ_APP_PATH="${RVIZ_APP_PATH:-/Applications/RViz 2.app}"
RQT_APP_PATH="${RQT_APP_PATH:-/Applications/rqt.app}"
RELEASE_ROOT="${ROOT_DIR}/.release"
PKG_ROOT="${RELEASE_ROOT}/pkgroot"
PKG_BUILD_DIR="${RELEASE_ROOT}/pkg"
PKG_SCRIPTS_DIR="${RELEASE_ROOT}/pkg-scripts"
COMPONENT_PKG="${PKG_BUILD_DIR}/ros2native-component.pkg"
FINAL_PKG="${PKG_BUILD_DIR}/ros2native.pkg"
EXPANDED_DIR="${PKG_BUILD_DIR}/expanded"
REQUIREMENTS_PLIST="${PKG_BUILD_DIR}/product-requirements.plist"
PAYLOAD_LIST="${PKG_BUILD_DIR}/payload-files.txt"
VERSION="$(
  awk -F'"' '/^version = / {print $2; exit}' pyproject.toml
)"

for app_bundle in "${APP_PATH}" "${RVIZ_APP_PATH}" "${RQT_APP_PATH}"; do
  if [[ ! -d "${app_bundle}" ]]; then
    echo "ERROR: expected app bundle missing: ${app_bundle}" >&2
    exit 1
  fi
done

chmod -R u+w "${PKG_ROOT}" "${PKG_BUILD_DIR}" "${PKG_SCRIPTS_DIR}" 2>/dev/null || true
rm -rf "${PKG_ROOT}" "${PKG_BUILD_DIR}" "${PKG_SCRIPTS_DIR}"
mkdir -p "${PKG_ROOT}/Applications" "${PKG_BUILD_DIR}" "${PKG_SCRIPTS_DIR}"

ditto --noextattr --noqtn --norsrc "${APP_PATH}" "${PKG_ROOT}/Applications/$(basename "${APP_PATH}")"
ditto --noextattr --noqtn --norsrc "${RVIZ_APP_PATH}" "${PKG_ROOT}/Applications/$(basename "${RVIZ_APP_PATH}")"
ditto --noextattr --noqtn --norsrc "${RQT_APP_PATH}" "${PKG_ROOT}/Applications/$(basename "${RQT_APP_PATH}")"

find "${PKG_ROOT}" -name '._*' -delete
xattr -cr "${PKG_ROOT}" 2>/dev/null || true

cat > "${REQUIREMENTS_PLIST}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>arch</key>
  <array>
    <string>arm64</string>
  </array>
  <key>os</key>
  <array>
    <string>14.0</string>
  </array>
</dict>
</plist>
EOF

cat > "${PKG_SCRIPTS_DIR}/postinstall" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

MANAGED_MARKER="ros2native-managed"
TARGET_ROOT="${3:-/}"
if [[ -z "${TARGET_ROOT}" ]]; then
  TARGET_ROOT="/"
fi

BIN_DIR="${TARGET_ROOT%/}/usr/local/bin"
ROS2_TARGET="${BIN_DIR}/ros2"
ROS2_FALLBACK_TARGET="${BIN_DIR}/ros2native"
RVIZ2_TARGET="${BIN_DIR}/rviz2"
RVIZ2_FALLBACK_TARGET="${BIN_DIR}/ros2native-rviz2"
COLCON_TARGET="${BIN_DIR}/colcon"
COLCON_FALLBACK_TARGET="${BIN_DIR}/ros2native-colcon"
UNINSTALL_TARGET="${BIN_DIR}/ros2native-uninstall"

is_managed_target() {
  local target="$1"
  [[ -f "${target}" ]] && /usr/bin/grep -Fq "${MANAGED_MARKER}" "${target}"
}

write_runner_wrapper() {
  local target="$1"
  local command="$2"
  local tmp_path

  tmp_path="$(mktemp "${BIN_DIR}/.$(basename "${target}").XXXXXX")"
  cat > "${tmp_path}" <<EOF_WRAPPER
#!/usr/bin/env bash
# ${MANAGED_MARKER}
set -euo pipefail

SCRIPT_PATH="\${BASH_SOURCE[0]}"
INSTALL_ROOT="\$(cd "\$(dirname "\${SCRIPT_PATH}")/../../.." && pwd)"
RUNNER="\${INSTALL_ROOT}/Applications/ROS2Native.app/Contents/Resources/scripts/run_with_runtime_env.sh"

if [[ ! -x "\${RUNNER}" ]]; then
  echo "ERROR: ROS2 Native runtime launcher not found at \${RUNNER}" >&2
  exit 1
fi

exec "\${RUNNER}" ${command} "\$@"
EOF_WRAPPER
  chmod 755 "${tmp_path}"
  mv -f "${tmp_path}" "${target}"
}

write_uninstall_wrapper() {
  local target="$1"
  local tmp_path

  tmp_path="$(mktemp "${BIN_DIR}/.$(basename "${target}").XXXXXX")"
  cat > "${tmp_path}" <<EOF_WRAPPER
#!/usr/bin/env bash
# ${MANAGED_MARKER}
set -euo pipefail

SCRIPT_PATH="\${BASH_SOURCE[0]}"
INSTALL_ROOT="\$(cd "\$(dirname "\${SCRIPT_PATH}")/../../.." && pwd)"
UNINSTALLER="\${INSTALL_ROOT}/Applications/ROS2Native.app/Contents/Resources/scripts/uninstall_ros2native.sh"

if [[ ! -x "\${UNINSTALLER}" ]]; then
  echo "ERROR: ROS2 Native uninstaller not found at \${UNINSTALLER}" >&2
  exit 1
fi

exec "\${UNINSTALLER}" "\$@"
EOF_WRAPPER
  chmod 755 "${tmp_path}"
  mv -f "${tmp_path}" "${target}"
}

mkdir -p "${BIN_DIR}"

install_runner() {
  local target="$1"
  local fallback_target="$2"
  local command="$3"

  if [[ ! -e "${fallback_target}" ]] || is_managed_target "${fallback_target}"; then
    write_runner_wrapper "${fallback_target}" "${command}"
  else
    echo "warning: preserving existing ${fallback_target}" >&2
  fi

  if [[ ! -e "${target}" ]] || is_managed_target "${target}"; then
    write_runner_wrapper "${target}" "${command}"
  else
    echo "warning: preserving existing ${target}; use ${fallback_target} for the packaged runtime" >&2
  fi
}

install_runner "${ROS2_TARGET}" "${ROS2_FALLBACK_TARGET}" ros2
install_runner "${RVIZ2_TARGET}" "${RVIZ2_FALLBACK_TARGET}" rviz2
install_runner "${COLCON_TARGET}" "${COLCON_FALLBACK_TARGET}" colcon

if [[ ! -e "${UNINSTALL_TARGET}" ]] || is_managed_target "${UNINSTALL_TARGET}"; then
  write_uninstall_wrapper "${UNINSTALL_TARGET}"
else
  echo "warning: preserving existing ${UNINSTALL_TARGET}" >&2
fi

exit 0
EOF
chmod 755 "${PKG_SCRIPTS_DIR}/postinstall"

PKGBUILD_ARGS=(
  --root "${PKG_ROOT}"
  --identifier io.github.taiga.ros2native.payload
  --version "${VERSION}"
  --install-location /
  --scripts "${PKG_SCRIPTS_DIR}"
)
if [[ -n "${PKG_SIGN_IDENTITY:-}" ]]; then
  PKGBUILD_ARGS+=(--sign "${PKG_SIGN_IDENTITY}")
fi
pkgbuild "${PKGBUILD_ARGS[@]}" "${COMPONENT_PKG}"

PRODUCTBUILD_ARGS=(
  --package "${COMPONENT_PKG}"
  --product "${REQUIREMENTS_PLIST}"
  --identifier io.github.taiga.ros2native
  --version "${VERSION}"
)
if [[ -n "${PRODUCT_SIGN_IDENTITY:-}" ]]; then
  PRODUCTBUILD_ARGS+=(--sign "${PRODUCT_SIGN_IDENTITY}")
fi
productbuild "${PRODUCTBUILD_ARGS[@]}" "${FINAL_PKG}"

chmod -R u+w "${EXPANDED_DIR}" 2>/dev/null || true
rm -rf "${EXPANDED_DIR}"
if ! pkgutil --expand-full "${FINAL_PKG}" "${EXPANDED_DIR}"; then
  echo "warning: could not expand ${FINAL_PKG} for inspection" >&2
fi
pkgutil --payload-files "${FINAL_PKG}" >"${PAYLOAD_LIST}"

if ! rg -q '(^|\./)Applications/ROS2Native\.app($|/)' "${PAYLOAD_LIST}"; then
  echo "ERROR: packaged payload is missing ROS2Native.app" >&2
  exit 1
fi

if ! rg -q '(^|\./)Applications/RViz 2\.app($|/)' "${PAYLOAD_LIST}"; then
  echo "ERROR: packaged payload is missing RViz 2.app" >&2
  exit 1
fi

if ! rg -q '(^|\./)Applications/rqt\.app($|/)' "${PAYLOAD_LIST}"; then
  echo "ERROR: packaged payload is missing rqt.app" >&2
  exit 1
fi

if [[ ! -x "${PKG_SCRIPTS_DIR}/postinstall" ]]; then
  echo "ERROR: package postinstall script was not generated." >&2
  exit 1
fi

if [[ -n "${PRODUCT_SIGN_IDENTITY:-}" || -n "${PKG_SIGN_IDENTITY:-}" ]]; then
  pkgutil --check-signature "${FINAL_PKG}"
fi

echo "Created ${FINAL_PKG}"
