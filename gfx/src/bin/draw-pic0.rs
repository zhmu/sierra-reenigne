extern crate scigfx;

use scigfx::{palette, picture, util};
use std::env;
use anyhow::Result;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        panic!("usage: {} path/pic.nnn", args[0]);
    }
    let pic_path = &args[1];
    let pic_data = std::fs::read(pic_path)?;
    let pic = picture::Picture::new_pic0(&pic_data)?;

    let mut palette = [ 0u8; 768 ];
    palette::fill_ega_colours(&mut palette);

    let width = picture::SCREEN_WIDTH as u32;
    let height = picture::SCREEN_HEIGHT as u32;
    util::render_bitmap("visual.bmp", width, height, &pic.visual, &palette)?;
    util::render_bitmap("priority.bmp", width, height, &pic.priority, &palette)?;
    util::render_bitmap("control.bmp", width, height, &pic.control, &palette)?;

    Ok(())
}
