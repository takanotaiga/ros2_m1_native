#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
HOST_ARCH="$(uname -m)"
THIRD_PARTY_SRC_DIR="${ROOT_DIR}/.deps/third_party"
CMAKE_BIN="${ROOT_DIR}/.local/tools/cmake/bin/cmake"
NATIVE_PREFIX="${ROOT_DIR}/.local/deps"
QT_PREFIX="${NATIVE_PREFIX}/qt5"

if [[ "${HOST_ARCH}" != "arm64" && "${HOST_ARCH}" != "x86_64" ]]; then
  echo "ERROR: unsupported host architecture: ${HOST_ARCH}" >&2
  exit 1
fi

uv run python "${ROOT_DIR}/scripts/sync_git_repos.py" \
  --manifest "${ROOT_DIR}/third_party.repos" \
  --root "${THIRD_PARTY_SRC_DIR}" \
  --force-clean

mkdir -p "${NATIVE_PREFIX}"
export PATH="${NATIVE_PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${NATIVE_PREFIX}/lib/pkgconfig:${NATIVE_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"

TINYXML2_SRC_DIR="${THIRD_PARTY_SRC_DIR}/leethomason/tinyxml2"
TINYXML2_BUILD_DIR="${ROOT_DIR}/.build/tinyxml2"
EIGEN_SRC_DIR="${THIRD_PARTY_SRC_DIR}/libeigen/eigen"
EIGEN_BUILD_DIR="${ROOT_DIR}/.build/eigen"
CERES_SRC_DIR="${THIRD_PARTY_SRC_DIR}/ceres-solver/ceres-solver"
CERES_BUILD_DIR="${ROOT_DIR}/.build/ceres"
GEOGRAPHICLIB_SRC_DIR="${THIRD_PARTY_SRC_DIR}/geographiclib/geographiclib"
GEOGRAPHICLIB_BUILD_DIR="${ROOT_DIR}/.build/geographiclib"
XTL_SRC_DIR="${THIRD_PARTY_SRC_DIR}/xtensor-stack/xtl"
XTL_BUILD_DIR="${ROOT_DIR}/.build/xtl"
XSIMD_SRC_DIR="${THIRD_PARTY_SRC_DIR}/xtensor-stack/xsimd"
XSIMD_BUILD_DIR="${ROOT_DIR}/.build/xsimd"
XTENSOR_SRC_DIR="${THIRD_PARTY_SRC_DIR}/xtensor-stack/xtensor"
XTENSOR_BUILD_DIR="${ROOT_DIR}/.build/xtensor"
NANOFLANN_SRC_DIR="${THIRD_PARTY_SRC_DIR}/jlblancoc/nanoflann"
NANOFLANN_BUILD_DIR="${ROOT_DIR}/.build/nanoflann"
OMPL_SRC_DIR="${THIRD_PARTY_SRC_DIR}/ompl/ompl"
OMPL_BUILD_DIR="${ROOT_DIR}/.build/ompl"
ASIO_SRC_DIR="${THIRD_PARTY_SRC_DIR}/chriskohlhoff/asio"
BOOST_SRC_DIR="${THIRD_PARTY_SRC_DIR}/boostorg/boost"
RAPIDJSON_SRC_DIR="${THIRD_PARTY_SRC_DIR}/tencent/rapidjson"
NLOHMANN_JSON_SRC_DIR="${THIRD_PARTY_SRC_DIR}/nlohmann/json"
NLOHMANN_JSON_BUILD_DIR="${ROOT_DIR}/.build/nlohmann_json"
FMT_SRC_DIR="${THIRD_PARTY_SRC_DIR}/fmtlib/fmt"
FMT_BUILD_DIR="${ROOT_DIR}/.build/fmt"
RUCKIG_SRC_DIR="${THIRD_PARTY_SRC_DIR}/pantor/ruckig"
RUCKIG_BUILD_DIR="${ROOT_DIR}/.build/ruckig"
LZ4_SRC_DIR="${THIRD_PARTY_SRC_DIR}/lz4/lz4"
GLEW_SRC_DIR="${THIRD_PARTY_SRC_DIR}/Perlmint/glew-cmake"
GLEW_BUILD_DIR="${ROOT_DIR}/.build/glew"
FREEGLUT_SRC_DIR="${THIRD_PARTY_SRC_DIR}/freeglut/freeglut"
FREEGLUT_BUILD_DIR="${ROOT_DIR}/.build/freeglut"
GRAPHICSMAGICK_SRC_DIR="${THIRD_PARTY_SRC_DIR}/GraphicsMagick/graphicsmagick"
FLANN_SRC_DIR="${THIRD_PARTY_SRC_DIR}/flann-lib/flann"
FLANN_BUILD_DIR="${ROOT_DIR}/.build/flann"
QHULL_SRC_DIR="${THIRD_PARTY_SRC_DIR}/qhull/qhull"
QHULL_BUILD_DIR="${ROOT_DIR}/.build/qhull"
PCL_SRC_DIR="${THIRD_PARTY_SRC_DIR}/pointcloudlibrary/pcl"
PCL_BUILD_DIR="${ROOT_DIR}/.build/pcl"
BULLET_SRC_DIR="${THIRD_PARTY_SRC_DIR}/bulletphysics/bullet3"
BULLET_BUILD_DIR="${ROOT_DIR}/.build/bullet3"
ASSIMP_SRC_DIR="${THIRD_PARTY_SRC_DIR}/assimp/assimp"
ASSIMP_BUILD_DIR="${ROOT_DIR}/.build/assimp"
OCTOMAP_SRC_DIR="${THIRD_PARTY_SRC_DIR}/OctoMap/octomap"
OCTOMAP_BUILD_DIR="${ROOT_DIR}/.build/octomap"
LIBCCD_SRC_DIR="${THIRD_PARTY_SRC_DIR}/danfis/libccd"
LIBCCD_BUILD_DIR="${ROOT_DIR}/.build/libccd"
FCL_SRC_DIR="${THIRD_PARTY_SRC_DIR}/flexible-collision-library/fcl"
FCL_BUILD_DIR="${ROOT_DIR}/.build/fcl"
OPENCV_SRC_DIR="${THIRD_PARTY_SRC_DIR}/opencv/opencv"
OPENCV_BUILD_DIR="${ROOT_DIR}/.build/opencv"
QTBASE_SRC_DIR="${THIRD_PARTY_SRC_DIR}/qt/qtbase"
QTBASE_BUILD_DIR="${ROOT_DIR}/.build/qtbase"
QTSVG_SRC_DIR="${THIRD_PARTY_SRC_DIR}/qt/qtsvg"
QTSVG_BUILD_DIR="${ROOT_DIR}/.build/qtsvg"
QT_QMAKE="${QT_PREFIX}/bin/qmake"
QT_MAC_CONF="${QTBASE_SRC_DIR}/mkspecs/common/mac.conf"
QT_PNG_PRIV="${QTBASE_SRC_DIR}/src/3rdparty/libpng/pngpriv.h"
QT_IOSURFACE_HEADER="${QTBASE_SRC_DIR}/src/plugins/platforms/cocoa/qiosurfacegraphicsbuffer.h"
PCL_ASCII_IO_SRC="${PCL_SRC_DIR}/io/src/ascii_io.cpp"
PCL_IMAGE_GRABBER_SRC="${PCL_SRC_DIR}/io/src/image_grabber.cpp"
XTENSOR_PATCH_FILE="${ROOT_DIR}/patches/xtensor_svector_rebind_clang_fix.patch"
GLEW_PATCH_FILE="${ROOT_DIR}/patches/glew_cmake_macos_no_x11.patch"

