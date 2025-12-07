#!/bin/bash

# ---------------------------------------------
# Helper script for building Delft3DFM on Mac Arm64
# 07/12/2025: Still incomplete due to platform-specific code
# ---------------------------------------------


# General setup

export HOME=$(pwd)/delft_src
mkdir -p $HOME
# Remove brew from path
export PATH=$(echo $PATH | sed 's#\(:/opt/homebrew[^:]*\)*##g')
export PATH="/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:$PATH"


# Install gcc15 and other non-DIMR-specific tools including gfortran

sudo port install gcc15 cmake wget nano git patchelf subversion ninja pkgconfig openssl
sudo port select --set gcc mp-gcc15

export CC=/opt/local/bin/gcc-mp-15
export CXX=/opt/local/bin/g++-mp-15
export FC=/opt/local/bin/gfortran-mp-15
export CFLAGS="-O2 -arch arm64"
export LDFLAGS="-L/opt/local/lib/gcc15"
export LIBS="-lstdc++ -lgfortran"


# Install mpich

cd $HOME
export MPICH_VERSION="4.3.2"
wget https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz
tar -xvf mpich-${MPICH_VERSION}.tar.gz
rm mpich-${MPICH_VERSION}.tar.gz
cd mpich-${MPICH_VERSION}
./configure \
  --prefix=/opt/local \
  CC=/opt/local/bin/gcc-mp-15 \
  CXX=/opt/local/bin/g++-mp-15 \
  FC=/opt/local/bin/gfortran-mp-15 \
  --enable-fortran=all \
  --enable-cxx \
  --enable-shared \
  CFLAGS="-O2 -arch arm64" \
  LDFLAGS="-L/opt/local/lib/gcc15" \
  LIBS="-lstdc++ -lgfortran"
make -j$(sysctl -n hw.ncpu)
sudo make install


# Install petsc

cd $HOME
export PETSC_VERSION="3.24.2"
wget https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz
tar -xzf petsc-${PETSC_VERSION}.tar.gz
rm petsc-${PETSC_VERSION}.tar.gz
cd petsc-${PETSC_VERSION}
sudo mkdir /opt/local/petsc
sudo chown $USER /opt/local/petsc
./configure \
    --prefix=/opt/local/petsc \
    --with-debugging=0 \
    --with-fortran-bindings \
    --with-pic \
    --with-shared-libraries \
    --with-scalar-type=real \
    --with-c-compiler=/opt/local/bin/mpicc \
    --with-cxx-compiler=/opt/local/bin/mpicxx \
    --with-fortran-compiler=/opt/local/bin/mpifort \
    --with-make-exec=/usr/local/bin/gmake
    --download-fblaslapack \
    --download-metis \
    --download-parmetis \
    --download-hypre \
    --download-scalapack \
    LDFLAGS="-L/opt/local/lib/gcc15" \
    COPTFLAGS='-O3 -march=native' \
    CXXOPTFLAGS='-O3 -march=native' \
    FOPTFLAGS='-O3 -march=native'
make PETSC_DIR=`pwd` PETSC_ARCH=arch-darwin-c-opt all
make PETSC_DIR=`pwd` PETSC_ARCH=arch-darwin-c-opt install
export PETSC_DIR=/opt/local/petsc
export PETSC_INCLUDE_DIRS=/opt/local/petsc/include
export PKG_CONFIG_PATH="${PETSC_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"


# With mpi installed, set up environment variables

export CC=/opt/local/bin/mpicc
export FC=/opt/local/bin/mpifort
export CXX=/opt/local/bin/mpicxx
export CFLAGS="-O2 -arch arm64"
export FFLAGS="-O2 -arch arm64"
export CXXFLAGS="-O2 -arch arm64"
export LDFLAGS="-L/opt/local/lib -L/opt/local/lib/gcc15"


# Install rest of software

sudo port install szip zlib metis proj json-c gdal ossp-uuid tiff gtest


# Backup existing szlib and create symlink to macports szlib to replace backed-up szlib

#mv /usr/local/lib/libsz.2.0.1.dylib /usr/local/lib/libsz.2.0.1.dylib.bak
#sudo ln -s /opt/local/lib/libsz.2.dylib /usr/local/lib/libsz.2.0.1.dylib


# Install hdf5 using mpi

cd $HOME
export HDF5_VERSION="1.14.6"
wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-${HDF5_VERSION}.tar.gz
tar -zxvf hdf5-${HDF5_VERSION}.tar.gz
rm hdf5-${HDF5_VERSION}.tar.gz
cd hdf5-hdf5-${HDF5_VERSION}
mkdir build
cd build
/opt/local/bin/cmake \
    -DCMAKE_INSTALL_PREFIX="/opt/local" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,/opt/local/lib -Wl,-rpath,/opt/local/lib/gcc15" \
    -DHDF5_ENABLE_PARALLEL=ON \
    -DBUILD_TESTING=OFF \
    CFLAGS="-fPIC" \
    CXXFLAGS="-fPIC" \
    FFLAGS="-fPIC" \
    CC=mpicc \
    CXX=mpicxx \
    FC=mpifort \
    F77=mpifort \
    -DMPI_C_COMPILER="/opt/local/bin/mpicc" \
    ..
make -j$(sysctl -n hw.ncpu)
sudo make install


# Install netcdf-c

