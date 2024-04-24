#! /bin/bash

export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
git clone https://github.com/tjeznach/linux.git
cd linux
git checkout tjeznach/riscv-iommu-aia

mkdir build
make  O=build defconfig
cd build
../scripts/kconfig/merge_config.sh .config ../../vfio.config
cd ../
make O=build -j $(nproc) Image
cd ../