apply_git_patch_if_needed() {
  local repo_dir="$1"
  local patch_file="$2"
  if [[ ! -f "${patch_file}" ]]; then
    echo "ERROR: patch file not found: ${patch_file}" >&2
    exit 1
  fi
  if git -C "${repo_dir}" apply --check "${patch_file}" >/dev/null 2>&1; then
    git -C "${repo_dir}" apply "${patch_file}"
    return
  fi
  if git -C "${repo_dir}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
    return
  fi
  echo "ERROR: failed to apply patch '${patch_file}' in '${repo_dir}'." >&2
  exit 1
}

if [[ -z "${SDKROOT:-}" ]] && command -v xcrun >/dev/null 2>&1; then
  SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
  export SDKROOT
fi

if [[ -f "${QT_MAC_CONF}" ]]; then
  # AGL was removed from modern macOS SDKs; keep only OpenGL framework paths/libs.
  sed -i '' '/AGL\.framework/d' "${QT_MAC_CONF}"
  sed -i '' 's/ -framework AGL//g' "${QT_MAC_CONF}"
fi

if [[ -f "${QT_PNG_PRIV}" ]]; then
  # Modern SDKs don't ship fp.h; force libpng to include math.h on macOS.
  perl -0777 -i -pe 's/\|\| \\\n    defined\(THINK_C\) \|\| defined\(__SC__\) \|\| defined\(TARGET_OS_MAC\)/|| \\\n    defined(THINK_C) || defined(__SC__)/g' "${QT_PNG_PRIV}"
