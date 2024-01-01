# SCI0 disassembler

This is a tool to parse a SCI0 `script.nnn` file and display the contents. Script code is disassembled, and structures are decoded.

Usage: `cargo run --bin disassemble0 [data_directory] script_nr`

`[data_directory]` should contain the extracted game resources. `script_nr` is the number of the script to decode. For example, `0` will process `script.000`.

### Building

Execute `cargo build`. You need to have the [Rust](https://www.rust-lang.org/) toolchain installed.
