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
ASIO_SRC_DIR="${THIRD_PARTY_SRC_DIR}/chriskohlhoff/asio"
BOOST_SRC_DIR="${THIRD_PARTY_SRC_DIR}/boostorg/boost"
RAPIDJSON_SRC_DIR="${THIRD_PARTY_SRC_DIR}/tencent/rapidjson"
NLOHMANN_JSON_SRC_DIR="${THIRD_PARTY_SRC_DIR}/nlohmann/json"
NLOHMANN_JSON_BUILD_DIR="${ROOT_DIR}/.build/nlohmann_json"
LZ4_SRC_DIR="${THIRD_PARTY_SRC_DIR}/lz4/lz4"
FLANN_SRC_DIR="${THIRD_PARTY_SRC_DIR}/flann-lib/flann"
FLANN_BUILD_DIR="${ROOT_DIR}/.build/flann"
PCL_SRC_DIR="${THIRD_PARTY_SRC_DIR}/pointcloudlibrary/pcl"
PCL_BUILD_DIR="${ROOT_DIR}/.build/pcl"
BULLET_SRC_DIR="${THIRD_PARTY_SRC_DIR}/bulletphysics/bullet3"
BULLET_BUILD_DIR="${ROOT_DIR}/.build/bullet3"
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

if [[ ! -f "${NATIVE_PREFIX}/lib/libboost_system.dylib" ]]; then
  pushd "${BOOST_SRC_DIR}" >/dev/null
  git submodule update --init --recursive --jobs "${JOBS}"
  ./bootstrap.sh --prefix="${NATIVE_PREFIX}"
  ./b2 -j"${JOBS}" \
    toolset=clang \
    variant=release \
    link=shared \
    runtime-link=shared \
    threading=multi \
    --layout=system \
    cxxflags="-std=c++17 -arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
    linkflags="-arch ${HOST_ARCH} -isysroot ${SDKROOT}" \
    install \
    --with-atomic \
    --with-chrono \
    --with-date_time \
    --with-filesystem \
    --with-iostreams \
    --with-regex \
    --with-serialization \
    --with-system \
    --with-thread
  popd >/dev/null
fi

if [[ ! -f "${NATIVE_PREFIX}/lib/liblz4.dylib" ]]; then
  pushd "${LZ4_SRC_DIR}" >/dev/null
  make -C lib -j"${JOBS}" PREFIX="${NATIVE_PREFIX}"
  make -C lib PREFIX="${NATIVE_PREFIX}" install
  popd >/dev/null
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

if [[ ! -f "${NATIVE_PREFIX}/lib/cmake/pcl/PCLConfig.cmake" ]]; then
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

if [[ ! -f "${NATIVE_PREFIX}/lib/libopencv_core.dylib" ]]; then
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
    -DBUILD_LIST=core,imgproc,imgcodecs,highgui,videoio \
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
