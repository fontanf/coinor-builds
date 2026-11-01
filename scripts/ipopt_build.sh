#!/usr/bin/env bash

##################################################################
# Build COIN-OR Ipopt (with MUMPS) from sources as static libs   #
# for the native architecture of the current Linux/macOS machine #
##################################################################

# Requirements: a C/C++ compiler, gfortran, make, wget, and BLAS/LAPACK
# (system libblas/liblapack on Linux, the Accelerate framework on macOS).
#
# The resulting archive contains:
# - include/coin-or/          Ipopt headers
# - lib/libipopt.a
# - lib/libcoinmumps.a
# - lib/libgfortran.a, lib/libquadmath.a (when available), so that
#   consumers do not need a Fortran compiler/runtime installed
#
# BLAS/LAPACK are NOT bundled: consumers link them from the system.

set -euo pipefail

ipopt_version=3.14.20
mumps_version=3.0.14

build_dir=build
output_dir=lib

os=$(uname -s)
arch=$(uname -m)
if [ "${os}" = "Darwin" ]; then
  platform=macos-${arch}
  lapack_lflags="-framework Accelerate"
  jobs=$(sysctl -n hw.ncpu)
else
  platform=linux-${arch}
  lapack_lflags="-llapack -lblas"
  jobs=$(nproc)
fi

fc=${FC:-gfortran}

root_dir=$(pwd)
prefix=${root_dir}/${build_dir}/dist

rm -rf ${build_dir}
mkdir -p ${build_dir}

# MUMPS

(
  cd ${build_dir}
  wget -q https://github.com/coin-or-tools/ThirdParty-Mumps/archive/refs/tags/releases/${mumps_version}.tar.gz -O mumps.tar.gz
  tar -xzf mumps.tar.gz
  cd ThirdParty-Mumps-releases-${mumps_version}
  ./get.Mumps
  ./configure \
    --prefix=${prefix} \
    --disable-shared \
    --enable-static \
    --with-pic \
    --without-metis \
    --with-lapack-lflags="${lapack_lflags}" \
    FC=${fc}
  make -j${jobs}
  make install
)

# Ipopt

(
  cd ${build_dir}
  wget -q https://github.com/coin-or/Ipopt/archive/refs/tags/releases/${ipopt_version}.tar.gz -O ipopt.tar.gz
  tar -xzf ipopt.tar.gz
  cd Ipopt-releases-${ipopt_version}
  PKG_CONFIG_PATH=${prefix}/lib/pkgconfig ./configure \
    --prefix=${prefix} \
    --disable-shared \
    --enable-static \
    --with-pic \
    --disable-java \
    --disable-sipopt \
    --without-hsl \
    --without-asl \
    --without-spral \
    --with-lapack-lflags="${lapack_lflags}"
  make -j${jobs}
  make install
)

# Bundle the Fortran runtime.

for lib in gfortran quadmath; do
  lib_path=$(${fc} -print-file-name=lib${lib}.a)
  if [ -f "${lib_path}" ]; then
    cp "${lib_path}" ${prefix}/lib/
  fi
done

# Create the archive.

mkdir -p ${output_dir}
# The pkg-config files contain absolute paths of the build machine.
rm -rf ${prefix}/share ${prefix}/lib/*.la ${prefix}/lib/pkgconfig
tar -czf ${output_dir}/Ipopt-${ipopt_version}-${platform}-static.tar.gz -C ${prefix} include lib
