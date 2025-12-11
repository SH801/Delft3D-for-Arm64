#!/bin/bash

# ---------------------------------------------
# Helper script for building Delft3DFM on Mac Arm64
# 07/12/2025: Still incomplete due to platform-specific code
# ---------------------------------------------


# General setup

OS_NAME=$(uname -s)
MEM_REQUIRED_KB=1048576

if [ "$OS_TYPE" = "Darwin" ]; then
    NUM_PROCS=$(sysctl -n hw.ncpu)
    MEM_BYTES=$(sysctl -n hw.memsize)
elif [ "$OS_TYPE" = "Linux" ]; then
    NUM_PROCS=$(nproc)
    MEM_TOTAL_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    MEM_BYTES=$(( MEM_TOTAL_KB * 1024 ))
else
    NUM_PROCS=2
    MEM_BYTES=0
fi

MEM_TOTAL_KB=$(( MEM_BYTES / 1024 ))
MEM_JOBS=$(( MEM_TOTAL_KB / MEM_REQUIRED_KB ))

if [ "$MEM_JOBS" -lt "$NUM_PROCS" ]; then
    MAX_JOBS=$MEM_JOBS
else
    MAX_JOBS=$NUM_PROCS
fi
if [ "$MAX_JOBS" -eq 0 ]; then
    MAX_JOBS=1
fi

if [ "$OS_NAME" = "Darwin" ]; then
    DIMR_PLATFORM_NAME="mac_macports"
elif [ "$OS_NAME" = "Linux" ]; then
    if grep -qE "(debian|ubuntu|pop|mint)" /etc/os-release 2>/dev/null; then
        DIMR_PLATFORM_NAME="linux_apt"
    else
        DIMR_PLATFORM_NAME="linux_generic"
        echo "Warning: Linux distribution is not recognized. Cannot determine package manager."
        exit 1
    fi

else
    DIMR_PLATFORM_NAME="unknown"
    echo "Error: Unsupported OS ($OS_NAME)"
    exit 1
fi

export DIMR_INSTALL_HOME=$(pwd)/delft_src
mkdir -p $DIMR_INSTALL_HOME


# Install gcc15 and other non-DIMR-specific tools including gfortran
# Set up cross-platform variables early

if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    # Remove both flavours of Homebrew from path and local libs
    export PATH=$(echo $PATH | sed 's#\(:/opt/homebrew[^:]*\)*##g')
    export PATH=$(echo $PATH | sed 's#\(:/usr/local[^:]*\)*##g')
    export PATH="/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:$PATH"
    sudo port -N install gcc15 cmake wget nano git patchelf subversion ninja pkgconfig openssl gmake +all
    sudo port select --set gcc mp-gcc15
    export DIMR_PLATFORM_PREFIX=/opt/local
    export CC=${DIMR_PLATFORM_PREFIX}/bin/gcc-mp-15
    export CXX=${DIMR_PLATFORM_PREFIX}/bin/g++-mp-15
    export FC=${DIMR_PLATFORM_PREFIX}/bin/gfortran-mp-15
    export CFLAGS="-O2 -arch arm64"
    export CXXFLAGS="-O2 -arch arm64"
    export FFLAGS="-O2 -arch arm64"
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib/gcc15"
    export LIBS="-lstdc++ -lgfortran"
    export PETSC_MAKE_LOCATION="--with-make-exec=${DIMR_PLATFORM_PREFIX}/bin/gmake"
    export NETCDF_FORTRAN_HOST="aarch64-apple-darwin"
    export ESMF_COMPILER=gfortranclang
    export ESMF_PLATFORM_FOLDER="Darwin.gfortranclang.64.mpiuni.default"
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update && sudo apt-get install -y  gcc g++ gfortran wget nano git cmake build-essential \
                                                    patchelf subversion ninja-build pkg-config libssl-dev libexpat1-dev
    export CC=/usr/bin/gcc
    export CXX=/usr/bin/g++
    export FC=/usr/bin/gfortran
    export DIMR_PLATFORM_PREFIX=/usr
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib/gcc"
    export LIBS="-lstdc++ -lgfortran"
    export PETSC_MAKE_LOCATION="--download-make"
    export NETCDF_FORTRAN_HOST="aarch64-linux-gnu"
    export ESMF_COMPILER=gfortran
    export ESMF_PLATFORM_FOLDER="Linux.gfortran.32.mpiuni.default"
