extern crate scigfx;

use scigfx::{palette, picture, util};
use std::env;
use anyhow::Result;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 && args.len() != 3 {
        panic!("usage: {} path/pic.num [path/palette.num]", args[0]);
    }
    let pic_path = &args[1];
    let pic_data = std::fs::read(pic_path)?;

    let mut palette = [ 0u8; 768 ];
    let mut got_palette = false;
    if args.len() > 2 {
        let pal_path = &args[2];
        let pal_data = std::fs::read(pal_path)?;

        palette::parse_vga_palette(&pal_data, &mut palette);
        got_palette = true;
    }

    let pic = picture::Picture::new_pic1(&pic_data, !got_palette, &mut palette)?;
    let width = picture::SCREEN_WIDTH as u32;
    let height = picture::SCREEN_HEIGHT as u32;
    util::render_bitmap("control.bmp", width, height, &pic.control, &palette)?;
    util::render_bitmap("priority.bmp", width, height, &pic.priority, &palette)?;
    util::render_bitmap("visual.bmp", width, height, &pic.visual, &palette)?;

    Ok(())
}
