# 1 qemu-host

## 1.1 qemu build

```shell
export WS=`pwd`

# some dependencies
sudo apt install git gcc g++ wget flex bison bc cpio make pkg-config libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev libncurses-dev libssl-dev ninja-build python3-venv libslirp-dev

# qemu build
git clone --depth=1 -b ctr_upstream --recurse-submodules -j8 https://github.com/rajnesh-kanwal/qemu.git
cd ./qemu
mkdir build && cd ./build

../configure --enable-kvm --enable-slirp --enable-plugins --enable-virtfs --enable-debug --enable-vnc --enable-werror --enable-vhost-net --target-list="riscv64-softmmu" 

make -j8
cd ../roms/
make opensbi64-generic

qemu-system-riscv64 --version

export QEMU=$WS/qemu/build
```

## 1.2 kernel build

```shell
git clone --depth=1 -b perf-kvm-stat-v3 -j8 https://github.com/zcxGGmu/linux.git
export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
make O=./build defconfig
# make O=./build menuconfig
make O=./build -j8
cd ..

export LINUX=$WS/linux/build/arch/riscv/boot
export KVM=$WS/linux/build/arch/riscv/kvm
```

## 1.3 ubuntu-riscv rootfs

```shell
mkdir rootfs && cd ./rootfs

# build rootfs
# Install pre-reqs
sudo apt install debootstrap qemu qemu-user-static binfmt-support dpkg-cross --no-install-recommends

# Generate minimal bootstrap rootfs
sudo debootstrap --arch=riscv64 --foreign jammy ./temp-rootfs http://ports.ubuntu.com/ubuntu-ports

# chroot to it and finish debootstrap
sudo chroot temp-rootfs /bin/bash

/debootstrap/debootstrap --second-stage

# Add package sources
cat >/etc/apt/sources.list <<EOF
deb http://ports.ubuntu.com/ubuntu-ports jammy main restricted

deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted

deb http://ports.ubuntu.com/ubuntu-ports jammy universe
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates universe

deb http://ports.ubuntu.com/ubuntu-ports jammy multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates multiverse

deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse

deb http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted
deb http://ports.ubuntu.com/ubuntu-ports jammy-security universe
deb http://ports.ubuntu.com/ubuntu-ports jammy-security multiverse
EOF

# Install essential packages
apt-get update
apt-get install --no-install-recommends -y util-linux haveged openssh-server systemd kmod initramfs-tools conntrack ebtables ethtool iproute2 iptables mount socat ifupdown iputils-ping vim dhcpcd5 neofetch sudo chrony

# Create base config files
mkdir -p /etc/network
cat >>/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

cat >/etc/fstab <<EOF
LABEL=rootfs	/	ext4	user_xattr,errors=remount-ro	0	1
EOF

echo "Ubuntu-riscv64" > /etc/hostname

# Disable some services on Qemu
ln -s /dev/null /etc/systemd/network/99-default.link
ln -sf /dev/null /etc/systemd/system/serial-getty@hvc0.service

# Set root passwd
echo "root:riscv" | chpasswd

sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

# Clean APT cache and debootstrap dirs
rm -rf /var/cache/apt/

# Exit chroot
exit
sudo tar -cSf Ubuntu-Jammy-rootfs.tar -C temp-rootfs .
gzip Ubuntu-Jammy-rootfs.tar
rm -rf temp-rootfs
    
# create rootfs.ext4
dd if=/dev/zero of=rootfs.ext4 bs=1G count=20
mkfs.ext4 rootfs.ext4
mkdir ./tmp
sudo mount rootfs.ext4 ./tmp
sudo cp -rp ./temp-rootfs/* ./tmp/
sudo umount ./tmp

# create rootfs_guest.ext4
dd if=/dev/zero of=rootfs_guest.ext4 bs=1G count=4
mkfs.ext4 rootfs_guest.ext4
mkdir ./tmp
sudo mount rootfs_guest.ext4 ./tmp
sudo cp -rp ./temp-rootfs/* ./tmp/
sudo umount ./tmp

export ROOTFS=$WS/rootfs
```

## 1.4 qemu boot host-riscv64

```sh
$QEMU/qemu-system-riscv64 \
    -M virt \
    -cpu rv64 \
    -m 2048 -nographic \
    -smp 8 \
    -kernel $LINUX/Image \
    -append "root=/dev/vda rw console=ttyS0 loglevel=3 earlycon=sbi" \
    -drive file=$ROOTFS/rootfs.ext4,format=raw,id=hd0,cache=writeback \
    -device virtio-blk-pci,drive=hd0 \
    -netdev user,id=usernet,hostfwd=tcp:127.0.0.1:7722-0.0.0.0:22 \
    -device virtio-net-pci,netdev=usernet \
    -rtc clock=host,base=utc
```

# 2 kvm-guest 

## 2.1 prepare kvm env

```shell
# enter host-riscv64
mkdir repo && cd ./repo

# back to x86 host
cd $WS && mkdir apps
cp -f $LINUX/Image ./apps
cp -f $KVM/kvm.ko ./apps
cp -f $ROOTFS/rootfs_guest.ext4 ./apps
scp -P 7722 -r ./apps root@127.0.0.1:/root/repo

insmod ./apps/kvm.ko
```

## 2.2 qemu boot kvm-riscv-guest

```shell
export WS=`pwd`

# some dependencies
sudo apt install git gcc g++ wget flex bison bc cpio make pkg-config libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev libncurses-dev libssl-dev ninja-build python3-venv libslirp-dev

# qemu build
git clone --depth=1 -b ctr_upstream --recurse-submodules -j8 https://github.com/rajnesh-kanwal/qemu.git
cd ./qemu
mkdir build && cd ./build

../configure --enable-kvm --enable-slirp --enable-plugins --enable-virtfs --enable-debug --enable-vnc --enable-werror --enable-vhost-net --target-list="riscv64-softmmu" 

make -j8
cd ../roms/
make opensbi64-generic

qemu-system-riscv64 --version
```

```shell
export QEMU=$WS/qemu/build
export LINUX=$WS/apps
export ROOTFS=$WS/apps

$QEMU/qemu-system-riscv64 \
    -M virt \
    -cpu rv64 --enable-kvm \
    -m 2048 -nographic \
    -smp 8 \
    -kernel $LINUX/Image \
    -append "root=/dev/vda rw console=ttyS0 loglevel=3 earlycon=sbi" \
    -drive file=$ROOTFS/rootfs_guest.ext4,format=raw,id=hd0,cache=writeback \
    -device virtio-blk-pci,drive=hd0 \
    -netdev user,id=usernet,hostfwd=tcp:127.0.0.1:7722-0.0.0.0:22 \
    -device virtio-net-pci,netdev=usernet \
    -rtc clock=host,base=utc
```







