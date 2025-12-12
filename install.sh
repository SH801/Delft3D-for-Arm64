#!/bin/bash

# ------------------------------------------------------------------
# Install script for building Delft3DFM on Arm64 Mac or Ubuntu 24.04
# ------------------------------------------------------------------


# General setup

export DIMR_INSTALL_CLEAN=1
export DIMR_INSTALL_CMAKE=1
export DIMR_INSTALL_MPICH=1
export DIMR_INSTALL_PETSC=1
export DIMR_INSTALL_GTEST=1
export DIMR_INSTALL_BOOST=1
export DIMR_INSTALL_HDF5=1
export DIMR_INSTALL_NETCDFC=1
export DIMR_INSTALL_NETCDFFORTAN=1
export DIMR_INSTALL_ESMF=1
export DIMR_INSTALL_DIMR_DOWNLOAD=1

set -e
read -s -p "Enter password for sudo: " sudoPW

OS_NAME=$(uname -s)
MEM_REQUIRED_KB=1048576

if [ "$OS_NAME" = "Darwin" ]; then
    NUM_PROCS=$(sysctl -n hw.ncpu)
    MEM_BYTES=$(sysctl -n hw.memsize)
elif [ "$OS_NAME" = "Linux" ]; then
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

echo "Total memory: ${MEM_TOTAL_KB}"
echo "Running make in parallel with ${MAX_JOBS} cpus"

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


# Clean up previously installed src folder

if [ "$DIMR_INSTALL_CLEAN" = "1" ]; then
    if [ -d "${DIMR_INSTALL_HOME}" ]; then
        echo $sudoPW | sudo -S rm -r ${DIMR_INSTALL_HOME}
    fi
fi

mkdir -p $DIMR_INSTALL_HOME


# Install gcc15 and other non-DIMR-specific tools including gfortran
# Set up cross-platform variables early

if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    # Remove both flavours of Homebrew from path and local libs
    export PATH=$(echo $PATH | sed 's#\(:/opt/homebrew[^:]*\)*##g')
    export PATH=$(echo $PATH | sed 's#\(:/usr/local[^:]*\)*##g')
    export PATH="/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:$PATH"
    # NOTE: gsed provides gnu-compliant versions of sed and tr as
    # built-in Mac versions of sed/tr don't function same as gnu sed/tr
    echo $sudoPW | sudo -S port -N install gcc15 cmake wget nano git patchelf subversion ninja pkgconfig openssl gmake gsed xercesc3 +all
    echo $sudoPW | sudo -S port -N select --set gcc mp-gcc15
    export DIMR_PLATFORM_PREFIX="/opt/local"
    export CFLAGS="-O2 -arch arm64"
    export CXXFLAGS="-O2 -arch arm64"
    export FFLAGS="-O2 -arch arm64"
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib/gcc15"
    export LIBS="-lstdc++ -lgfortran"
    export PETSC_MAKE_LOCATION="--with-make-exec=${DIMR_PLATFORM_PREFIX}/bin/gmake"
    export NETCDF_FORTRAN_HOST="aarch64-apple-darwin"
    export PETSC_ARCH="arch-darwin-c-opt"
    export ESMF_COMPILER=gfortranclang
    export ESMF_PLATFORM_FOLDER="Darwin.gfortranclang.64.mpiuni.default"
