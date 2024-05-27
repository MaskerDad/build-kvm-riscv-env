#!/bin/bash

cd $ROOTFS
dd if=/dev/zero of=rootfs.ext4 bs=1G count=4
mkfs.ext4 rootfs.ext4
mkdir ./tmp
sudo mount rootfs.ext4 ./tmp
sudo cp -rp ./temp-rootfs/* ./tmp/
sudo umount ./tmp
