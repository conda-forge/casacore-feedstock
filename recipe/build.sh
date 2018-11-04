#! /bin/bash

set -ex

cmake_args=(
    -DBUILD_TESTING=OFF
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_COLOR_MAKEFILE=OFF
    -DCMAKE_INSTALL_PREFIX=$PREFIX
    -DDATA_DIR=$PREFIX/lib/casa/data
    -DUSE_FFTW3=ON
    -DUSE_HDF5=ON
    -DUSE_THREADS=ON
    -DCXX11=ON
    -DCONDA_CASA_ROOT=$PREFIX/lib/casa
)

if [ $PY3K -ne 0 ] ; then
    cmake_args+=(
        -DBUILD_PYTHON3=ON
        -DBUILD_PYTHON=OFF
        -DPYTHON3_EXECUTABLE=$PYTHON
    )
else
    cmake_args+=(
        -DBUILD_PYTHON=ON
        -DBUILD_PYTHON3=OFF
        -DPYTHON2_EXECUTABLE=$PYTHON
    )
fi

if [ $(uname) = Darwin ] ; then
    cmake_args+=(
	-DCMAKE_CXX_FLAGS="$CXXFLAGS -stdlib=libc++"
	-DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET
	-DCMAKE_OSX_SYSROOT=/
	-DREADLINE_INCLUDE_DIR=$PREFIX/include
	-DREADLINE_LIBRARY=$PREFIX/lib/libreadline.dylib
    )
else
    cmake_args+=(
	-DBLAS_LIBRARIES="$PREFIX/lib/libopenblas.so"
	-DCMAKE_CXX_FLAGS="$CXXFLAGS -Wl,-rpath-link,$PREFIX/lib"
    )

    # Ermahgerd, CMake and the new C++ compilers do *not* play well together.
    # Although that may be mostly due to funky rules in this particular
    # package. Anyway, commence hacks to get this compiling. The basic problem
    # is that CMake wants to find paths to libraries itself. Annoyingly it is
    # *very* hard to debug what exactly it is doing as it does so.

    if [ "$cxx_compiler" = "gxx" ] ; then
        sysroot="$BUILD_PREFIX/$HOST/sysroot"

        cmake_args+=(
            -DCMAKE_LIBRARY_PATH="$PREFIX/lib;$sysroot/lib"
            -DPTHREADS_INCLUDE_DIR="$sysroot/usr/include"
        )

        pushd $sysroot/lib
        for lib in dl m pthread rt ; do
            ln -s lib${lib}.so.? lib${lib}.so
        done
        popd
    fi
fi

### cmake_args+=(--debug-trycompile --debug-output --trace-expand)

# Work around bug in conda-forge package of bison (3.0.5 hfc679d8_1)
export M4=$BUILD_PREFIX/bin/m4

mkdir build
cd build
cmake "${cmake_args[@]}" ..
make -j$CPU_COUNT VERBOSE=1
make install

cd $PREFIX
rm -f \
   casa_sover.txt \
   bin/casacore_assay \
   bin/casacore_floatcheck \
   bin/casacore_memcheck \
   bin/countcode \
   bin/measuresdata.csh \
   share/casacore/*.supp
