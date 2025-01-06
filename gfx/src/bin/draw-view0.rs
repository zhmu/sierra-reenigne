extern crate scigfx;

use scigfx::{palette, util, view0};
use std::env;
use anyhow::Result;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        panic!("usage: {} path/view.nnn", args[0]);
    }
    let view_path = &args[1];
    let view_data = std::fs::read(view_path)?;

    let view = view0::View0::new(&view_data)?;
    let mut ega_palette = [ 0u8; 768 ];
    palette::fill_ega_colours(&mut ega_palette);

    for (g, group) in view.groups.iter().enumerate() {
        for (n, image) in group.images.iter().enumerate() {
            let fname = format!("view_{}_{}.bmp", g, n);
            util::render_bitmap(&fname, image.width as u32, image.height as u32, &image.visual, &ega_palette)?;
        }
    }

    Ok(())
}
