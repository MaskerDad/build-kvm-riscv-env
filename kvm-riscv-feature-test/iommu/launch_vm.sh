#! /bin/bash

QEMU="qemu/build/qemu-system-riscv64"
KERNEL="linux/build/arch/riscv/boot/Image"
OPEN_SBI="qemu/build/platform/generic/firmware/fw_jump.elf"

NVME0="nvme0.img,format=raw"
NVME1="nvme1.img,format=raw"

myExit() {
    echo $*
    exit 1
}

test -x "${QEMU}" || myExit "Can't find QEMU: ${QEMU}"
test -f "${KERNEL}" || myExit "Can't find KERNEL: ${KERNEL}"
test -f "${OPEN_SBI}" || myExit "Can't find OPEN_SBI: ${OPEN_SBI}"

# machine definition
QARGS="-no-reboot -no-user-config -nographic -machine virt,aia=aplic-imsic,aia-guests=4 -cpu rv64 -smp 2"
QARGS="${QARGS} -m 4G -object memory-backend-file,id=sysmem,mem-path=/tmp/4g,size=4G,share=on"

# emulation backends
QARGS="${QARGS} -drive file=${NVME0},read-only=off,id=nvme0"
QARGS="${QARGS} -drive file=${NVME1},read-only=off,id=nvme1"
QARGS="${QARGS} -netdev user,id=host-net,hostfwd=tcp::2223-:23"
# emulated devices, use virtio-blk for host OS
QARGS="${QARGS} -device x-riscv-iommu-pci,addr=1.0"
QARGS="${QARGS} -device virtio-blk-pci,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on,drive=nvme0,addr=3.0"
QARGS="${QARGS} -device virtio-net-pci,romfile=,netdev=host-net,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on,addr=7.0"
QARGS="${QARGS} -device nvme,serial=87654321,drive=nvme1,addr=4.0"

# kernel arguments
KARGS="nokaslr earlycon=sbi console=ttyS0 root=/dev/vda"

# Optional - enable IOMMU DMA translation trace
# QARGS="${QARGS} -trace riscv_iommu_dma"

# run qemu
${QEMU} -bios ${OPEN_SBI} -append "${KARGS}" -kernel ${KERNEL} ${QARGS}
