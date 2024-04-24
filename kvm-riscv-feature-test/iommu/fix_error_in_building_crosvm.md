# fix error
## error:note: the `riscv64gc-unknown-linux-gnu` target may not be installed

    rustup target add riscv64gc-unknown-linux-gnu

## error: could not find system library 'libcap' required by the 'minijail-sys' crate

    sudo apt install  libcap-dev

## error: could not find -lcap: No such file or directory

how to fix please see [libcap cross compile](libcap_compile.md)

## error: thread 'main' panicked at 'protoc binary not found: cannot find binary path', /home/binbin/.cargo/registry/src/github.com-1ecc6299db9ec823/protoc-2.27.1/src/lib.rs:209:17

    sudo apt install protobuf-compiler

or

    wget https://github.com/protocolbuffers/protobuf/releases/download/v24.0/protoc-24.0-linux-x86_64.zip
    unzip protoc-24.0-linux-x86_64.zip -d protoc-24.0
    cp protoc-24.0/bin/protoc /usr/local/bin/