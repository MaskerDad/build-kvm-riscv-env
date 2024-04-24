#! /bin/bash

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
#cp lkvm-static kinetic/usr/bin
cp crosvm/target/riscv64gc-unknown-linux-gnu/release/crosvm kinetic/usr/bin/
cp linux/build/arch/riscv/boot/Image kinetic/usr/share/Image
echo 'riscv-host' > kinetic/etc/hostname
cp testcmd.sh kinetic/usr/bin/
umount kinetic
cp kinetic.img nvme0.img
rm -rf kinetic*
