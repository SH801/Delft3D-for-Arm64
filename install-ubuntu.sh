#!/bin/bash

# ---------------------------------------------
# Helper script for building Delft3DFM on linux
# ---------------------------------------------

# Set base directory

export HOME=$(pwd)/delft_src
mkdir -p $HOME


# Install libraries

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update && sudo apt-get install -y  wget nano git cmake build-essential \
                                                gcc g++ gfortran \
                                                mpich patchelf subversion ninja-build pkg-config libssl-dev


# Install newer cmake

cd $HOME
export CMAKE_VERSION="4.2.0"
wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
tar -xzf cmake-${CMAKE_VERSION}.tar.gz
rm cmake-${CMAKE_VERSION}.tar.gz
cd cmake-${CMAKE_VERSION}
./bootstrap --prefix=/usr && make -j$(nproc)
sudo make install


# Setup compilers using mpi

export CC=/usr/bin/mpicc
export FC=/usr/bin/mpifort
export CXX=/usr/bin/mpicxx


# Install further libraries (hoping they'll use mpi compilers)

sudo apt-get update && sudo apt-get install -y 	petsc-dev  \
                                                hdf5-tools hdf5-helpers libhdf5-dev libhdf5-doc libhdf5-serial-dev \
                                                metis libgdal-dev uuid-dev sqlite3 \
                                                libnetcdf-dev libtiff-dev libboost-all-dev libgtest-dev


# Install hdf5 using mpi

cd $HOME
export HDF5_VERSION="1.14.6"
wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-${HDF5_VERSION}.tar.gz
tar -zxvf hdf5-${HDF5_VERSION}.tar.gz
rm hdf5-${HDF5_VERSION}.tar.gz
cd hdf5-hdf5-${HDF5_VERSION}
mkdir build
cd build
export HDF5_PLUGIN_PATH=/usr/hdf5/lib/plugin
cmake \
    -DCMAKE_INSTALL_PREFIX="/usr" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,/usr/lib -Wl,-rpath,/usr/lib/gcc" \
    -DHDF5_ENABLE_PARALLEL=ON \
    -DBUILD_TESTING=OFF \
    CFLAGS="-fPIC" \
    CXXFLAGS="-fPIC" \
    FFLAGS="-fPIC" \
    CC=mpicc \
    CXX=mpicxx \
    FC=mpifort \
    -DMPI_C_COMPILER="/usr/bin/mpicc" \
    ..
make
sudo make install


# Install NetCDF-C

cd $HOME
export NETCDF_C_VERSION="4.9.2"
wget https://downloads.unidata.ucar.edu/netcdf-c/${NETCDF_C_VERSION}/netcdf-c-${NETCDF_C_VERSION}.tar.gz
tar -xzf netcdf-c-${NETCDF_C_VERSION}.tar.gz
rm netcdf-c-${NETCDF_C_VERSION}.tar.gz
cd netcdf-c-${NETCDF_C_VERSION}
export CPPFLAGS="-I/usr/include"
export LDFLAGS="-L/usr/lib"
export LIBS="-ldl"
export HDF5_DIR="/usr"
export NETCDF_ROOT="/usr"
./configure 
    --prefix=/usr \
    CC=mpicc \
    CPPFLAGS="-I/usr/include" \
    LDFLAGS="-L/usr/lib" \
    --enable-shared \
    CFLAGS="-fPIC" \
    CXXFLAGS="-fPIC"
make
sudo make install


# Install latest version of NetCDF-Fortran

cd $HOME
export NETCDF_FORTRAN_VERSION="4.6.2"
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz -O netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
tar -xvf netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
rm netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
cd netcdf-fortran-${NETCDF_FORTRAN_VERSION}
./configure CC=mpicc \
                CXX=mpicxx \
                FC=mpifort \
                F77=mpifort \
                CFLAGS="-fPIC" \
                CXXFLAGS="-fPIC" \
                CPPFLAGS="-I/usr/include" \
                LDFLAGS="-L/usr/lib" \
                LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lm -lz -lsz -lzstd -lblosc -lxml2 -lcurl -ldl" \
                --prefix=/usr \
                --disable-fortran-type-check \
                --enable-shared \
                --host=aarch64-linux-gnu
make
sudo make install


# Install latest version of ESMF

cd $HOME
export ESMF_VERSION="8.9.0"
wget https://github.com/esmf-org/esmf/archive/refs/tags/v${ESMF_VERSION}.tar.gz -O esmf-${ESMF_VERSION}.tar.gz
tar -xzf esmf-${ESMF_VERSION}.tar.gz
rm esmf-${ESMF_VERSION}.tar.gz
cd $HOME/esmf-${ESMF_VERSION}
export ESMF_DIR=$HOME/esmf-${ESMF_VERSION}
export ESMF_COMPILER=gfortran
export ESMF_F90COMPILER=/usr/bin/mpifort
export ESMF_INSTALL_PREFIX="/opt/esmf-${ESMF_VERSION}"
export ESMF_ROOT=${ESMF_INSTALL_PREFIX}
make all
sudo make install ESMF_DIR=$HOME/esmf-${ESMF_VERSION} ESMF_INSTALL_PREFIX="/opt/esmf-${ESMF_VERSION}"
export PATH=/opt/esmf-8.9.0/bin/binO/Linux.gfortran.32.mpiuni.default/:${PATH}


# Install latest version of DIMR (Deltares Delft3DFM)

cd $HOME
export DIMR_VERSION="2026.01"
wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_${DIMR_VERSION}.tar.gz
tar -xzf DIMRset_${DIMR_VERSION}.tar.gz
rm DIMRset_${DIMR_VERSION}.tar.gz
mv Delft3D-DIMRset_${DIMR_VERSION} Delft3D


# Install patches to enable Arm64 compilation

cd $HOME/Delft3D
patch -p1 -f -i ../../arm64-base.patch
patch -p1 -f -i ../../arm64-${DIMR_VERSION}.patch
git init
git add .
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git commit -m "Initial commit"
cmake ./src/cmake -G "Unix Makefiles" -B build -D CONFIGURATION_TYPE=all -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=install -D CMAKE_Fortran_FLAGS="-fPIC"
cmake --build build --target install --config Release
export PATH=${HOME}/Delft3D/install/bin:${PATH}
