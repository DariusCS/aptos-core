// Copyright © Aptos Foundation

fn main() {
    println!("cargo:rerun-if-changed=../doc/.version");
    println!("cargo:rerun-if-changed=../move_scripts/build/Minter/bytecode_scripts/main.mv");
}