cd $HOME
export NETCDF_C_VERSION="4.9.2"
wget https://downloads.unidata.ucar.edu/netcdf-c/${NETCDF_C_VERSION}/netcdf-c-${NETCDF_C_VERSION}.tar.gz
tar -xzf netcdf-c-${NETCDF_C_VERSION}.tar.gz
rm netcdf-c-${NETCDF_C_VERSION}.tar.gz
cd netcdf-c-${NETCDF_C_VERSION}
export CPPFLAGS="-I/opt/local/include"
export LDFLAGS="-L/opt/local/lib"
export LIBS="-ldl"
export HDF5_DIR="/opt/local"
export NETCDF_ROOT="/opt/local"
./configure     --prefix=/opt/local\
                CC=mpicc    
                CXX=mpicxx \
                FC=mpifort \
                F77=mpifort \
                --enable-parallel-hdf5 \
                CPPFLAGS="-I/opt/local/include" \
                LDFLAGS="-L/opt/local/lib" \
                --enable-shared \
                CFLAGS="-I/opt/local/include -fPIC" \
                LIBS="-L/opt/local/lib -lnetcdf" \
                CXXFLAGS="-fPIC"
make -j$(sysctl -n hw.ncpu)
sudo make install


# Install netcdf-fortran

cd $HOME
export NETCDF_FORTRAN_VERSION="4.6.2"
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz -O netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
tar -xvf netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
rm netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
cd netcdf-fortran-${NETCDF_FORTRAN_VERSION}
./configure     --prefix=/opt/local \
                CC=mpicc \
                CXX=mpicxx \
                FC=mpifort \
                F77=mpifort \
                CFLAGS="-fPIC" \
                CXXFLAGS="-fPIC" \
                CPPFLAGS="-I/opt/local/include" \
                LDFLAGS="-L/opt/local/lib" \
                LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lm -lz -lsz -lzstd -lblosc -lxml2 -lcurl -ldl" \
                --disable-fortran-type-check \
                --disable-shared \
                --enable-static \
                --host=aarch64-linux-gnu
make -j$(sysctl -n hw.ncpu)
sudo make install


# Install boost

cd $HOME
wget https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.bz2
tar xf boost_1_89_0.tar.bz2
rm boost_1_89_0.tar.bz2
cd boost_1_89_0
./bootstrap.sh \
  --prefix=/opt/local \
  --with-libraries=system,filesystem,program_options
sudo ./b2 install \
  architecture=arm \
  address-model=64 \
  link=static \
  runtime-link=shared \
  -j$(sysctl -n hw.ncpu)


# Install esmf

cd $HOME
export ESMF_VERSION="8.9.0"
wget https://github.com/esmf-org/esmf/archive/refs/tags/v${ESMF_VERSION}.tar.gz -O esmf-${ESMF_VERSION}.tar.gz
tar -xzf esmf-${ESMF_VERSION}.tar.gz
rm esmf-${ESMF_VERSION}.tar.gz
cd $HOME/esmf-${ESMF_VERSION}
sudo mkdir /opt/local/esmf-${ESMF_VERSION}
sudo chown $USER /opt/local/esmf-${ESMF_VERSION}
export ESMF_DIR=$HOME/esmf-${ESMF_VERSION}
export ESMF_COMPILER=gfortranclang
export ESMF_COMM=mpiuni
export ESMF_F90COMPILER=/opt/local/bin/mpifort
export ESMF_C_FLAGS="-O3 -march=native -arch arm64"
export ESMF_F90_FLAGS="-O3 -march=native -arch arm64"
export ESMF_INSTALL_PREFIX="/opt/esmf-${ESMF_VERSION}"
export ESMF_ROOT=${ESMF_INSTALL_PREFIX}

# Hacky-workaround so ESMF compiler generates non-clang output

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

make -j all ESMF_F90=mpifort \
    ESMF_F77=mpifort \
    ESMF_C=/opt/local/bin/gcc-mp-15 \
    ESMF_CXX=/opt/local/bin/g++-mp-15
sudo make install ESMF_DIR=$HOME/esmf-${ESMF_VERSION} ESMF_INSTALL_PREFIX="/opt/esmf-${ESMF_VERSION}"
export PATH=/opt/local/esmf-${ESMF_VERSION}/bin/binO/Darwin.gfortranclang.64.mpiuni.default/:${PATH}


# Download Delft3DFM

cd $HOME
export DIMR_VERSION="2026.01"
#export LIBRARY_PATH="${LIBRARY_PATH}:${SDK_PATH}/usr/lib"
wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_${DIMR_VERSION}.tar.gz
tar -xzf DIMRset_${DIMR_VERSION}.tar.gz
rm DIMRset_${DIMR_VERSION}.tar.gz
mv Delft3D-DIMRset_${DIMR_VERSION} Delft3D


# Install patches to enable Arm64 and / or gfortran compilation 

cd Delft3D
patch -p1 -f -i ../../arm64-base.patch
patch -p1 -f -i ../../arm64-${DIMR_VERSION}.patch
git init
git add .
git commit -m "Initial commit"


# Build Delft3DFM

export PKG_FOLDER=$(pwd)/pkgconfig
mkdir -p ${PKG_FOLDER}
cat << EOF > "${PKG_FOLDER}/proj.pc"
prefix=/opt/local/lib/proj9
libdir=\${prefix}/lib64
includedir=\${prefix}/include
datarootdir=\${prefix}/share
datadir=\${datarootdir}/proj
Name: PROJ
Description: Coordinate transformation software library
Requires:
Version: 9.2.0
Libs: -L\${libdir} -lproj
Libs.private: -lpthread -lstdc++ -lm -ldl
Requires.private: sqlite3 libtiff-4 libcurl
Cflags: -I\${includedir}
EOF
export PKG_CONFIG_PATH="pkgconfig:${PKG_CONFIG_PATH}"

cmake ./src/cmake -G "Unix Makefiles" \
    -B build \
    -D CONFIGURATION_TYPE=all \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=install \
    -D CMAKE_Fortran_FLAGS="-fPIC" 
cmake --build build --target install --config Release
export PATH=${HOME}/Delft3D/install/bin:$PATH