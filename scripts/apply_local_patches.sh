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
apply_patch_file "${ROOT_DIR}/patches/ros2_rviz_ogre_vendor_sdkroot.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_rviz_ogre_vendor_disable_meshlod.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_rviz_ogre_vendor_disable_pugixml_consumers.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_rviz_ogre_vendor_xcrun.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_rviz_ogre_vendor_patch_idempotent.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_qt_gui_cpp_optional_bindings.patch"
apply_patch_file "${ROOT_DIR}/patches/ros_visualization_rqt_bag.patch"
apply_patch_file "${ROOT_DIR}/patches/foxglove_bridge_macos_sdk.patch"
apply_patch_file "${ROOT_DIR}/patches/perception_pcl_minimal_pcl_components.patch"
apply_patch_file "${ROOT_DIR}/patches/image_view_boost_include_dirs.patch"
apply_patch_file "${ROOT_DIR}/patches/realtime_tools_macos_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/ros2_control_controller_manager_backward_ros_optional.patch"
apply_patch_file "${ROOT_DIR}/patches/geometric_shapes_assimp_target_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_distance_map_key_const_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_cached_ik_random_shuffle_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_ompl_openmp_optional.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_perception_openmp_cxx_only.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_perception_openmp_subdirs_optional.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_benchmarks_boost_timer_deprecated_guard.patch"
apply_patch_file "${ROOT_DIR}/patches/moveit2_pilz_planning_context_loader_link_fix.patch"
apply_patch_file "${ROOT_DIR}/patches/warehouse_ros_tf2_buffer_header_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_odom_callback_const.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_costmap_filter_override.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_graphicsmagick_libcpp_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_constrained_smoother_ceres_config.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_mppi_controller_clang_flags.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_smac_planner_openmp_optional.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_clang_template_and_callback_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/navigation2_system_tests_gazebo_optional_when_not_testing.patch"
apply_patch_file "${ROOT_DIR}/patches/slam_toolbox_macos_deps_compat.patch"
apply_patch_file "${ROOT_DIR}/patches/velodyne_pointcloud_yaml_cpp_include_dirs.patch"
