#! /bin/sh

mount -t debugfs debugfs /sys/kernel/debug
insmod modules/kvm.ko
echo 132 > /proc/sys/vm/nr_hugepages
mkdir hugetlbfs
mount -t hugetlbfs none /hugetlbfs

lkvm-static run -m 256 -c2 --console virtio -p "earlycon" -k /modules/Image --hugetlbfs /hugetlbfs --debug