fi

if [[ -f "${QT_IOSURFACE_HEADER}" ]] && ! grep -q "CGColorSpace.h" "${QT_IOSURFACE_HEADER}"; then
  perl -0777 -i -pe 's/#include <private\/qcore_mac_p\.h>\n/#include <private\/qcore_mac_p.h>\n#include <CoreGraphics\/CGColorSpace.h>\n/' "${QT_IOSURFACE_HEADER}"
fi

if [[ -f "${PCL_ASCII_IO_SRC}" ]]; then
  perl -0777 -i -pe 's/boost::filesystem::extension\s*\(fpath\)/fpath.extension().string()/g' "${PCL_ASCII_IO_SRC}"
fi

if [[ -f "${PCL_IMAGE_GRABBER_SRC}" ]]; then
  perl -0777 -i -pe 's/boost::algorithm::to_upper_copy\s*\(boost::filesystem::extension\s*\(itr->path\s*\(\)\)\)/boost::algorithm::to_upper_copy (itr->path ().extension().string())/g' "${PCL_IMAGE_GRABBER_SRC}"
  perl -0777 -i -pe 's/boost::filesystem::basename\s*\(itr->path\s*\(\)\)/itr->path ().stem().string()/g' "${PCL_IMAGE_GRABBER_SRC}"
  perl -0777 -i -pe 's/boost::filesystem::basename\s*\(filepath\)/boost::filesystem::path(filepath).stem().string()/g' "${PCL_IMAGE_GRABBER_SRC}"
  perl -0777 -i -pe 's/boost::filesystem::basename\s*\(pathname\)/boost::filesystem::path(pathname).stem().string()/g' "${PCL_IMAGE_GRABBER_SRC}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libtinyxml2.dylib" ]]; then
  rm -rf "${TINYXML2_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${TINYXML2_SRC_DIR}" -B "${TINYXML2_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}"
  "${CMAKE_BIN}" --build "${TINYXML2_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${TINYXML2_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/include/eigen3/Eigen/Core" ]]; then
  rm -rf "${EIGEN_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${EIGEN_SRC_DIR}" -B "${EIGEN_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}"
  "${CMAKE_BIN}" --build "${EIGEN_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${EIGEN_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/cmake/Ceres/CeresConfig.cmake" ]]; then
  rm -rf "${CERES_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${CERES_SRC_DIR}" -B "${CERES_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_BENCHMARKS=OFF \
    -DBUILD_DOCUMENTATION=OFF \
    -DMINIGLOG=ON \
    -DGFLAGS=OFF \
    -DSUITESPARSE=OFF \
    -DCXSPARSE=OFF \
    -DLAPACK=OFF \
    -DEIGENSPARSE=ON \
    -DCUDA=OFF
  "${CMAKE_BIN}" --build "${CERES_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${CERES_BUILD_DIR}"
fi

apply_git_patch_if_needed "${XTENSOR_SRC_DIR}" "${XTENSOR_PATCH_FILE}"
apply_git_patch_if_needed "${GLEW_SRC_DIR}" "${GLEW_PATCH_FILE}"

if [[ ! -f "${NATIVE_PREFIX}/lib/cmake/GeographicLib/GeographicLibConfig.cmake" ]]; then
  rm -rf "${GEOGRAPHICLIB_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${GEOGRAPHICLIB_SRC_DIR}" -B "${GEOGRAPHICLIB_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DGEOGRAPHICLIB_DOCUMENTATION=OFF \
    -DGEOGRAPHICLIB_TESTING=OFF
  "${CMAKE_BIN}" --build "${GEOGRAPHICLIB_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${GEOGRAPHICLIB_BUILD_DIR}"
fi

