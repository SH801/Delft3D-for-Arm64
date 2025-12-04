# Set versions of software at start to allow incremental build

export CMAKE_VERSION="4.2.0"
export NETCDF_FORTRAN_VERSION="4.6.2"
export ESMF_VERSION="8.9.0"
export DIMR_VERSION="2026.01"
export HDF5_PLUGIN_PATH=/opt/local/hdf5/lib/plugin


# Set related environment variables 

export FC=mpifort 
export CXX=mpicxx 
export CC=mpicc
export LD_LIBRARY_PATH=/usr/local/lib
export ESMF_INSTALL_PREFIX="/opt/esmf-${ESMF_VERSION}"
export ESMF_ROOT=${ESMF_INSTALL_PREFIX}
export ESMF_F90COMPILER=/usr/bin/gfortran
export $HOME=${PWD}
export PATH=/usr/local/bin:${HOME}/Delft3D/build_all/install/bin:${PATH}


# Install libraries

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && sudo apt-get install -y 	ninja-build petsc-dev patchelf wget nano git build-essential subversion \
                                                hdf5-tools hdf5-helpers libhdf5-dev libhdf5-doc libhdf5-serial-dev \
                                                netcdf-bin metis libgdal-dev uuid-dev sqlite3 \
                                                libnetcdf-dev libtiff-dev libboost-all-dev libgtest-dev


# Install latest version of NetCDF-Fortran

cd $HOME
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.2.tar.gz -O netcdf-fortran-4.6.2.tar.gz
tar -xvf netcdf-fortran-4.6.2.tar.gz
rm netcdf-fortran-4.6.2.tar.gz
cd netcdf-fortran-4.6.2
./configure CC=mpicc \
                CXX=mpicxx \
                FC=mpifort \
                F77=mpifort \
                CPPFLAGS="-I/usr/local/include" \
                LDFLAGS="-L/usr/local/lib" \
                --prefix=/usr/local \
                --disable-fortran-type-check \
                --enable-shared \
                --host=aarch64-linux-gnu
make
make install


# Install latest version of ESMF

cd $HOME
wget https://github.com/esmf-org/esmf/archive/refs/tags/v${ESMF_VERSION}.tar.gz -O esmf-${ESMF_VERSION}.tar.gz
tar -xzf esmf-${ESMF_VERSION}.tar.gz
rm esmf-${ESMF_VERSION}.tar.gz
cd $HOME/esmf-${ESMF_VERSION}
export ESMF_DIR=${PWD}
export ESMF_COMPILER=gfortranclang
export ESMF_F90COMPILER=/usr/local/bin/gfortran
make all
make install
export PATH=/opt/esmf-8.9.0/bin/binO/Linux.gfortran.32.mpiuni.default/:${PATH}


# Install latest version of DIMR (Deltares Delft3DFM)

cd $HOME
wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_{DIMR_VERSION}.tar.gz
tar -xzf DIMRset_{DIMR_VERSION}.tar.gz
rm DIMRset_{DIMR_VERSION}.tar.gz
mv Delft3D_DIMRset_{DIMR_VERSION} Delft3D
cd $HOME/Delft3D


# Install patches to enable Arm64 compilation

cd Delft3D
patch -p1 -f -i ../arm64-base.patch
patch -p1 -f -i ../arm64-${DIMR_VERSION}.patch
git init
git add .
git commit -m "Initial commit"
./build.sh all
