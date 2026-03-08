#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

apply_patch_file() {
  local patch_file="$1"
  if patch -R -p0 -N -l --dry-run < "${patch_file}" >/dev/null 2>&1; then
    echo "Patch already applied: ${patch_file}"
    return
  fi
  echo "Applying patch: ${patch_file}"
  patch -p0 -N -l < "${patch_file}"
}

apply_patch_file "${ROOT_DIR}/patches/ros2_console_bridge_vendor.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_rviz_ogre_vendor.patch"
apply_patch_file "${ROOT_DIR}/patches/ros_visualization_rqt_bag.patch"
