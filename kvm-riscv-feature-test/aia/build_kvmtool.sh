#!/bin/bash

# libdft has been installed in building environment, so can skip the steps.
export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-

git clone https://github.com/avpatel/kvmtool.git
cd kvmtool
git checkout riscv_aia_v1
make lkvm-static -j $(nproc)
${CROSS_COMPILE}strip lkvm-static
cd -
