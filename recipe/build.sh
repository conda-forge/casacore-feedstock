#! /bin/bash

set -ex

if [ "$mpi" = nompi ] ; then
    use_adios2=OFF
else
    use_adios2=ON
fi

if [ "$mpi" = openmpi ] ; then
    # "for cross compiling with openmpi" -- libnetcdf build.sh:
    export OPAL_PREFIX="$PREFIX"
fi

cmake_args=(
    ${CMAKE_ARGS}
    -DBUILD_FFTPACK_DEPRECATED=ON
    -DBUILD_TESTING=OFF
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_COLOR_MAKEFILE=OFF
    -DCMAKE_INSTALL_PREFIX=$PREFIX
    -DDATA_DIR=$PREFIX/lib/casa/data
    -DUSE_FFTW3=ON
    -DUSE_ADIOS2=$use_adios2
    -DUSE_HDF5=ON
    -DUSE_THREADS=ON
    -DCXX11=ON
    -DCONDA_CASA_ROOT=$PREFIX/lib/casa
    -DPORTABLE=ON
)

if [ $PY3K -ne 0 ] ; then
    cmake_args+=(
        -DBUILD_PYTHON3=ON
        -DBUILD_PYTHON=OFF
        -DPython3_EXECUTABLE="$PYTHON"
    )
else
    cmake_args+=(
        -DBUILD_PYTHON=ON
        -DBUILD_PYTHON3=OFF
        -DPython2_EXECUTABLE="$PYTHON"
    )
fi

if [ $(uname) = Darwin ] ; then
    cmake_args+=(
	-DREADLINE_INCLUDE_DIR=$PREFIX/include
	-DREADLINE_LIBRARY=$PREFIX/lib/libreadline.dylib
    )
else
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
fi

cmake_args+=(
  -DBLAS_LIBRARIES="$PREFIX/lib/libblas${SHLIB_EXT}"
  -DLAPACK_LIBRARIES="$PREFIX/lib/liblapack${SHLIB_EXT}"
)

# Work around issue with multiple definitions of Yacc error function, introduced
# by behavior change in Bison 3.8 (cf.
# https://www.gnu.org/software/bison/manual/html_node/Tuning-the-Parser.html)
for c in \
    IMAGEEXPR \
    JSON \
    MSANTENNA \
    MSARRAY \
    MSCORR \
    MSFEED \
    MSFIELD \
    MSOBSERVATION \
    MSPOLN \
    MSSCAN \
    MSSPW \
    MSSTATE \
    MSTIME \
    MSUVDIST \
    RECORD \
    TABLE \
; do
    export CPPFLAGS="$CPPFLAGS -D${c}GRAMERROR_IS_DECLARED -D${c}GRAMLEX_IS_DECLARED"
done

# Also, CMake doesn't honor CPPFLAGS
export CXXFLAGS="$CXXFLAGS $CPPFLAGS"

### cmake_args+=(--debug-trycompile --debug-output --trace-expand)

mkdir build
cd build
cmake ${CMAKE_ARGS} "${cmake_args[@]}" ..
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