fi
export ESMF_PARENT_FOLDER="${DIMR_PLATFORM_PREFIX}"
export CMAKE_PREFIX_PATH="${DIMR_PLATFORM_PREFIX}:$CMAKE_PREFIX_PATH"


# Install version of cmake that works with petsc

cd $DIMR_INSTALL_HOME
export CMAKE_VERSION="3.31.10"
wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
tar -xzf cmake-${CMAKE_VERSION}.tar.gz
rm cmake-${CMAKE_VERSION}.tar.gz
cd cmake-${CMAKE_VERSION}
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    ./bootstrap --prefix=${DIMR_PLATFORM_PREFIX} \
                CC=/usr/bin/clang \
                CXX=/usr/bin/clang++ \
                CFLAGS="-arch arm64" \
                CXXFLAGS="-arch arm64" \
                LDFLAGS="-arch arm64"
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    ./bootstrap --prefix=${DIMR_PLATFORM_PREFIX}
fi
make -j$MAX_JOBS
sudo make install


# Install mpich

cd $DIMR_INSTALL_HOME
export MPICH_VERSION="4.3.2"
wget https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz
tar -xvf mpich-${MPICH_VERSION}.tar.gz
rm mpich-${MPICH_VERSION}.tar.gz
cd mpich-${MPICH_VERSION}
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    ./configure --prefix=${DIMR_PLATFORM_PREFIX} \
                CC=${CC} \
                CXX=${CXX} \
                FC=${FC} \
                --enable-fortran=all \
                --enable-cxx \
                --enable-shared \
                CFLAGS="-O2 -arch arm64" \
                LDFLAGS=${LDFLAGS} \
                LIBS="-lstdc++ -lgfortran"
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    ./configure --prefix=${DIMR_PLATFORM_PREFIX} \
                --enable-fortran=all \
                --enable-cxx \
                --enable-shared 
fi
make -j$MAX_JOBS
sudo make install


# With mpi installed, set up environment variables

export CC=${DIMR_PLATFORM_PREFIX}/bin/mpicc
export FC=${DIMR_PLATFORM_PREFIX}/bin/mpifort
export CXX=${DIMR_PLATFORM_PREFIX}/bin/mpicxx
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib -L${DIMR_PLATFORM_PREFIX}/lib/gcc15"
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib -L${DIMR_PLATFORM_PREFIX}/lib/aarch64-linux-gnu/13"
fi


# Install petsc

cd $DIMR_INSTALL_HOME
export PETSC_VERSION="3.21.3"
wget https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz
tar -xzf petsc-${PETSC_VERSION}.tar.gz
rm petsc-${PETSC_VERSION}.tar.gz
cd petsc-${PETSC_VERSION}
sudo mkdir ${DIMR_PLATFORM_PREFIX}/petsc
sudo chown $USER ${DIMR_PLATFORM_PREFIX}/petsc
export PETSC_DIR=`pwd` 
./configure \
    --prefix=${DIMR_PLATFORM_PREFIX}/petsc \
    --with-debugging=0 \
    --with-fortran-bindings \
    --with-pic \
    --with-shared-libraries \
    --with-scalar-type=real \
    --with-c-compiler=${CC} \
    --with-cxx-compiler=${CXX} \
    --with-fortran-compiler=${FC} \
    ${PETSC_MAKE_LOCATION} \
    --download-fblaslapack \
    --download-metis \
    --download-parmetis \
    --with-cmake-arguments='-DCMAKE_POLICY_VERSION_MINIMUM=3.5' \
    LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib/gcc15" \
    COPTFLAGS='-O3 -march=native' \
    CXXOPTFLAGS='-O3 -march=native' \
    FOPTFLAGS='-O3 -march=native'
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    make PETSC_DIR=`pwd` PETSC_ARCH=arch-darwin-c-opt all
    make PETSC_DIR=`pwd` PETSC_ARCH=arch-darwin-c-opt install
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt all
    make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt install
