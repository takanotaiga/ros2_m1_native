#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
THIRD_PARTY_SRC_DIR="${ROOT_DIR}/.deps/third_party"
CMAKE_BIN="${ROOT_DIR}/.local/tools/cmake/bin/cmake"
NATIVE_PREFIX="${ROOT_DIR}/.local/deps"

uv run python "${ROOT_DIR}/scripts/sync_git_repos.py" \
  --manifest "${ROOT_DIR}/third_party.repos" \
  --root "${THIRD_PARTY_SRC_DIR}"

mkdir -p "${NATIVE_PREFIX}"

TINYXML2_SRC_DIR="${THIRD_PARTY_SRC_DIR}/leethomason/tinyxml2"
TINYXML2_BUILD_DIR="${ROOT_DIR}/.build/tinyxml2"
EIGEN_SRC_DIR="${THIRD_PARTY_SRC_DIR}/libeigen/eigen"
EIGEN_BUILD_DIR="${ROOT_DIR}/.build/eigen"
ASIO_SRC_DIR="${THIRD_PARTY_SRC_DIR}/chriskohlhoff/asio"
BULLET_SRC_DIR="${THIRD_PARTY_SRC_DIR}/bulletphysics/bullet3"
BULLET_BUILD_DIR="${ROOT_DIR}/.build/bullet3"

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
