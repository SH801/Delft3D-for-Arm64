

# Default Ubuntu version = 24.04 but allow different versions through CLI, eg:
# docker build --build-arg UBUNTU_VERSION=22.04 -t delft3d-ubuntu-22-04 -f ubuntu.dockerfile .
# docker build --build-arg UBUNTU_VERSION=20.04 -t delft3d-ubuntu-20-04 -f ubuntu.dockerfile .
# docker build --build-arg UBUNTU_VERSION=18.04 -t delft3d-ubuntu-18-04 -f ubuntu.dockerfile .

ARG UBUNTU_VERSION=24.04  # Sets 24.04 as the default version
FROM ubuntu:${UBUNTU_VERSION}


ENV HOME=/root

# Set versions of software at start to allow incremental build

ENV CMAKE_VERSION="3.31.10"
ENV NETCDF_FORTRAN_VERSION="4.6.2"
ENV ESMF_VERSION="8.9.0"
ENV DIMR_VERSION="2026.01"


# Set related environment variables 

ENV FC=mpifort 
ENV CXX=mpicxx 
ENV CC=mpicc
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV ESMF_DIR=$HOME/esmf-${ESMF_VERSION}
ENV ESMF_INSTALL_PREFIX="/opt/esmf-${ESMF_VERSION}"
ENV ESMF_ROOT=${ESMF_INSTALL_PREFIX}
ENV ESMF_F90COMPILER=/usr/bin/gfortran
ENV PATH=/usr/local/bin:${HOME}/Delft3D/build_all/install/bin:${PATH}


# Install libraries

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt install -y software-properties-common dirmngr build-essential
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt update
RUN apt-get update && apt-get install -y 	ninja-build petsc-dev patchelf wget nano git subversion \
											hdf5-tools hdf5-helpers libhdf5-dev libhdf5-doc libhdf5-serial-dev \
											netcdf-bin metis libgdal-dev uuid-dev sqlite3 \
											libnetcdf-dev libtiff-dev libboost-all-dev libgtest-dev


# Install latest version of CMake

WORKDIR $HOME
RUN wget https://github.com/Kitware/CMake/archive/refs/tags/v${CMAKE_VERSION}.tar.gz -O CMake-${CMAKE_VERSION}.tar.gz
RUN tar -xzf CMake-${CMAKE_VERSION}.tar.gz
RUN rm CMake-${CMAKE_VERSION}.tar.gz
WORKDIR $HOME/CMake-${CMAKE_VERSION}
RUN ./bootstrap
RUN make install



# Install latest version of NetCDF-Fortran

WORKDIR $HOME
RUN wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz -O netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz 
RUN tar -xzf netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
RUN rm netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz
WORKDIR $HOME/netcdf-fortran-${NETCDF_FORTRAN_VERSION}
RUN ./configure CC=mpicc \
				CXX=mpicxx \
				FC=mpifort \
				F77=mpifort \
				CPPFLAGS="-I/usr/local/include" \
				LDFLAGS="-L/usr/local/lib" \
				--prefix=/usr/local \
				--disable-fortran-type-check \
				--enable-shared \
				--host=aarch64-linux-gnu
RUN make
RUN make install


# Install latest version of ESMF

WORKDIR $HOME
RUN wget https://github.com/esmf-org/esmf/archive/refs/tags/v${ESMF_VERSION}.tar.gz -O esmf-${ESMF_VERSION}.tar.gz
RUN tar -xzf esmf-${ESMF_VERSION}.tar.gz
RUN rm esmf-${ESMF_VERSION}.tar.gz
WORKDIR $HOME/esmf-${ESMF_VERSION}
RUN make all
RUN make install
ENV PATH=/opt/esmf-8.9.0/bin/binO/Linux.gfortran.32.mpiuni.default/:${PATH}


# Install latest version of DIMR (Deltares Delft3DFM)

WORKDIR $HOME
RUN wget https://github.com/Deltares/Delft3D/archive/refs/tags/DIMRset_${DIMR_VERSION}.tar.gz
RUN tar -xzf DIMRset_${DIMR_VERSION}.tar.gz
RUN rm DIMRset_${DIMR_VERSION}.tar.gz
RUN mv Delft3D-DIMRset_${DIMR_VERSION} Delft3D
WORKDIR $HOME/Delft3D


# Install patch to enable Arm64 compilation

WORKDIR $HOME
COPY *.patch .
WORKDIR $HOME/Delft3D
RUN patch -p1 -f -i ../001-${DIMR_VERSION}.patch || true
RUN git init
RUN git add .
RUN git config --global user.email "you@example.com"
RUN git config --global user.name "Your Name"
RUN git commit -m "Initial commit"
RUN ./build.sh all
