# Graphics tools

## Drawing

This is a tool to extract all SCI0/SCI1 resources to a given directory.

Usage: `cargo run --bin [tool] [path to resource]`

The following tools are available:

* `draw-font`: Renders SCI0 font resources to the supplied output file
* `draw-pic0`: Renders SCI0 picture resources to `visual.bmp`, `priority.bmp` and `control.bmp`.
* `draw-pic1`: Renders SCI1 picture resources to `visual.bmp`, `priority.bmp` and `control.bmp`.
* `draw-view0`: Renders SCI0 view resources to `view_NNN_MMM.bmp`.
* `draw-view1`: Renders SCI0 view resources to `NNN_MMM.bmp`.

### Building

Execute `cargo build`. You need to have the [Rust](https://www.rust-lang.org/) toolchain installed.
