extern crate scigfx;

use std::env;
use scigfx::{palette, util, view1};
use anyhow::Result;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        panic!("usage: {} path/view.nnn", args[0]);
    }
    let view_path = &args[1];
    let view_data = std::fs::read(view_path)?;
    let mut vga_palette = [ 0u8; 768 ];
    palette::fill_ega_colours(&mut vga_palette);

    let view = view1::View1::new(&view_data)?;
    for (lop_index, lop) in view.loops.iter().enumerate() {
        for (cel_index, cel) in lop.cels.iter().enumerate() {
            let fname = format!("{}_{}.bmp", lop_index, cel_index);
            util::render_bitmap(&fname, cel.width.into(), cel.height.into(), &cel.visual, &vga_palette)?;
        }
    }
    Ok(())
}
