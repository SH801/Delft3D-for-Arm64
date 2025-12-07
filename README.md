# Delft3DFM for arm64

Due to inability of Intel Fortran compiler to run natively on arm64 platforms, this project is an attempt to produce an arm64 - and ideally Mac-arm64-native - version of Delft3DFM using gnu Fortran compiler.

## Wider motivation

- Desirable to have Delft3DFM working with GNU toolchain; arm64 support is added bonus.
- Many cloud providers are embracing arm64 CPUs as low-cost way to deliver high computing power.
- Was curious to see how difficult it was to switch from Docker Linux (running on arm64 Mac) to Mac arm64 native/non-Docker.

## Limitations

Still to do (07/12/2025):

- Complete platform-specific code modifications for Mac arm 64 - all the supporting libraries 'seem' to compile but not all of Delft3DFM yet. 
- Have only carried out most basic testing (no actual data) of small number of commands - don't know yet if things will break when real data is used.
- No testing carried out yet on parallel/MPI functionality which is a key goal of the MPI compilation.
- Docker file is not MPI-correct yet.

Enjoy!

Stefan