XSIMD_VERSION_OK=0
if [[ -f "${NATIVE_PREFIX}/include/xsimd/config/xsimd_config.hpp" ]]; then
  XSIMD_VERSION="$(
    awk '
      /XSIMD_VERSION_MAJOR/ {maj=$3}
      /XSIMD_VERSION_MINOR/ {min=$3}
      /XSIMD_VERSION_PATCH/ {pat=$3}
      END {if (maj != "") printf "%s.%s.%s", maj, min, pat}
    ' "${NATIVE_PREFIX}/include/xsimd/config/xsimd_config.hpp"
  )"
  if [[ "${XSIMD_VERSION}" == "9.0.1" ]]; then
    XSIMD_VERSION_OK=1
  fi
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/cmake/xsimd/xsimdConfig.cmake" || "${XSIMD_VERSION_OK}" -ne 1 ]]; then
  rm -rf "${NATIVE_PREFIX}/include/xsimd" "${NATIVE_PREFIX}/lib/cmake/xsimd" "${NATIVE_PREFIX}/lib/pkgconfig/xsimd.pc"
  rm -rf "${XSIMD_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${XSIMD_SRC_DIR}" -B "${XSIMD_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_TESTS=OFF \
    -DDOWNLOAD_GTEST=OFF
  "${CMAKE_BIN}" --build "${XSIMD_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${XSIMD_BUILD_DIR}"
fi

XTL_VERSION_OK=0
if [[ -f "${NATIVE_PREFIX}/include/xtl/xtl_config.hpp" ]]; then
  XTL_VERSION="$(
    awk '
      /XTL_VERSION_MAJOR/ {maj=$3}
      /XTL_VERSION_MINOR/ {min=$3}
      /XTL_VERSION_PATCH/ {pat=$3}
      END {if (maj != "") printf "%s.%s.%s", maj, min, pat}
    ' "${NATIVE_PREFIX}/include/xtl/xtl_config.hpp"
  )"
  if [[ "${XTL_VERSION}" == "0.7.2" ]]; then
    XTL_VERSION_OK=1
  fi
fi

if [[ ! -f "${NATIVE_PREFIX}/share/cmake/xtl/xtlConfig.cmake" || "${XTL_VERSION_OK}" -ne 1 ]]; then
  rm -rf "${NATIVE_PREFIX}/include/xtl" "${NATIVE_PREFIX}/share/cmake/xtl" "${NATIVE_PREFIX}/share/pkgconfig/xtl.pc"
  rm -rf "${XTL_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${XTL_SRC_DIR}" -B "${XTL_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_TESTS=OFF \
    -DDOWNLOAD_GTEST=OFF
  "${CMAKE_BIN}" --build "${XTL_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${XTL_BUILD_DIR}"
fi

XTENSOR_VERSION_OK=0
if [[ -f "${NATIVE_PREFIX}/include/xtensor/xtensor_config.hpp" ]]; then
  XTENSOR_VERSION="$(
    awk '
      /XTENSOR_VERSION_MAJOR/ {maj=$3}
      /XTENSOR_VERSION_MINOR/ {min=$3}
      /XTENSOR_VERSION_PATCH/ {pat=$3}
      END {if (maj != "") printf "%s.%s.%s", maj, min, pat}
    ' "${NATIVE_PREFIX}/include/xtensor/xtensor_config.hpp"
  )"
  if [[ "${XTENSOR_VERSION}" == "0.24.3" ]]; then
    XTENSOR_VERSION_OK=1
  fi
fi

XTENSOR_PATCH_OK=0
if [[ -f "${NATIVE_PREFIX}/include/xtensor/xutils.hpp" ]] && \
  grep -q "rebind_container<X, svector<T, N, std::allocator<T>, true>>" \
  "${NATIVE_PREFIX}/include/xtensor/xutils.hpp"; then
  XTENSOR_PATCH_OK=1
fi

if [[ ! -f "${NATIVE_PREFIX}/share/cmake/xtensor/xtensorConfig.cmake" || \
  "${XTENSOR_VERSION_OK}" -ne 1 || \
  "${XTENSOR_PATCH_OK}" -ne 1 ]]; then
  rm -rf "${NATIVE_PREFIX}/include/xtensor" "${NATIVE_PREFIX}/include/xtensor.hpp" "${NATIVE_PREFIX}/share/cmake/xtensor" "${NATIVE_PREFIX}/share/pkgconfig/xtensor.pc"
  rm -rf "${XTENSOR_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${XTENSOR_SRC_DIR}" -B "${XTENSOR_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DBUILD_TESTS=OFF \
    -DBUILD_BENCHMARK=OFF \
    -DDOWNLOAD_GTEST=OFF \
    -DDOWNLOAD_GBENCHMARK=OFF
  "${CMAKE_BIN}" --build "${XTENSOR_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${XTENSOR_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/share/cmake/nanoflann/nanoflannConfig.cmake" ]]; then
  rm -rf "${NANOFLANN_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${NANOFLANN_SRC_DIR}" -B "${NANOFLANN_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DNANOFLANN_BUILD_EXAMPLES=OFF \
    -DNANOFLANN_BUILD_TESTS=OFF \
    -DNANOFLANN_USE_SYSTEM_GTEST=ON
  "${CMAKE_BIN}" --build "${NANOFLANN_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${NANOFLANN_BUILD_DIR}"
