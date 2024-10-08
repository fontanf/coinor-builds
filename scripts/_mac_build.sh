#!/usr/bin/env bash

##################################################################
# Build COIN-OR Project from sources for different architectures #
##################################################################

function build_coinor_project {

  # Example variables to define before calling this function
  # --------------------------------------------------------
  # project_name=Cbc
  # project_versions=(2.10.11 2.10.12)
  # archs=(arm64 x86_64)
  # libs=(Cbc Cgl Clp ClpSolver CoinUtils Osi OsiCbc OsiClp OsiCommonTests)

  build_dir=build
  output_dir=lib

  for project_version in ${project_versions[*]}
  do

    # Cleanup build dir
    rm -rf ${build_dir}

    # Create an empty build dir
    mkdir -p ${build_dir}

    # Get coinbrew
    wget https://raw.githubusercontent.com/coin-or/coinbrew/master/coinbrew -P ${build_dir} -O ${build_dir}/coinbrew
    chmod u+x ${build_dir}/coinbrew

    # Fetch project
    (cd ${build_dir} && ./coinbrew fetch ${project_name}@${project_version} --no-third-party)

    # Build project for each architecture
    for arch in ${archs[*]}
    do
      (cd ${build_dir} && env /usr/bin/arch -${arch} ./coinbrew build ${project_name} --no-prompt --reconfigure --build-dir=build/${arch} --prefix=dist/${arch} --disable-shared --disable-zlib --disable-bzlib --disable-readline --without-cholmod --without-amd --without-sample --without-lapack --no-third-party LT_LDFLAGS=-all-static --tests=none)
    done

    # Create universal lib dir
    mkdir -p ${build_dir}/dist/universal/lib

    # Copy includes
    cp -r ${build_dir}/dist/${archs[0]}/include ${build_dir}/dist/universal/

    # Combine each lib in single fat binary lib
    for lib in ${libs[*]}
    do
      files=""; for arch in ${archs[*]}; do files="${files} ${build_dir}/dist/${arch}/lib/lib${lib}.a"; done
      lipo ${files} -create -output ${build_dir}/dist/universal/lib/lib${lib}.a
    done

    # Create an archive with project universal static libs
    mkdir -p ${output_dir}
    tar -czf ${output_dir}/${project_name}-release.${project_version}-universal-macos.tar.gz -C ${build_dir}/dist/universal .

  done

}