fi
export PKG_CONFIG_PATH="${DIMR_PLATFORM_PREFIX}/petsc/lib/pkgconfig:${PKG_CONFIG_PATH}"


# Install gtest 1.14.0 (not latest) for compliance with old Deltares

cd $DIMR_INSTALL_HOME
export GTEST_VERSION="1.14.0"
wget https://github.com/google/googletest/archive/refs/tags/v${GTEST_VERSION}.tar.gz -O gtest-${GTEST_VERSION}.tar.gz
tar -xzf gtest-${GTEST_VERSION}.tar.gz
rm gtest-${GTEST_VERSION}.tar.gz
cd googletest-${GTEST_VERSION}
mkdir build
cd build
cmake .. -DBUILD_GMOCK=OFF -DCMAKE_INSTALL_PREFIX=${DIMR_PLATFORM_PREFIX}
make -j$MAX_JOBS
sudo make install


# Install rest of software

if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    # NOTE: gsed provides gnu-compliant versions of sed and tr as
    # built-in Mac versions of sed/tr don't function same as gnu sed/tr
    sudo port -N install szip zlib metis expat proj6 json-c gdal ossp-uuid tiff gtest gsed +all

    # Install specific boost on Mac that is required for Delft3DFM
    # NOTE: Issue with github releases so use boost.io
    cd $DIMR_INSTALL_HOME
    export BOOST_VERSION="1.85.0"
    export BOOST_VERSION_UNDERSCORED=${BOOST_VERSION//\./_}
    wget https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_UNDERSCORED}.tar.bz2
    tar -xf boost_${BOOST_VERSION_UNDERSCORED}.tar.bz2
    rm boost_${BOOST_VERSION_UNDERSCORED}.tar.bz2
    mv boost_${BOOST_VERSION_UNDERSCORED} boost-${BOOST_VERSION}
    cd boost-${BOOST_VERSION}
    ./bootstrap.sh --prefix=${DIMR_PLATFORM_PREFIX} --with-toolset=gcc
    sudo ./b2 install architecture=arm \
                    address-model=64 \
                    link=shared \
                    runtime-link=shared \
                    boost.stacktrace.from_exception=off \
                    -j$MAX_JOBS

    export PROJ6_PKG_FOLDER=/opt/local/lib/proj6/lib/pkgconfig
    export PKG_CONFIG_PATH="${PROJ6_PKG_FOLDER}:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH}"
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    sudo apt-get update && sudo apt-get install -y metis libgdal-dev libboost-all-dev uuid-dev sqlite3 libtiff-dev 
fi


# Install hdf5 using mpi

cd $DIMR_INSTALL_HOME
export HDF5_VERSION="1.14.6"
wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-${HDF5_VERSION}.tar.gz
tar -zxvf hdf5-${HDF5_VERSION}.tar.gz
rm hdf5-${HDF5_VERSION}.tar.gz
mv hdf5-hdf5-${HDF5_VERSION} hdf5-${HDF5_VERSION}
cd hdf5-${HDF5_VERSION}
mkdir build
cd build
${DIMR_PLATFORM_PREFIX}/bin/cmake \
    -DCMAKE_INSTALL_PREFIX="${DIMR_PLATFORM_PREFIX}" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,${DIMR_PLATFORM_PREFIX}/lib -Wl,-rpath,${DIMR_PLATFORM_PREFIX}/lib/gcc15" \
    -DHDF5_ENABLE_PARALLEL=ON \
    -DBUILD_TESTING=OFF \
    CFLAGS="-fPIC" \
    CXXFLAGS="-fPIC" \
    FFLAGS="-fPIC" \
    CC=mpicc \
    CXX=mpicxx \
    FC=mpifort \
    -DMPI_C_COMPILER="${DIMR_PLATFORM_PREFIX}/bin/mpicc" \
    ..
