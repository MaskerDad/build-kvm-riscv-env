#! /bin/bash

path=$1

if [ ! $path ]; then
    echo "invalid branch name!"
    exit
fi

mkdir initrd
cp rootfs_kvm_riscv64.img initrd/
cd initrd
cpio -ivmd < rootfs_kvm_riscv64.img
rm rootfs_kvm_riscv64.img

cp -f ../kvmtool/lkvm-static usr/bin/
cp -f ../testcmd_in_vm.sh usr/bin/
cp -f ../$path/arch/riscv/boot/Image modules/
cp -f ../$path/arch/riscv/kvm/kvm.ko modules/

find ./ | cpio -o -H newc > ../$path/rootfs_kvm_riscv64.img
cd -
rm initrd -rf
