#!/bin/bash

branch=$1

if [ ! $branch ]; then
    echo "invalid branch name!"
    exit
fi

export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
git clone https://github.com/avpatel/linux.git
cd linux
#git checkout riscv_aia_v6
#git checkout riscv_kvm_aia_hwaccel_v1
git checkout $branch
cd -
mkdir -p $branch
make -C linux O=`pwd`/$branch defconfig
make -C linux O=`pwd`/$branch -j $(nproc)