fi

build_boost_if_needed() {
  local boost_python_executable=""
  local boost_python_version=""
  local boost_python_tag=""
  local boost_python_include_dir=""
  local boost_python_lib_dir=""
  local boost_python_lib=""
  local required_boost_paths=(
    "${NATIVE_PREFIX}/include/boost/version.hpp"
    "${NATIVE_PREFIX}/lib/libboost_system.dylib"
    "${NATIVE_PREFIX}/lib/libboost_program_options.dylib"
    "${NATIVE_PREFIX}/lib/libboost_filesystem.dylib"
    "${NATIVE_PREFIX}/lib/libboost_serialization.dylib"
    "${NATIVE_PREFIX}/lib/libboost_random.dylib"
  )

  if [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
    boost_python_executable="$("${ROOT_DIR}/.venv/bin/python" -c 'import pathlib,sys; print(pathlib.Path(sys.base_prefix) / "bin" / "python3")')"
  fi
  if [[ -z "${boost_python_executable}" || ! -x "${boost_python_executable}" ]]; then
    boost_python_executable="$(command -v python3 || true)"
  fi
  if [[ -z "${boost_python_executable}" || ! -x "${boost_python_executable}" ]]; then
    echo "ERROR: python3 executable is required to build Boost.Python." >&2
    exit 1
  fi

  boost_python_version="$("${boost_python_executable}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  boost_python_tag="$("${boost_python_executable}" -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor}")')"
  boost_python_include_dir="$("${boost_python_executable}" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
  boost_python_lib_dir="$("${boost_python_executable}" -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')"
  boost_python_lib="${NATIVE_PREFIX}/lib/libboost_python${boost_python_tag}.dylib"

  local path
  local missing_boost=0
  for path in "${required_boost_paths[@]}" "${boost_python_lib}"; do
    if [[ ! -f "${path}" ]]; then
      missing_boost=1
      break
    fi
  done

  if [[ "${missing_boost}" -eq 0 ]]; then
    return
  fi

  pushd "${BOOST_SRC_DIR}" >/dev/null
  git submodule update --init --recursive --jobs "${JOBS}"
  ./bootstrap.sh --prefix="${NATIVE_PREFIX}" --with-python="${boost_python_executable}"
  ./b2 -j"${JOBS}" \
    toolset=clang \
    variant=release \
    link=shared \
    runtime-link=shared \
    threading=multi \
    python="${boost_python_version}" \
    include="${boost_python_include_dir}" \
    library-path="${boost_python_lib_dir}" \
    --layout=system \
    cxxflags="-std=c++17 -arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
    linkflags="-arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
    install \
    --with-atomic \
    --with-chrono \
    --with-date_time \
    --with-filesystem \
    --with-iostreams \
    --with-python \
    --with-program_options \
    --with-random \
    --with-regex \
    --with-serialization \
    --with-system \
    --with-thread
  popd >/dev/null
}

build_boost_if_needed

if [[ ! -f "${NATIVE_PREFIX}/share/ompl/cmake/omplConfig.cmake" ]]; then
  rm -rf "${OMPL_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${OMPL_SRC_DIR}" -B "${OMPL_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBoost_NO_BOOST_CMAKE=ON \
    -DBOOST_ROOT="${NATIVE_PREFIX}" \
    -DBOOST_INCLUDEDIR="${NATIVE_PREFIX}/include" \
    -DBOOST_LIBRARYDIR="${NATIVE_PREFIX}/lib" \
    -DOMPL_BUILD_DEMOS=OFF \
    -DOMPL_BUILD_TESTS=OFF \
    -DOMPL_BUILD_PYBINDINGS=OFF \
    -DOMPL_BUILD_PYTESTS=OFF \
    -DOMPL_REGISTRATION=OFF
  "${CMAKE_BIN}" --build "${OMPL_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${OMPL_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/include/asio.hpp" ]]; then
  mkdir -p "${NATIVE_PREFIX}/include"
  rm -rf "${NATIVE_PREFIX}/include/asio" "${NATIVE_PREFIX}/include/asio.hpp"
  cp -R "${ASIO_SRC_DIR}/asio/include/asio" "${NATIVE_PREFIX}/include/"
  cp "${ASIO_SRC_DIR}/asio/include/asio.hpp" "${NATIVE_PREFIX}/include/"
