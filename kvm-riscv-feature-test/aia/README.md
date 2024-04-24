# KVM riscv AIA on qemu

## Build Qemu
For this case, the qemu must include riscv hypersior extension and aia.

    git clone https://gitlab.com/qemu-project/qemu.git
    cd qemu
    git submodule update --init --recursive
    ./configure --target-list="riscv64-softmmu"
    make -j $(nproc)
    cp build/qemu-system-riscv64 ../
    cd -

## Build kvmtool
libdft has been installed in building environment, so can skip the steps.
If you want to install libdft, please see the [document](../riscv_kvm/README.md).

    export ARCH=riscv
    export CROSS_COMPILE=riscv64-unknown-linux-gnu-

    git clone https://github.com/avpatel/kvmtool.git
    cd kvmtool
    git checkout riscv_aia_v1
    make lkvm-static -j $(nproc)
    ${CROSS_COMPILE}strip lkvm-static
    cd -

## Build linux kernel for host and guest

    export ARCH=riscv
    export CROSS_COMPILE=riscv64-unknown-linux-gnu-
    git clone https://github.com/avpatel/linux.git
    cd linux
    git checkout riscv_aia_v6
    cd -
    mkdir -p riscv_aia_v6
    make -C linux O=`pwd`/riscv_aia_v6 defconfig -j $(nproc)
    make -C linux O=`pwd`/riscv_aia_v6 -j $(nproc)

 ## Update the rootfs
 The steps of making `rootfs_kvm_riscv64.img` are described in [document](../riscv_kvm/README.md).

    mkdir initrd
    cp rootfs_kvm_riscv64.img initrd/
    cd initrd
    cpio -ivmd < rootfs_kvm_riscv64.img
    rm rootfs_kvm_riscv64.img

    cp -f ../kvmtool/lkvm-static usr/bin/
    cp -f ../riscv_aia_v6/arch/riscv/boot/Image modules/
    cp -f ../riscv_aia_v6/arch/riscv/kvm/kvm.ko modules/

    find ./ | cpio -o -H newc > ../rootfs_kvm_riscv64.img
    cd -
    rm initrd -rf

## launch the VM

    ./qemu-system-riscv64 -cpu rv64 -M virt,aia=aplic-imsic,aia-guests=7 -m 512M -nographic -smp 4 -bios opensbi/build/platform/generic/firmware/fw_jump.bin -kernel riscv_aia_v6/arch/riscv/boot/Image -initrd ./rootfs_kvm_riscv64.img -append "root=/dev/ram rw console=ttyS0 earlycon=sbi"

load kvm module and launch the new VM
    mount -t debugfs debugfs /sys/kernel/debug
    insmod modules/kvm.ko
    echo 132 > /proc/sys/vm/nr_hugepages
    mkdir hugetlbfs
    mount -t hugetlbfs none /hugetlbfs

    lkvm-static run -m 256 -c2 --console virtio -p "earlycon" -k /modules/Image --hugetlbfs /hugetlbfs --debug