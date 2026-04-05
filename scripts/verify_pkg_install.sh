#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PKG_PATH="${PKG_PATH:-${ROOT_DIR}/.release/pkg/ros2native.pkg}"
VERIFY_ROOT="${ROOT_DIR}/.release/pkg-verify"
MOUNT_POINT="${VERIFY_ROOT}/mnt"
DISK_IMAGE="${VERIFY_ROOT}/ros2native-test.sparseimage"
VOLUME_NAME="${VOLUME_NAME:-ROS2NativeTest}"
VOLUME_SIZE="${VOLUME_SIZE:-6g}"
INSTALLER_LOG="${VERIFY_ROOT}/installer.log"
INSTALL_MODE=""

cleanup() {
  if mount | /usr/bin/grep -Fq "on ${MOUNT_POINT} "; then
    hdiutil detach "${MOUNT_POINT}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

if [[ ! -f "${PKG_PATH}" ]]; then
  echo "ERROR: package not found at ${PKG_PATH}" >&2
  exit 1
fi

cleanup
chmod -R u+w "${VERIFY_ROOT}" 2>/dev/null || true
rm -rf "${VERIFY_ROOT}"
mkdir -p "${VERIFY_ROOT}" "${MOUNT_POINT}"

hdiutil create \
  -quiet \
  -type SPARSE \
  -fs APFS \
  -size "${VOLUME_SIZE}" \
  -volname "${VOLUME_NAME}" \
  "${DISK_IMAGE}"

hdiutil attach \
  -quiet \
  -nobrowse \
  -owners on \
  -mountpoint "${MOUNT_POINT}" \
  "${DISK_IMAGE}"

if /usr/sbin/installer -allowUntrusted -pkg "${PKG_PATH}" -target "${MOUNT_POINT}" >"${INSTALLER_LOG}" 2>&1; then
  INSTALL_MODE="installer"
else
  if /usr/bin/grep -Fq 'Must be run as root to install this package.' "${INSTALLER_LOG}"; then
    INSTALL_MODE="simulated"
    ditto --noextattr --noqtn --norsrc "${ROOT_DIR}/.release/pkgroot" "${MOUNT_POINT}"
    /bin/bash "${ROOT_DIR}/.release/pkg-scripts/postinstall" "${PKG_PATH}" "/" "${MOUNT_POINT}"
  else
    echo "ERROR: package installation failed for target ${MOUNT_POINT}" >&2
    cat "${INSTALLER_LOG}" >&2
    exit 1
  fi
fi

ROS2_WRAPPER="${MOUNT_POINT}/usr/local/bin/ros2"
ROS2_FALLBACK="${MOUNT_POINT}/usr/local/bin/ros2native"
RVIZ2_WRAPPER="${MOUNT_POINT}/usr/local/bin/rviz2"
RVIZ2_FALLBACK="${MOUNT_POINT}/usr/local/bin/ros2native-rviz2"
COLCON_WRAPPER="${MOUNT_POINT}/usr/local/bin/colcon"
COLCON_FALLBACK="${MOUNT_POINT}/usr/local/bin/ros2native-colcon"
UNINSTALL_WRAPPER="${MOUNT_POINT}/usr/local/bin/ros2native-uninstall"
APP_BUNDLE="${MOUNT_POINT}/Applications/ROS2Native.app"

for required_path in \
  "${ROS2_WRAPPER}" \
  "${ROS2_FALLBACK}" \
  "${RVIZ2_WRAPPER}" \
  "${RVIZ2_FALLBACK}" \
  "${COLCON_WRAPPER}" \
  "${COLCON_FALLBACK}" \
  "${UNINSTALL_WRAPPER}" \
  "${APP_BUNDLE}"; do
  if [[ ! -e "${required_path}" ]]; then
    echo "ERROR: installed package is missing ${required_path}" >&2
    exit 1
  fi
done

chmod -R a-w "${APP_BUNDLE}"

"${ROS2_WRAPPER}" --help >/dev/null
"${ROS2_FALLBACK}" --help >/dev/null
"${RVIZ2_WRAPPER}" --help >/dev/null
"${RVIZ2_FALLBACK}" --help >/dev/null
"${COLCON_WRAPPER}" --help >/dev/null
"${COLCON_FALLBACK}" --help >/dev/null
"${ROS2_WRAPPER}" topic list >/dev/null
"${APP_BUNDLE}/Contents/Resources/scripts/run_with_runtime_env.sh" python -c 'import rclpy'

"${UNINSTALL_WRAPPER}" --yes

for removed_path in \
  "${ROS2_WRAPPER}" \
  "${ROS2_FALLBACK}" \
  "${RVIZ2_WRAPPER}" \
  "${RVIZ2_FALLBACK}" \
  "${COLCON_WRAPPER}" \
  "${COLCON_FALLBACK}" \
  "${UNINSTALL_WRAPPER}" \
  "${APP_BUNDLE}"; do
  if [[ -e "${removed_path}" || -L "${removed_path}" ]]; then
    echo "ERROR: uninstaller left behind ${removed_path}" >&2
    exit 1
  fi
done

echo "Package install/uninstall verification passed for ${PKG_PATH}"
echo "Verification mode: ${INSTALL_MODE}"
