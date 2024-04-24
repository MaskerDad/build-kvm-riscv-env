#! /bin/bash

branch=$1

if [ ! $branch ]; then
    echo "invalid branch name!"
    exit
fi

#build kernel and kvm
bash build_linux_riscv.sh $branch

#update initrd
bash update_initrd.sh $branch

# Launch VM
./qemu-system-riscv64 -cpu rv64 -M virt,aia=aplic-imsic,aia-guests=7 -m 512M -nographic -smp 4 -bios opensbi/build/platform/generic/firmware/fw_jump.bin -kernel $branch/arch/riscv/boot/Image -initrd $branch/rootfs_kvm_riscv64.img -append "root=/dev/ram rw console=ttyS0 earlycon=sbi"
