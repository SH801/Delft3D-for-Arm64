# Delft3DFM for arm64

Intel Fortran compiler does not run natively on arm64 platforms so this project aims to provide an arm64 (and Mac-arm64-native) version of Delft3DFM using GNU Fortran compiler (`gfortran`).

## Purpose

- **GNU Toolchain**: Desirable to have Delft3DFM working with widely used and supported GNU toolchain. 
- **Streamlined build**: Streamline Delft3DFM build process by specifying reliable library versions in single install script.
- **Arm64**: Cloud providers are embracing arm64 CPUs as low-cost way to deliver high computing power.
- **Mac Silicon platforms**: Latest Macs use Arm64 chipsets. 
## Limitations

As of 12/12/2025:

- Only carried out most basic testing (no actual data) of small number of commands. Things may still break when real data is used.
- No testing carried out on parallel/MPI functionality which is a key goal of the MPI compilation.
- Docker file is not MPI-correct.

## Installing - Mac

Install [macports](https://www.macports.org/install.php) then run shell installer:

`
./install.sh
`

## Installing - Ubuntu 24.04

Run shell installer:

`
./install.sh
`

## About

Created by Stefan Haselwimmer, 2025.