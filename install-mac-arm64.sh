

# ****************************************************************
# ****************************************************************
# ****** Before running this script on Mac Silicon, ************** 
# ****** ensure you have Arm64 gfortran installed. ***************
# ****** For Arm64 gfortran Mac installers, go to: ***************
# ****** https://github.com/fxcoudert/gfortran-for-macOS *********
# ****************************************************************
# ****************************************************************


# Set versions of software at start to allow incremental build

export CMAKE_VERSION="4.2.0"
export NETCDF_FORTRAN_VERSION="4.6.2"
export ESMF_VERSION="8.9.0"
export DIMR_VERSION="2026.01"


# Set related environment variables 

export HOME=$(PWD)/src
export PATH=/usr/local/bin:$PATH
export FC=mpifort 
export CXX=mpicxx 
export CC=mpicc
export LD_LIBRARY_PATH=/usr/local/lib
export ESMF_INSTALL_PREFIX="${HOME}/esmf-${ESMF_VERSION}"
export ESMF_ROOT=${ESMF_INSTALL_PREFIX}
export ESMF_F90COMPILER=/usr/bin/gfortran
export HDF5_PLUGIN_PATH=/opt/local/hdf5/lib/plugin
mkdir -p $HOME


# Install libraries

# We use absolute path to brew to ensure we use Arm64 brew
# as opposed to legacy brew (/usr/local/bin/brew)

/opt/homebrew/bin/brew update
/opt/homebrew/bin/brew install patchelf
/opt/homebrew/bin/brew install cmake
/opt/homebrew/bin/brew install ninja
/opt/homebrew/bin/brew install gcc
/opt/homebrew/bin/brew install openmpi
/opt/homebrew/bin/brew install hdf5-mpi
/opt/homebrew/bin/brew install boost-mpi
/opt/homebrew/bin/brew install gdal
/opt/homebrew/bin/brew install netcdf
/opt/homebrew/bin/brew install petsc
/opt/homebrew/bin/brew install metis
/opt/homebrew/bin/brew install libtiff
/opt/homebrew/bin/brew install sqlite
/opt/homebrew/bin/brew install googletest


# Install latest version of NetCDF-Fortran

cd $HOME
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.2.tar.gz -O netcdf-fortran-4.6.2.tar.gz
tar -xvf netcdf-fortran-4.6.2.tar.gz
rm netcdf-fortran-4.6.2.tar.gz
cd netcdf-fortran-4.6.2
export NETCDF_INC_PATH="/opt/homebrew/include"
export NETCDF_LIB_PATH="$(nc-config --libs)"
./configure CC=mpicc \
            CXX=mpicxx \
            FC=mpifort \
            F77=mpifort \
            CPPFLAGS="-I${NETCDF_INC_PATH}" \
            LDFLAGS="${NETCDF_LIB_PATH} -O3 -arch arm64" \
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
export ESMF_DIR=$(PWD)
export ESMF_COMPILER=gfortranclang
export ESMF_F90COMPILER=/usr/local/bin/gfortran
export ESMF_C_FLAGS="-O3 -march=native -arch arm64"
export ESMF_F90_FLAGS="-O3 -march=native -arch arm64"
export ESMF_BLAS_LIBS="-framework Accelerate"
export ESMF_LAPACK_LIBS="-framework Accelerate"
make all
make install
export PATH=/opt/esmf-8.9.0/bin/binO/Linux.gfortran.32.mpiuni.default/:${PATH}


# Install latest version of DIMR (Deltares Delft3DFM)

cd $HOME
wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_${DIMR_VERSION}.tar.gz
tar -xzf DIMRset_${DIMR_VERSION}.tar.gz
rm DIMRset_${DIMR_VERSION}.tar.gz
mv Delft3D-DIMRset_${DIMR_VERSION} Delft3D


# Install patches to enable Arm64 and / or gfortran compilation 

cd $HOME/Delft3D
patch -p1 -f -i ../../arm64-base.patch
patch -p1 -f -i ../../arm64-${DIMR_VERSION}.patch
git init
git add .
git commit -m "Initial commit"
./build.sh all
export PATH=${HOME}/Delft3D/install/bin:$PATH

