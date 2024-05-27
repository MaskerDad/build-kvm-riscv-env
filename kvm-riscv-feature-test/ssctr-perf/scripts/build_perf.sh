#!/bin/bash

cd $LINUX/tools/perf
sudo -E PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/riscv64-linux-gnu/pkgconfig/" VF=1 make   EXTRA_CFLAGS="--sysroot=$SYSROOT"   ARCH=riscv  CROSS_COMPILE=riscv64-unknown-linux-gnu- NO_LIBBPF=1  prefix='$(SYSROOT)/usr' install