fi

if [[ ! -f "${NATIVE_PREFIX}/include/rapidjson/document.h" ]]; then
  mkdir -p "${NATIVE_PREFIX}/include"
  rm -rf "${NATIVE_PREFIX}/include/rapidjson"
  cp -R "${RAPIDJSON_SRC_DIR}/include/rapidjson" "${NATIVE_PREFIX}/include/"
fi

if [[ ! -f "${NATIVE_PREFIX}/include/nlohmann/json.hpp" ]]; then
  rm -rf "${NLOHMANN_JSON_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${NLOHMANN_JSON_SRC_DIR}" -B "${NLOHMANN_JSON_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DJSON_BuildTests=OFF \
    -DJSON_Install=ON
  "${CMAKE_BIN}" --build "${NLOHMANN_JSON_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${NLOHMANN_JSON_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libfmt.dylib" ]]; then
  rm -rf "${FMT_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${FMT_SRC_DIR}" -B "${FMT_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DFMT_DOC=OFF \
    -DFMT_TEST=OFF
  "${CMAKE_BIN}" --build "${FMT_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${FMT_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libruckig.dylib" ]]; then
  rm -rf "${RUCKIG_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${RUCKIG_SRC_DIR}" -B "${RUCKIG_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_PYTHON_MODULE=OFF \
    -DBUILD_ONLINE_CLIENT=OFF \
    -DBUILD_BENCHMARK=OFF
  "${CMAKE_BIN}" --build "${RUCKIG_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${RUCKIG_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/liblz4.dylib" ]]; then
  pushd "${LZ4_SRC_DIR}" >/dev/null
  make -C lib -j"${JOBS}" PREFIX="${NATIVE_PREFIX}"
  make -C lib PREFIX="${NATIVE_PREFIX}" install
  popd >/dev/null
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libglew.dylib" && ! -f "${NATIVE_PREFIX}/lib/libGLEW.dylib" ]]; then
  rm -rf "${GLEW_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${GLEW_SRC_DIR}" -B "${GLEW_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DONLY_LIBS=ON \
    -Dglew-cmake_BUILD_SHARED=ON \
    -Dglew-cmake_BUILD_STATIC=OFF \
    -DUSE_GLU=OFF
  "${CMAKE_BIN}" --build "${GLEW_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${GLEW_BUILD_DIR}"
fi

if [[ -d "${NATIVE_PREFIX}/lib/cmake/glew" ]]; then
  rm -rf "${NATIVE_PREFIX}/lib/cmake/glew"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libglut.dylib" && ! -f "${NATIVE_PREFIX}/lib/libfreeglut.dylib" ]]; then
  rm -rf "${FREEGLUT_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${FREEGLUT_SRC_DIR}" -B "${FREEGLUT_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DFREEGLUT_COCOA=ON \
    -DFREEGLUT_GLES=OFF \
    -DFREEGLUT_BUILD_STATIC_LIBS=OFF \
    -DFREEGLUT_BUILD_DEMOS=OFF
  "${CMAKE_BIN}" --build "${FREEGLUT_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${FREEGLUT_BUILD_DIR}"
fi

mkdir -p "${NATIVE_PREFIX}/bin"
cat > "${NATIVE_PREFIX}/bin/pkg-config" <<EOF
#!/usr/bin/env bash
set -euo pipefail
prefix="${NATIVE_PREFIX}"
if [[ "\${1:-}" == "--version" ]]; then
  echo "0.29.2"
  exit 0
fi
if [[ "\${1:-}" == "--atleast-pkgconfig-version" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "--help" ]]; then
  echo "pkg-config shim"
  exit 0
fi
pkg=""
for arg in "\$@"; do
  case "\$arg" in
    --*|*=*) ;;
    *) pkg="\$arg" ;;
  esac
done
if [[ "\$pkg" != "liblz4" ]]; then
  exit 1
fi
for arg in "\$@"; do
  if [[ "\$arg" == "--exists" ]]; then
    exit 0
  fi
done
out=()
for arg in "\$@"; do
  case "\$arg" in
    --modversion) out+=("1.10.0") ;;
    --cflags|--cflags-only-I) out+=("-I\${prefix}/include") ;;
    --libs) out+=("-L\${prefix}/lib" "-llz4") ;;
    --libs-only-L) out+=("-L\${prefix}/lib") ;;
    --libs-only-l) out+=("-llz4") ;;
    *) ;;
  esac
