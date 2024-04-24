#! /bin/bash

cat /sys/firmware/devicetree/base/model
printf '\n'
ls /sys/bus/pci/devices/0000\:00\:0?.0/iommu_group -l
ls /sys/bus/pci/devices/0000\:00\:0?.0/iommu -l

export BDF="0000:00:04.0"
export DID="1b36 0010"

echo "$BDF" > /sys/bus/pci/devices/$BDF/driver/unbind
echo "$DID" > /sys/bus/pci/drivers/vfio-pci/new_id

#lkvm-static run -m 256 -c2 --console virtio \
#    -p "nokaslr console=ttyS0 root=/dev/nvme0n1" \
#    -k /usr/share/Image --vfio-pci 0000:00:04.0 -d /dev/nvme0n1

/usr/bin/crosvm.elf --no-syslog run --disable-sandbox \
    -p 'nokaslr console=ttyS0 root=/dev/nvme0n1' \
    --vfio "/sys/bus/pci/devices/$BDF" \
    /usr/share/Image
