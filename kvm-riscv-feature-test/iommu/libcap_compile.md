# cross compile libcap

    git clone https://git.kernel.org/pub/scm/libs/libcap/libcap.git
    cd libcap
    vim libcap/Makefile


        _makenames: _makenames.c cap_names.list.h
        ifeq ($(CROSS_COMPILE), )
                $(BUILD_CC) $(BUILD_CFLAGS) $(BUILD_CPPFLAGS) $< -o $@
        else
                gcc $(BUILD_CFLAGS) $(BUILD_CPPFLAGS) $< -o $@
        endif

    make CROSS_COMPILE=riscv64-linux-gnu- prefix=/opt/libcap/riscv64-linux-gnu-
     
    cp libcap/libcap.so /usr/riscv64-linux-gnu/lib/
    cp libcap/libcap.a /usr/riscv64-linux-gnu/lib/

 

