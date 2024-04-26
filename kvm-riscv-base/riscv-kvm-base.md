# 0 前言

> 本文介绍了两种验证 kvm-riscv 功能、性能的环境搭建方式：
>
> * 如果想获取足够的调试信息，但配置过程会复杂一些，同时确保你的主机性能，参考：[1 嵌套qemu搭建kvm-riscv验证环境](#1 嵌套qemu搭建kvm-riscv验证环境)
> * 如果只是做功能验证，并不想追踪guest的详细执行情况，社区采用这种方式更多，参考：[2 qemu+kvmtool引导riscv-kvm-guest](2 qemu+kvmtool引导riscv-kvm-guest)

# 1 嵌套qemu搭建kvm-riscv验证环境

## 1.1 准备riscv-tool-chain

有些不必要的模块，建议移除以提高clone/build速度：

```sh
git clone https://github.com/riscv/riscv-gnu-toolchain
sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev
git rm qemu
git submodule update --init --recursive
./configure --prefix=/opt/riscv --with-arch=rv64gc --with-abi=lp64d
sudo make linux -j $(nproc)

#./configure --prefix=/opt/riscv --with-arch=rv64imafdc_zicsr_zifencei --with-abi=lp64d
make -j $(nproc)

# Add the path of compiler to your PATH
export PATH=/opt/riscv/bin/:$PATH

# Validate the compiler
riscv64-unknown-linux-gnu-gcc -v
```

## 1.2 运行kvm-riscv-guest

### step1: 构建host/guest linux

Linux版本与config可自行调整，如需使用I/O则开启 `CONFIG_VIRTIO` 相关选项：

```shell
git clone https://github.com/kvm-riscv/linux.git
export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
mkdir build-guest
make -C linux O=`pwd`/build-riscv64 defconfig
make -C linux O=`pwd`/build-riscv64 -j`nproc`
```

### step2: 构建第一层qemu模拟riscv-h

```shell
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git submodule init
git submodule update --recursive
export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu- 
./configure --target-list="riscv32-softmmu riscv64-softmmu"
make
cd ..
```

### step3: 构建第二层qemu来启动kvm-guest

因为qemu编译需要依赖很多动态库，想得到一个riscv64版本的qemu需要先交叉编译qemu依赖的动态库，然后再交叉编译qemu，太麻烦了。这里用编译buildroot的方式一同编译小文件系统里的qemu, buildroot编译qemu的时候就会一同编译qemu依赖的各种库, 这样编译出的host文件系统里就带了qemu。

#### 下载buildroot工具

```shell
git clone https://github.com/buildroot/buildroot.git
cd buildroot
make menuconfig
```

#### 选择riscv架构

> **Target options  --->  Target Architecture （i386）--->  (x) RISCV**

![img](https://cdn.nlark.com/yuque/0/2023/png/38811017/1693545081802-a8336959-3c4d-46c9-9485-ac9367b93650.png)

#### 选择ext文件系统

> **Filesystem images ---> [*] ext2/3/4 root filesystem**

![img](https://cdn.nlark.com/yuque/0/2023/png/38811017/1693545241748-98ded40b-c1e5-446f-bb30-75d96085ee02.png)

下方的exact size可以调整ext文件系统大小配置，默认为60M，这里需要调整到500M以上，因为需要编译qemu文件进去。

#### buildroot配置qemu

```shell
BR2_TOOLCHAIN_BUILDROOT_GLIBC=y/
BR2_USE_WCHAR=y
BR2_PACKAGE_QEMU=y/
BR2_TARGET_ROOTFS_CPIO=y
BR2_TARGET_ROOTFS_CPIO_GZIP=y

 Prompt: gzip                                                                                                                                 │  
  │   Location:                                                                                                                                  │  
  │     -> Filesystem images                                                                                                                     │  
  │       -> cpio the root filesystem (for use as an initial RAM filesystem) (BR2_TARGET_ROOTFS_CPIO [=y])                                       │  
  │ (1)     -> Compression method (<choice> [=y])  
```

在可视化页面按 `/` 即可进入搜索模式，在搜索模式分别输入上述参数：

<img src="https://cdn.nlark.com/yuque/0/2023/png/38811108/1695365777988-0ddae6e1-cc5a-40b0-841a-6caf5bc69529.png" alt="img" style="zoom: 33%;" />

<img src="https://cdn.nlark.com/yuque/0/2023/png/38811108/1695365865223-acf0d8f9-25ee-4451-9549-090eaa7de25f.png" alt="img" style="zoom: 33%;" />

#### 全部开启后保存退出 -> 编译

`make -j$(nproc)` 编译，完成后在 `output/images` 目录下得到rootfs.ext2，将它复制到工作目录。

两层qemu的版本需保持一致，因为不同版本的qemu模拟的riscv平台 `priv-spec` 可能不同。

#### host-kvm启动第二层qemu

第二层qemu运行的内核就使用第一层qemu对应的内核即可。随后，从主机运行脚本：

`strat_qemu_1.sh`

```sh
#!/bin/bash

./qemu/build/qemu-system-riscv64 \
    -M virt \
    -cpu 'rv64,h=true' \
    -m 2G \
    -kernel Image \
    -append "rootwait root=/dev/vda ro" \
    -drive file=rootfs.ext2,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -nographic \
    -virtfs local,path=/home/wx/Documents/shared,mount_tag=host0,security_model=passthrough,id=host0 \
    -netdev user,id=net0 -device virtio-net-device,netdev=net0
```

### step4: 运行riscv-host

随后，从主机运行脚本：

```sh
#!/bin/bash

./qemu/build/qemu-system-riscv64 \
    -M virt \
    -cpu rv64 \
    -m 2G \
    kernel ./build-riscv64/arch/riscv/boot/Image \
    -append "rootwait root=/dev/vda ro" \
    -drive file=rootfs.ext2,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -nographic \
    -virtfs local,path=/home/wx/Documents/shared,mount_tag=host0,security_model=passthrough,id=host0 \
    -netdev user,id=net0 -device virtio-net-device,netdev=net0
```

### step5: 运行riscv-guest

在 riscv-host 上，运行 `start_qemu_2.sh`：

```sh
#!/bin/sh

/usr/bin/qemu-system-riscv64 \
    -M virt --enable-kvm \
    -cpu rv64 \
    -m 256m  \
    -kernel ./Image \
    -append "rootwait root=/dev/vda ro" \
    -drive file=rootfs.ext2,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -nographic 
```

# 2 qemu+kvmtool引导riscv-kvm-guest

第1部分的第二层qemu构建过程可能会遇到不少问题，且真正运行的时候速度也比较慢，还有一种使用kvmtool的更轻量级的方法。

整体上看，验证kvm功能更建议用这种方式。

## 2.1 其他组件构建

```sh
# Build Qemu
sudo apt install libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev -y
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git submodule update --init --recursive
./configure --target-list="riscv32-softmmu riscv64-softmmu"
make -j $(nproc)
cd -

# Build linux kernel for host and guest
sudo apt install libelf-dev
sudo apt install libssl-dev

export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
git clone https://github.com/kvm-riscv/linux.git
mkdir riscv-linux
make -C linux O=`pwd`/riscv-linux defconfig
make -C linux O=`pwd`/riscv-linux -j $(nproc)

# Build OpenSBI
export ARCH=riscv
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
git clone https://github.com/riscv-software-src/opensbi.git
cd opensbi
make PLATFORM=generic -j $(nproc)
cd -
```

## 2.2 构建kvmtool

编译 libfdt 库，将其添加到工具链所在位置的 `sysroot` 文件夹中：

```sh
# install cross-compiled libfdt library at $SYSROOT/usr/lib64/lp64d directory of cross-compile toolchain
git clone git://git.kernel.org/pub/scm/utils/dtc/dtc.git
cd dtc
export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
export CC="${CROSS_COMPILE}gcc -mabi=lp64d -march=rv64gc" # riscv toolchain should be configured with --enable-multilib to support the most common -march/-mabi options if you build it from source code
TRIPLET=$($CC -dumpmachine)
SYSROOT=$($CC -print-sysroot)
make libfdt  -j`nproc`
make NO_PYTHON=1 NO_YAML=1 DESTDIR=$SYSROOT PREFIX=/usr LIBDIR=/usr/lib64/lp64d install-lib install-includes  -j`nproc`
cd ..
```

编译 kvmtool：

```sh
git clone https://git.kernel.org/pub/scm/linux/kernel/git/will/kvmtool.git
cd kvmtool
export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
make lkvm-static  -j`nproc`
${CROSS_COMPILE}strip lkvm-static
cd ..
```

## 2.3 构建rootfs

```sh
export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
git clone https://github.com/kvm-riscv/howto.git
wget https://busybox.net/downloads/busybox-1.33.1.tar.bz2
tar -C . -xvf ./busybox-1.33.1.tar.bz2
mv ./busybox-1.33.1 ./busybox-1.33.1-kvm-riscv64
cp -f ./howto/configs/busybox-1.33.1_defconfig busybox-1.33.1-kvm-riscv64/.config
make -C busybox-1.33.1-kvm-riscv64 oldconfig
make -C busybox-1.33.1-kvm-riscv64 install
mkdir -p busybox-1.33.1-kvm-riscv64/_install/etc/init.d
mkdir -p busybox-1.33.1-kvm-riscv64/_install/dev
mkdir -p busybox-1.33.1-kvm-riscv64/_install/proc
mkdir -p busybox-1.33.1-kvm-riscv64/_install/sys
mkdir -p busybox-1.33.1-kvm-riscv64/_install/apps
ln -sf /sbin/init busybox-1.33.1-kvm-riscv64/_install/init
cp -f ./howto/configs/busybox/fstab busybox-1.33.1-kvm-riscv64/_install/etc/fstab
cp -f ./howto/configs/busybox/rcS busybox-1.33.1-kvm-riscv64/_install/etc/init.d/rcS
cp -f ./howto/configs/busybox/motd busybox-1.33.1-kvm-riscv64/_install/etc/motd
cp -f ./kvmtool/lkvm-static busybox-1.33.1-kvm-riscv64/_install/apps
cp -f ./build-riscv64/arch/riscv/boot/Image busybox-1.33.1-kvm-riscv64/_install/apps
cp -f ./build-riscv64/arch/riscv/kvm/kvm.ko busybox-1.33.1-kvm-riscv64/_install/apps
cd busybox-1.33.1-kvm-riscv64/_install; find ./ | cpio -o -H newc > ../../rootfs_kvm_riscv64.img; cd -
```

## 2.4 启动riscv-kvm-guest

### 启动Host Linux

qemu模拟RISC-V平台并启动Host Linux：

```sh
./qemu/build/qemu-system-riscv64 -cpu rv64 -M virt -m 512M -nographic \
  -bios opensbi/build/platform/generic/firmware/fw_jump.bin \
  -kernel ./build-riscv64/arch/riscv/boot/Image \
  -initrd ./rootfs_kvm_riscv64.img
  -append "root=/dev/ram rw console=ttyS0 earlycon=sbi"
```

注意，在上一步中，如果 initrd 未使用 RISC-V 工具链编译，可能会出现如下问题：

```sh
[ 0.629637] ---[ end Kernel panic - not syncing: No working init found. Try passing init= option to kernel. See Linux Documentation/admin-guide/init.rst for guidance. ]---
```

### 启动Guest Linux

在上一步打开的Host Linux仿真环境中执行以下步骤：

* 首先，加入KVM内核模块：

  ```sh
  insmod apps/kvm.ko
  ```

* 接着 kvmtool 运行 Guest Linux：

  ```sh
  ./apps/lkvm-static run -m 128 -c2 --console serial -p "console=ttyS0 earlycon=uart8250,mmio,0x3f8" -k ./apps/Image --debug
  ```