make -j$MAX_JOBS
sudo make install


# Install netcdf-c

cd $DIMR_INSTALL_HOME
export NETCDF_C_VERSION="4.9.2"
wget https://downloads.unidata.ucar.edu/netcdf-c/${NETCDF_C_VERSION}/netcdf-c-${NETCDF_C_VERSION}.tar.gz
tar -xzf netcdf-c-${NETCDF_C_VERSION}.tar.gz
rm netcdf-c-${NETCDF_C_VERSION}.tar.gz
cd netcdf-c-${NETCDF_C_VERSION}
export CPPFLAGS="-I${DIMR_PLATFORM_PREFIX}/include"
export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib"
export LIBS="-ldl"
export HDF5_DIR="${DIMR_PLATFORM_PREFIX}"
export NETCDF_ROOT="${DIMR_PLATFORM_PREFIX}"
./configure     --prefix=${DIMR_PLATFORM_PREFIX}\
                CC=mpicc
                CXX=mpicxx \
                FC=mpifort \
                F77=mpifort \
                --enable-parallel-hdf5 \
                CPPFLAGS="-I${DIMR_PLATFORM_PREFIX}/include" \
                LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib" \
                --enable-shared \
                CFLAGS="-I${DIMR_PLATFORM_PREFIX}/include -fPIC" \
                LIBS="-L${DIMR_PLATFORM_PREFIX}/lib -lnetcdf" \
                CXXFLAGS="-fPIC"
make -j$MAX_JOBS
sudo make install
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    sudo install_name_tool -change "@rpath/libhdf5_hl.310.dylib" "${DIMR_PLATFORM_PREFIX}/lib/libhdf5_hl.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libnetcdf.19.dylib
    sudo install_name_tool -change "@rpath/libhdf5.310.dylib" "${DIMR_PLATFORM_PREFIX}/lib/libhdf5.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libnetcdf.19.dylib
fi


# Install netcdf-fortran

cd $DIMR_INSTALL_HOME
export NETCDF_FORTRAN_VERSION="4.6.2"
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz -O netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
tar -xvf netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
rm netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
cd netcdf-fortran-${NETCDF_FORTRAN_VERSION}
./configure     --prefix=${DIMR_PLATFORM_PREFIX} \
                CC=mpicc \
                CXX=mpicxx \
                FC=mpifort \
                F77=mpifort \
                CFLAGS="-fPIC" \
                CXXFLAGS="-fPIC" \
                CPPFLAGS="-I${DIMR_PLATFORM_PREFIX}/include" \
                LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib" \
                LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lm -lz -lsz -lzstd -lblosc -lxml2 -lcurl -ldl" \
                --disable-fortran-type-check \
                --enable-shared \
                --host=${NETCDF_FORTRAN_HOST}
make -j$MAX_JOBS
sudo make install
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    sudo install_name_tool -change "@rpath/libhdf5_hl.310.dylib" "${DIMR_PLATFORM_PREFIX}/lib/libhdf5_hl.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libnetcdff.dylib
    sudo install_name_tool -change "@rpath/libhdf5.310.dylib" "${DIMR_PLATFORM_PREFIX}/lib/libhdf5.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libnetcdff.dylib
fi


# Install esmf

cd $DIMR_INSTALL_HOME
export ESMF_VERSION="8.9.0"
wget https://github.com/esmf-org/esmf/archive/refs/tags/v${ESMF_VERSION}.tar.gz -O esmf-${ESMF_VERSION}.tar.gz
tar -xzf esmf-${ESMF_VERSION}.tar.gz
rm esmf-${ESMF_VERSION}.tar.gz
cd $DIMR_INSTALL_HOME/esmf-${ESMF_VERSION}
sudo mkdir ${DIMR_PLATFORM_PREFIX}/esmf-${ESMF_VERSION}
sudo chown $USER ${DIMR_PLATFORM_PREFIX}/esmf-${ESMF_VERSION}
export ESMF_DIR=$(pwd)
export ESMF_COMM=mpiuni
export ESMF_F90COMPILER=${DIMR_PLATFORM_PREFIX}/bin/mpifort
export ESMF_C_FLAGS="-O3 -march=native -arch arm64"
export ESMF_F90_FLAGS="-O3 -march=native -arch arm64"
export ESMF_INSTALL_PREFIX="${ESMF_PARENT_FOLDER}/esmf-${ESMF_VERSION}"
export ESMF_ROOT=${ESMF_INSTALL_PREFIX}