done
if (( \${#out[@]} > 0 )); then
  printf '%s ' "\${out[@]}"
  printf '\n'
fi
EOF
chmod +x "${NATIVE_PREFIX}/bin/pkg-config"

if [[ ! -f "${NATIVE_PREFIX}/lib/libflann_cpp.dylib" ]]; then
  rm -rf "${FLANN_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${FLANN_SRC_DIR}" -B "${FLANN_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_C_BINDINGS=ON \
    -DBUILD_MATLAB_BINDINGS=OFF \
    -DBUILD_PYTHON_BINDINGS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_DOC=OFF \
    -DUSE_OPENMP=OFF
  "${CMAKE_BIN}" --build "${FLANN_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${FLANN_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libqhull_r.dylib" ]]; then
  rm -rf "${QHULL_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${QHULL_SRC_DIR}" -B "${QHULL_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DQHULL_ENABLE_TESTING=OFF
  "${CMAKE_BIN}" --build "${QHULL_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${QHULL_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/cmake/pcl/PCLConfig.cmake" && ! -f "${NATIVE_PREFIX}/share/pcl-1.12/PCLConfig.cmake" ]]; then
  rm -rf "${PCL_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${PCL_SRC_DIR}" -B "${PCL_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_tools=OFF \
    -DBUILD_apps=OFF \
    -DBUILD_examples=OFF \
    -DBUILD_benchmarks=OFF \
    -DBUILD_global_tests=OFF \
    -DBUILD_simulation=OFF \
    -DBUILD_visualization=OFF \
    -DBUILD_gpu=OFF \
    -DBUILD_recognition=OFF \
    -DBUILD_registration=OFF \
    -DBUILD_surface=OFF \
    -DBUILD_segmentation=OFF \
    -DBUILD_features=OFF \
    -DBUILD_filters=OFF \
    -DBUILD_tracking=OFF \
    -DBUILD_keypoints=OFF \
    -DBUILD_people=OFF \
    -DBUILD_octree=ON \
    -DBUILD_search=ON \
    -DBUILD_kdtree=ON \
    -DBUILD_ml=OFF \
    -DBUILD_stereo=OFF \
    -DBUILD_outofcore=OFF \
    -DBUILD_common=ON \
    -DBUILD_io=ON \
    -DWITH_QT=OFF \
    -DWITH_OPENGL=OFF \
    -DWITH_VTK=OFF \
    -DWITH_OPENNI=OFF \
    -DWITH_OPENNI2=OFF \
    -DWITH_PCAP=OFF \
    -DWITH_LIBUSB=OFF \
    -DWITH_QHULL=OFF \
    -DWITH_PNG=OFF \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBOOST_ROOT="${NATIVE_PREFIX}" \
    -DPCL_ENABLE_SSE=OFF \
    -DPCL_ENABLE_AVX=OFF
  "${CMAKE_BIN}" --build "${PCL_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${PCL_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libBulletDynamics.dylib" ]]; then
  rm -rf "${BULLET_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${BULLET_SRC_DIR}" -B "${BULLET_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_BULLET2_DEMOS=OFF \
    -DBUILD_EXTRAS=OFF \
    -DBUILD_UNIT_TESTS=OFF \
    -DINSTALL_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}"
  "${CMAKE_BIN}" --build "${BULLET_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${BULLET_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libassimp.dylib" ]]; then
  rm -rf "${ASSIMP_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${ASSIMP_SRC_DIR}" -B "${ASSIMP_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DASSIMP_BUILD_TESTS=OFF \
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
    -DASSIMP_BUILD_SAMPLES=OFF \
    -DASSIMP_WARNINGS_AS_ERRORS=OFF \
    -DASSIMP_NO_EXPORT=ON
  "${CMAKE_BIN}" --build "${ASSIMP_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${ASSIMP_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/liboctomap.dylib" || ! -f "${NATIVE_PREFIX}/lib/liboctomath.dylib" ]]; then
  rm -rf "${OCTOMAP_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${OCTOMAP_SRC_DIR}" -B "${OCTOMAP_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_TESTING=OFF \
    -DBUILD_OCTOVIS=OFF \
    -DOCTOMAP_BUILD_STATIC=OFF \
    -DOCTOMAP_BUILD_SHARED=ON
  "${CMAKE_BIN}" --build "${OCTOMAP_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${OCTOMAP_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libccd.dylib" ]]; then
  rm -rf "${LIBCCD_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${LIBCCD_SRC_DIR}" -B "${LIBCCD_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DENABLE_DOUBLE_PRECISION=ON
  "${CMAKE_BIN}" --build "${LIBCCD_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${LIBCCD_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libfcl.dylib" ]]; then
  rm -rf "${FCL_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${FCL_SRC_DIR}" -B "${FCL_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DFCL_USE_X64_SSE=OFF \
    -DFCL_BUILD_TESTS=OFF \
    -DFCL_BUILD_EXAMPLES=OFF \
    -DFCL_WITH_OCTOMAP=ON
  "${CMAKE_BIN}" --build "${FCL_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${FCL_BUILD_DIR}"
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libGraphicsMagick++.a" && ! -f "${NATIVE_PREFIX}/lib/libGraphicsMagick++.dylib" ]]; then
  pushd "${GRAPHICSMAGICK_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  CFLAGS="-O2 -arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
  CXXFLAGS="-O2 -arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
  LDFLAGS="-arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
  ./configure \
    --prefix="${NATIVE_PREFIX}" \
    --disable-dependency-tracking \
    --enable-shared \
    --disable-static \
    --disable-openmp \
    --without-x \
    --without-perl \
    --with-magick-plus-plus
  make -j"${JOBS}"
  make install
  popd >/dev/null
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/libopencv_core.dylib" || ! -f "${NATIVE_PREFIX}/lib/libopencv_calib3d.dylib" ]]; then
  rm -rf "${OPENCV_BUILD_DIR}"
  "${CMAKE_BIN}" -S "${OPENCV_SRC_DIR}" -B "${OPENCV_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_opencv_python2=OFF \
    -DBUILD_opencv_python3=OFF \
    -DBUILD_opencv_gapi=OFF \
    -DBUILD_opencv_apps=OFF \
    -DBUILD_opencv_objc=OFF \
    -DBUILD_LIST=core,imgproc,imgcodecs,highgui,videoio,calib3d \
    -DWITH_IPP=OFF \
    -DWITH_TBB=OFF \
    -DWITH_OPENMP=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_GSTREAMER=OFF \
    -DWITH_V4L=OFF \
    -DWITH_OBSENSOR=OFF \
    -DWITH_QT=OFF \
    -DWITH_OPENEXR=OFF \
    -DWITH_1394=OFF
  "${CMAKE_BIN}" --build "${OPENCV_BUILD_DIR}" --parallel "${JOBS}"
  "${CMAKE_BIN}" --install "${OPENCV_BUILD_DIR}"