elif [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    export DEBIAN_FRONTEND=noninteractive
    echo $sudoPW | sudo -S apt-get update
    echo $sudoPW | sudo -S apt-get install -y   gcc g++ gfortran wget nano git cmake build-essential \
                                                patchelf subversion ninja-build pkg-config libssl-dev libexpat1-dev
    export DIMR_PLATFORM_PREFIX="/usr"
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib/gcc"
    export LIBS="-lstdc++ -lgfortran"
    export PETSC_MAKE_LOCATION="--download-make"
    export NETCDF_FORTRAN_HOST="aarch64-linux-gnu"
    export PETSC_ARCH="arch-linux-c-opt"
    export ESMF_COMPILER="gfortran"
    export ESMF_PLATFORM_FOLDER="Linux.gfortran.32.mpiuni.default"

fi

DEFAULT_GIT_NAME="Anonymous User"
DEFAULT_GIT_EMAIL="anonymous@example.com"
if [ -z "$(git config --global user.name)" ]; then git config --global user.name "$DEFAULT_GIT_NAME"; fi
if [ -z "$(git config --global user.email)" ]; then git config --global user.email "$DEFAULT_GIT_EMAIL"; fi


export CC="${DIMR_PLATFORM_PREFIX}/bin/gcc"
export CXX="${DIMR_PLATFORM_PREFIX}/bin/g++"
export FC="${DIMR_PLATFORM_PREFIX}/bin/gfortran"
export ESMF_PARENT_FOLDER="${DIMR_PLATFORM_PREFIX}"


# Install version of cmake that works with petsc and Deltares

export CMAKE_VERSION="3.31.10"
if [ "$DIMR_INSTALL_CMAKE" = "1" ]; then
    cd $DIMR_INSTALL_HOME
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
    tar -xzf cmake-${CMAKE_VERSION}.tar.gz
    rm cmake-${CMAKE_VERSION}.tar.gz
    cd cmake-${CMAKE_VERSION}
    if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
        export CMAKE_PREFIX_PATH="/opt/local"
        ./bootstrap --prefix=${DIMR_PLATFORM_PREFIX} \
                    CC=/usr/bin/clang \
                    CXX=/usr/bin/clang++ \
                    CFLAGS="-arch arm64" \
                    CXXFLAGS="-arch arm64" \
                    LDFLAGS="-arch arm64" 
        unset CMAKE_PREFIX_PATH
    elif [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
        ./bootstrap --prefix=${DIMR_PLATFORM_PREFIX}
    fi
    make -j$MAX_JOBS
    echo $sudoPW | sudo -S make install
fi


# Install mpich

export MPICH_VERSION="4.3.2"
if [ "$DIMR_INSTALL_MPICH" = "1" ]; then
    cd $DIMR_INSTALL_HOME
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
    elif [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
        ./configure --prefix=${DIMR_PLATFORM_PREFIX} \
                    --enable-fortran=all \
                    --enable-cxx \
                    --enable-shared 
    fi
    make -j$MAX_JOBS
    echo $sudoPW | sudo -S make install
fi


# With mpi installed, set up environment variables

export CC="${DIMR_PLATFORM_PREFIX}/bin/mpicc"
export FC="${DIMR_PLATFORM_PREFIX}/bin/mpifort"
export CXX="${DIMR_PLATFORM_PREFIX}/bin/mpicxx"
if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib -L${DIMR_PLATFORM_PREFIX}/lib/gcc15"
elif [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib -L${DIMR_PLATFORM_PREFIX}/lib/aarch64-linux-gnu/13"
fi


# Install petsc

export PETSC_VERSION="3.21.3"
export PETSC_DIR="${DIMR_INSTALL_HOME}/petsc-${PETSC_VERSION}"
if [ "$DIMR_INSTALL_PETSC" = "1" ]; then
    cd $DIMR_INSTALL_HOME
    wget https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz
    tar -xzf petsc-${PETSC_VERSION}.tar.gz
    rm petsc-${PETSC_VERSION}.tar.gz
    cd petsc-${PETSC_VERSION}
    if [ -d "${DIMR_PLATFORM_PREFIX}/petsc" ]; then
        echo "Found previous petsc folder, deleting..."
        echo $sudoPW | sudo -S rm -r ${DIMR_PLATFORM_PREFIX}/petsc
    fi
    echo $sudoPW | sudo -S mkdir ${DIMR_PLATFORM_PREFIX}/petsc
    echo $sudoPW | sudo -S chown $USER ${DIMR_PLATFORM_PREFIX}/petsc
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
        --with-cmake-arguments="-DCMAKE_POLICY_VERSION_MINIMUM=3.5" \
        LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib/gcc15" \
        COPTFLAGS='-O3 -march=native' \
        CXXOPTFLAGS='-O3 -march=native' \
        FOPTFLAGS='-O3 -march=native'
    make PETSC_DIR=`pwd` PETSC_ARCH=${PETSC_ARCH} all
    make PETSC_DIR=`pwd` PETSC_ARCH=${PETSC_ARCH} install
fi
export PKG_CONFIG_PATH="${DIMR_PLATFORM_PREFIX}/petsc/lib/pkgconfig:${PKG_CONFIG_PATH}"


# # Install gtest 1.14.0 (not latest) for compliance with old Deltares

export GTEST_VERSION="1.14.0"
if [ "$DIMR_INSTALL_GTEST" = "1" ]; then
    cd $DIMR_INSTALL_HOME
    wget https://github.com/google/googletest/archive/refs/tags/v${GTEST_VERSION}.tar.gz -O gtest-${GTEST_VERSION}.tar.gz
    tar -xzf gtest-${GTEST_VERSION}.tar.gz
    rm gtest-${GTEST_VERSION}.tar.gz
    cd googletest-${GTEST_VERSION}
    mkdir build
    cd build
    cmake .. -DBUILD_GMOCK=OFF -DCMAKE_INSTALL_PREFIX=${DIMR_PLATFORM_PREFIX}
    make -j$MAX_JOBS
    echo $sudoPW | sudo -S make install
fi


# Install rest of software

if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
    echo $sudoPW | sudo -S port -N install szip zlib metis expat proj6 json-c gdal ossp-uuid tiff +all

    # Install specific boost on Mac that is required for Delft3DFM
    # NOTE: Issue with github releases so use boost.io
    cd $DIMR_INSTALL_HOME
    export BOOST_VERSION="1.85.0"

    if [ "$DIMR_INSTALL_BOOST" = "1" ]; then
        export BOOST_VERSION_UNDERSCORED=${BOOST_VERSION//\./_}
        wget https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_UNDERSCORED}.tar.bz2
        tar -xf boost_${BOOST_VERSION_UNDERSCORED}.tar.bz2
        rm boost_${BOOST_VERSION_UNDERSCORED}.tar.bz2
        mv boost_${BOOST_VERSION_UNDERSCORED} boost-${BOOST_VERSION}
        cd boost-${BOOST_VERSION}
        ./bootstrap.sh --prefix=${DIMR_PLATFORM_PREFIX} --exec-prefix=${DIMR_PLATFORM_PREFIX} --with-toolset=gcc
        ${DIMR_INSTALL_HOME}/boost-${BOOST_VERSION}/b2 architecture=arm address-model=64 link=shared runtime-link=shared boost.stacktrace.from_exception=off 

        set +e
        files_to_remove_1=(${DIMR_PLATFORM_PREFIX}/lib/libboost_*.*)
        files_to_remove_2=(${DIMR_PLATFORM_PREFIX}/lib/cmake/boost*)
        files_to_remove_3=(${DIMR_PLATFORM_PREFIX}/lib/cmake/Boost*)
        if [ ${#files_to_remove_1[@]} -gt 0 ]; then echo $sudoPW | sudo -S rm ${DIMR_PLATFORM_PREFIX}/lib/libboost_*.*; fi
        if [ ${#files_to_remove_2[@]} -gt 0 ]; then echo $sudoPW | sudo -S rm -r ${DIMR_PLATFORM_PREFIX}/lib/cmake/boost*; fi
        if [ ${#files_to_remove_3[@]} -gt 0 ]; then echo $sudoPW | sudo -S rm -r ${DIMR_PLATFORM_PREFIX}/lib/cmake/Boost*; fi
        if [ -d "${DIMR_PLATFORM_PREFIX}/include/boost" ]; then echo $sudoPW | sudo -S rm -r ${DIMR_PLATFORM_PREFIX}/include/boost; fi
        set -e

        echo $sudoPW | sudo -S cp -R ${DIMR_INSTALL_HOME}/boost-${BOOST_VERSION}/boost ${DIMR_PLATFORM_PREFIX}/include/boost
        echo $sudoPW | sudo -S cp -R ${DIMR_INSTALL_HOME}/boost-${BOOST_VERSION}/stage/lib/* ${DIMR_PLATFORM_PREFIX}/lib/.
        echo $sudoPW | sudo -S cp -R ${DIMR_INSTALL_HOME}/boost-${BOOST_VERSION}/stage/lib/cmake/* ${DIMR_PLATFORM_PREFIX}/lib/cmake/.
    fi

    export PROJ6_PKG_FOLDER="${DIMR_PLATFORM_PREFIX}/lib/proj6/lib/pkgconfig"
    export PKG_CONFIG_PATH="${PROJ6_PKG_FOLDER}:${DIMR_PLATFORM_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"

elif [ "$DIMR_PLATFORM_NAME" = "linux_apt" ]; then
    echo $sudoPW | sudo -S apt-get update
    echo $sudoPW | sudo -S apt-get install -y metis libgdal-dev libboost-all-dev uuid-dev sqlite3 libtiff-dev 
fi

# # Install hdf5 using mpi

export HDF5_VERSION="1.14.6"
if [ "$DIMR_INSTALL_HDF5" = "1" ]; then
    cd $DIMR_INSTALL_HOME
    wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-${HDF5_VERSION}.tar.gz
    tar -zxvf hdf5-${HDF5_VERSION}.tar.gz
    rm hdf5-${HDF5_VERSION}.tar.gz
    mv hdf5-hdf5-${HDF5_VERSION} hdf5-${HDF5_VERSION}
    cd hdf5-${HDF5_VERSION}
    mkdir build
    cd build
    export CMAKE_PREFIX_PATH="/opt/local"
    export CMAKE_IGNORE_PATH="/opt/homebrew;/usr/local"
    export CMAKE_LIBRARY_PATH="/opt/local/lib:/opt/local/lib/libaec/lib"
    ${DIMR_PLATFORM_PREFIX}/bin/cmake \
        -DCMAKE_INSTALL_PREFIX="${DIMR_PLATFORM_PREFIX}" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,${DIMR_PLATFORM_PREFIX}/lib -Wl,-rpath,${DIMR_PLATFORM_PREFIX}/lib/gcc15" \
        -DHDF5_ENABLE_PARALLEL=ON \
        -DBUILD_TESTING=OFF \
        -DCMAKE_PREFIX_PATH=${DIMR_PLATFORM_PREFIX} \
        -DCMAKE_IGNORE_PATH="/opt/homebrew;/usr/local" \
        -DCMAKE_LIBRARY_PATH=${DIMR_PLATFORM_PREFIX}/lib:${DIMR_PLATFORM_PREFIX}/lib/libaec/lib \
        CFLAGS="-fPIC" \
        CXXFLAGS="-fPIC" \
        FFLAGS="-fPIC" \
        CC=mpicc \
        CXX=mpicxx \
        FC=mpifort \
        -DMPI_C_COMPILER="${DIMR_PLATFORM_PREFIX}/bin/mpicc" \
        ..
    unset CMAKE_PREFIX_PATH
    unset CMAKE_LIBRARY_PATH
    make -j$MAX_JOBS
    echo $sudoPW | sudo -S make install
    if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
        echo $sudoPW | sudo -S install_name_tool -id "${DIMR_PLATFORM_PREFIX}/lib/libhdf5.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libhdf5.310.dylib
        echo $sudoPW | sudo -S install_name_tool -id "${DIMR_PLATFORM_PREFIX}/lib/libhdf5_hl.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libhdf5_hl.310.dylib
        echo $sudoPW | sudo -S install_name_tool -change "@rpath/libhdf5.310.dylib" "${DIMR_PLATFORM_PREFIX}/lib/libhdf5.310.dylib" ${DIMR_PLATFORM_PREFIX}/lib/libhdf5_hl.310.dylib
    fi
fi


# # Install netcdf-c

export NETCDF_C_VERSION="4.9.2"
export CPPFLAGS="-I${DIMR_PLATFORM_PREFIX}/include"
export LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib"
export LIBS="-ldl"
export HDF5_DIR="${DIMR_PLATFORM_PREFIX}"
export NETCDF_ROOT="${DIMR_PLATFORM_PREFIX}"
if [ "$DIMR_INSTALL_NETCDFC" = "1" ]; then
    cd $DIMR_INSTALL_HOME
    wget https://downloads.unidata.ucar.edu/netcdf-c/${NETCDF_C_VERSION}/netcdf-c-${NETCDF_C_VERSION}.tar.gz
    tar -xzf netcdf-c-${NETCDF_C_VERSION}.tar.gz
    rm netcdf-c-${NETCDF_C_VERSION}.tar.gz
    cd netcdf-c-${NETCDF_C_VERSION}
    ./configure     --prefix=${DIMR_PLATFORM_PREFIX}\
                    --enable-parallel-hdf5 \
                    --enable-shared \
                    CC=mpicc \
                    CXX=mpicxx \
                    FC=mpifort \
                    F77=mpifort \
                    CPPFLAGS="-I${DIMR_PLATFORM_PREFIX}/include" \
                    LDFLAGS="-L${DIMR_PLATFORM_PREFIX}/lib" \
                    CFLAGS="-I${DIMR_PLATFORM_PREFIX}/include -fPIC" \
                    LIBS="-L${DIMR_PLATFORM_PREFIX}/lib" \
                    CXXFLAGS="-fPIC"
    make -j$MAX_JOBS
    echo $sudoPW | sudo -S make install
fi


# # Install netcdf-fortran

export NETCDF_FORTRAN_VERSION="4.6.2"
if [ "$DIMR_INSTALL_NETCDFFORTAN" = "1" ]; then
    cd $DIMR_INSTALL_HOME
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
    echo $sudoPW | sudo -S make install
fi


# Install esmf

export ESMF_VERSION="8.9.0"
export ESMF_DIR=${DIMR_INSTALL_HOME}/esmf-${ESMF_VERSION}
export ESMF_COMM=mpiuni
export ESMF_F90COMPILER=${DIMR_PLATFORM_PREFIX}/bin/mpifort
export ESMF_C_FLAGS="-O3 -march=native -arch arm64"
export ESMF_F90_FLAGS="-O3 -march=native -arch arm64"
export ESMF_INSTALL_PREFIX="${ESMF_PARENT_FOLDER}/esmf-${ESMF_VERSION}"
export ESMF_ROOT=${ESMF_INSTALL_PREFIX}
if [ "$DIMR_INSTALL_ESMF" = "1" ]; then
    cd $DIMR_INSTALL_HOME
    wget https://github.com/esmf-org/esmf/archive/refs/tags/v${ESMF_VERSION}.tar.gz -O esmf-${ESMF_VERSION}.tar.gz
    tar -xzf esmf-${ESMF_VERSION}.tar.gz
    rm esmf-${ESMF_VERSION}.tar.gz
    cd ${DIMR_INSTALL_HOME}/esmf-${ESMF_VERSION}
    if [ -d "${ESMF_INSTALL_PREFIX}" ]; then
        echo "Found previous esmf folder, deleting..."
        echo $sudoPW | sudo -S rm -r ${ESMF_INSTALL_PREFIX}
    fi
    echo $sudoPW | sudo -S mkdir ${ESMF_INSTALL_PREFIX}
    echo $sudoPW | sudo -S chown -R $USER ${ESMF_INSTALL_PREFIX}
    echo $sudoPW | sudo -S chmod -R go-w ${ESMF_INSTALL_PREFIX}

    if [ "$DIMR_PLATFORM_NAME" = "mac_macports" ]; then
        # Workaround so ESMF compiler generates non-clang output as doesn't detect gnu compiler
        cp ${DIMR_INSTALL_HOME}/../build_config/Darwin.gfortranclang.default/build_rules.mk ${ESMF_DIR}/build_config/Darwin.gfortranclang.default/build_rules.mk
    fi

    set +e
    make all    -j$MAX_JOBS \
                ESMF_F90=mpifort \
                ESMF_F77=mpifort \
                ESMF_C=${DIMR_PLATFORM_PREFIX}/bin/gcc \
                ESMF_CXX=${DIMR_PLATFORM_PREFIX}/bin/g++
    set -e
    echo $sudoPW | sudo -S make install ESMF_DIR="${ESMF_DIR}" ESMF_INSTALL_PREFIX="${ESMF_INSTALL_PREFIX}"
fi
export PATH=${ESMF_INSTALL_PREFIX}/bin/binO/${ESMF_PLATFORM_FOLDER}/:${PATH}


# Download Delft3DFM

export DIMR_VERSION="2026.01"
cd $DIMR_INSTALL_HOME
if [ "$DIMR_INSTALL_DIMR_DOWNLOAD" = "1" ]; then
    wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_${DIMR_VERSION}.tar.gz
    tar -xzf DIMRset_${DIMR_VERSION}.tar.gz
    rm DIMRset_${DIMR_VERSION}.tar.gz
    mv Delft3D-DIMRset_${DIMR_VERSION} Delft3D
fi

# Install patches to enable Arm64 and / or gfortran compilation 

cd Delft3D
if [ "$DIMR_INSTALL_DIMR_DOWNLOAD" = "1" ]; then
    cp ../../.gitignore .
    git init
    git add .
    git commit -m "${DIMR_VERSION}"
    git branch -M main
    git tag -a ${DIMR_VERSION} -m "${DIMR_VERSION}" HEAD
    patch -p1 -f -i ../../001-${DIMR_VERSION}.patch --no-backup-if-mismatch --reject-file=/dev/null
    git add .
    git commit -m "${DIMR_VERSION} - Patched for arm64 with 001-${DIMR_VERSION}.patch"
    git tag -a ${DIMR_VERSION}--arm64-patched--001-${DIMR_VERSION} -m "${DIMR_VERSION} - Patched for arm64 with 001-${DIMR_VERSION}.patch" HEAD
fi


# Build Delft3DFM

# Prioritise DIMR_PLATFORM_PREFIX libraries
export CMAKE_PREFIX_PATH="${DIMR_PLATFORM_PREFIX}:$CMAKE_PREFIX_PATH"
cmake ./src/cmake \
    -G "Unix Makefiles" \
    -B build \
    -D CONFIGURATION_TYPE=all \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=install \
    -D CMAKE_Fortran_FLAGS="-fPIC" \
    -D CMAKE_VERBOSE_MAKEFILE=OFF \
    -D Boost_INCLUDE_DIR=${DIMR_PLATFORM_PREFIX}/include/boost
cmake --build build -j$MAX_JOBS --target install --config Release
export PATH=${DIMR_INSTALL_HOME}/Delft3D/install/bin:$PATH