if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then

    # Hacky-workaround so ESMF compiler generates non-clang output as doesn't detect gnu compilers

    TARGET_FILE="build_config/Darwin.gfortranclang.default/build_rules.mk"
    REPLACEMENT_TEXT='ESMF_F90DEFAULT         = gfortran
    ESMF_F90LINKERDEFAULT   = $(ESMF_CXXLINKER)
    ESMF_F90LINKOPTS       += -L/opt/local/lib/gcc15 -Wl,-rpath,/opt/local/lib/gcc15 -lstdc++
    ESMF_CXXDEFAULT         = /opt/local/bin/g++-mp-15
    ESMF_CDEFAULT           = /opt/local/bin/gcc-mp-15
    ESMF_CLINKERDEFAULT     = /opt/local/bin/g++-mp-15
    ESMF_CPPDEFAULT         = /opt/local/bin/gcc-mp-15 -E -P -x c

    ESMF_CXXCOMPILEOPTS    += -x c++ -mmacosx-version-min=10.7'

    ESCAPED_REPLACEMENT=$(echo "$REPLACEMENT_TEXT" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' -e 's/|/\\|/g')

    sed -i '' "/ESMF_F90DEFAULT/ {
    N;N;N;N;N;N;N;N;
    s|ESMF_F90DEFAULT\s*= gfortran\nESMF_F90LINKERDEFAULT\s*= \$(ESMF_CXXLINKER)\nESMF_CXXDEFAULT\s*= clang\+\+\nESMF_CDEFAULT\s*= clang\nESMF_CLINKERDEFAULT\s*= clang\+\+\nESMF_CPPDEFAULT\s*= clang -E -P -x c\n\nESMF_CXXCOMPILEOPTS\s*+= -x c\+\+ -mmacosx-version-min=10.7 -stdlib=libc\+\+|${ESCAPED_REPLACEMENT}|
    }" "$TARGET_FILE"

fi

if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    make all    -j$MAX_JOBS \
                ESMF_F90=mpifort \
                ESMF_F77=mpifort \
                ESMF_C=${DIMR_PLATFORM_PREFIX}/bin/gcc \
                ESMF_CXX=${DIMR_PLATFORM_PREFIX}/bin/g++
fi
if [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    make all -j$MAX_JOBS
fi
sudo make install ESMF_DIR=${ESMF_DIR} ESMF_INSTALL_PREFIX="${ESMF_INSTALL_PREFIX}"
export PATH=${ESMF_INSTALL_PREFIX}/bin/binO/${ESMF_PLATFORM_FOLDER}/:${PATH}


# Download Delft3DFM

cd $DIMR_INSTALL_HOME
export DIMR_VERSION="2026.01"
wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_${DIMR_VERSION}.tar.gz
tar -xzf DIMRset_${DIMR_VERSION}.tar.gz
rm DIMRset_${DIMR_VERSION}.tar.gz
mv Delft3D-DIMRset_${DIMR_VERSION} Delft3D


# Install patches to enable Arm64 and / or gfortran compilation 

cd Delft3D
patch -p1 -f -i ../../001-${DIMR_VERSION}.patch
git init
git add .
git commit -m "Initial commit"


# Build Delft3DFM

cmake ./src/cmake \
    -G "Unix Makefiles" \
    -B build \
    -D CONFIGURATION_TYPE=all \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=install \
    -D CMAKE_Fortran_FLAGS="-fPIC" \
    -D CMAKE_VERBOSE_MAKEFILE=OFF
cmake --build build -j$MAX_JOBS --target install --config Release
export PATH=${DIMR_INSTALL_HOME}/Delft3D/install/bin:$PATH