fi

if [[ ! -x "${QT_QMAKE}" ]]; then
  rm -rf "${QTBASE_BUILD_DIR}"
  mkdir -p "${QTBASE_BUILD_DIR}" "${QT_PREFIX}"
  pushd "${QTBASE_BUILD_DIR}" >/dev/null
  MACOSX_DEPLOYMENT_TARGET=11.0 \
  CFLAGS="-arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
  CXXFLAGS="-arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
  LDFLAGS="-arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
  "${QTBASE_SRC_DIR}/configure" \
    -platform macx-clang \
    -opengl desktop \
    -prefix "${QT_PREFIX}" \
    -opensource \
    -confirm-license \
    -release \
    -nomake examples \
    -nomake tests \
    -no-openssl \
    -no-dbus \
    -no-glib \
    -qt-zlib \
    -qt-libpng \
    -qt-libjpeg \
    QMAKE_APPLE_DEVICE_ARCHS="${HOST_ARCH}" \
    QMAKE_MACOSX_DEPLOYMENT_TARGET=11.0 \
    QMAKE_MAC_SDK=macosx \
    "QMAKE_INCDIR_OPENGL=${SDKROOT}/System/Library/Frameworks/OpenGL.framework/Headers" \
    "QMAKE_LIBS_OPENGL=-framework OpenGL" \
    "QMAKE_CONFIG+=sdk_no_version_check"
  make -j"${JOBS}"
  make install
  popd >/dev/null
fi

if [[ ! -f "${QT_PREFIX}/lib/cmake/Qt5Svg/Qt5SvgConfig.cmake" ]]; then
  rm -rf "${QTSVG_BUILD_DIR}"
  mkdir -p "${QTSVG_BUILD_DIR}"
  pushd "${QTSVG_BUILD_DIR}" >/dev/null
  "${QT_QMAKE}" "${QTSVG_SRC_DIR}/qtsvg.pro" "PREFIX=${QT_PREFIX}"
  make -j"${JOBS}"
  make install
  popd >/dev/null
fi
