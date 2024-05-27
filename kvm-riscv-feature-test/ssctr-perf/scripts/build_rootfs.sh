#!/bin/bash

mkdir $ROOTFS && cd $ROOTFS
wget https://raw.githubusercontent.com/rajnesh-kanwal/common_work/main/rootfs_related/create_rootfs.sh
chmod +x ./create_rootfs.sh
./create_rootfs.sh
