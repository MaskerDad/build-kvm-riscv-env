#!/bin/bash

git clone --depth=1 -b ctr_upstream --recurse-submodules -j8 https://github.com/rajnesh-kanwal/qemu.git $QEMU
cd $QEMU
mkdir build && cd ./build
../configure --target-list="riscv64-softmmu" --enable-plugins
make -j$(nproc)
cd ../roms/
make opensbi64-generic
