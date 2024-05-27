#!/bin/bash

git clone --depth=1 -b ctr_upstream -j8 https://github.com/rajnesh-kanwal/linux.git $LINUX
cd $LINUX
export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
mkdir build
make O=./build defconfig
make O=./build -j$(nproc)
cd ..
