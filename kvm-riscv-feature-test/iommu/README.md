# RISCV IOMMU on qemu

## Build Qemu
add --enable-slirp option for -netdev

    export ARCH=riscv
    export CROSS_COMPILE=riscv64-linux-gnu-
    git clone https://github.com/tjeznach/qemu.git
    cd qemu
    git checkout tjeznach/riscv-iommu
    git submodule update --init
    ./configure --target-list="riscv32-softmmu riscv64-softmmu" --enable-slirp
    make -j $(nproc)

## Build opensbi

    make -C roms/opensbi O=../../build PLATFORM_RISCV_XLEN=64 PLATFORM=generic -j $(nproc)
    cd -

## Build linux kernel
    export ARCH=riscv
    export CROSS_COMPILE=riscv64-linux-gnu-
    git clone https://github.com/tjeznach/linux.git
    cd linux
    git checkout tjeznach/riscv-iommu-aia

    mkdir build
    make  O=build -j $(nproc) defconfig
    cd build
    ../scripts/kconfig/merge_config.sh .config ../../vfio.config
    cd ..
    make O=build -j $(nproc) Image
    cd ../

 ## Make the rootfs
    sudo su
    truncate -s 1G kinetic.img
    mkfs.ext4 kinetic.img
    mkdir -p kinetic
    mount -oloop kinetic.img kinetic
    debootstrap --arch=riscv64 kinetic kinetic
    sed 's/root:.:/root::/' -i kinetic/etc/shadow
    echo 'riscv-guest' > kinetic/etc/hostname
    umount kinetic
    cp kinetic.img nvme1.img
    mount -oloop kinetic.img kinetic
    cp lkvm-static kinetic/usr/bin
    cp linux/build/arch/riscv/boot/Image kinetic/usr/share/Image
    echo 'riscv-host' > kinetic/etc/hostname
    cp testcmd.sh kinetic/usr/bin
    umount kinetic
    cp kinetic.img nvme0.img
    rm -rf kinetic*
    exit

## Build crosvm

    git clone git@github.com:tjeznach/crosvm.git
    cd crosvm
    git checkout tjeznach/topic/riscv-iommu
    git submodule update --init

    export PKG_CONFIG_ALLOW_CROSS="true"
    export CROS_RUST=1
    cargo build --no-default-features --target=riscv64gc-unknown-linux-gnu --release

You can see the [document](fix_error_in_building_crosvm.md) as reference to fix the errors if you meet.

## Launch the VM

    qemu/build/qemu-system-riscv64 -bios qemu/build/platform/generic/firmware/fw_jump.elf -append "nokaslr earlycon=sbi console=ttyS0 root=/dev/vda rw" -kernel linux/build/arch/riscv/boot/Image -no-reboot -no-user-config -nographic -machine virt,aia=aplic-imsic,aia-guests=4 -cpu rv64 -smp 2 -m 4G -object memory-backend-file,id=sysmem,mem-path=/tmp/4g,size=4G,share=on -drive file=nvme0.img,format=raw,read-only=off,id=nvme0 -drive file=nvme1.img,format=raw,read-only=off,id=nvme1 -netdev user,id=host-net,hostfwd=tcp::2223-:23 -device x-riscv-iommu-pci,addr=1.0 -device virtio-blk-pci,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on,drive=nvme0,addr=3.0 -device virtio-net-pci,romfile=,netdev=host-net,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on,addr=7.0 -device nvme,serial=87654321,drive=nvme1,addr=4.0



    echo "0000:00:04.0" > /sys/bus/pci/devices/0000:00:04.0/driver/unbind
    echo "1b36 0010" > /sys/bus/pci/drivers/vfio-pci/new_id

    crosvm --no-syslog run --disable-sandbox -p 'nokaslr console=ttyS0 root=/dev/nvme0n1' --vfio "/sys/bus/pci/devices/0000:00:04.0" /usr/share/Image

[reference](https://raw.githubusercontent.com/tjeznach/docs/master/riscv-iommu/run-qemu.sh)
