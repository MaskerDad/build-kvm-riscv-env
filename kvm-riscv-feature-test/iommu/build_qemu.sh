#!/bin/bash

export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
git clone https://github.com/tjeznach/qemu.git
cd qemu
git checkout tjeznach/riscv-iommu
git submodule update --init
./configure --target-list="riscv64-softmmu" --enable-slirp
make -j $(nproc)

make -C roms/opensbi CROSS_COMPILE=riscv64-linux-gnu- O=../../build PLATFORM_RISCV_XLEN=64 PLATFORM=generic -j $(nproc)
cd -