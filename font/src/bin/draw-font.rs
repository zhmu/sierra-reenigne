use std::env;
use scifont::font;
use bmp::{Image, Pixel, px};
use anyhow::Result;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        panic!("usage: {} data/font.nnn out.bmp", args[0]);
    }
    let font_path = &args[1];
    let bmp_path = &args[2];
    let font_data = std::fs::read(font_path)?;

    let font = font::Font::new(&font_data)?;

    let width: u32 = 256;
    let height: u32 = 128;
    let mut img = Image::new(width, height);
    let mut base_x: u32 = 0;
    let mut base_y: u32 = 0;
    for ch in 0..(font.get_number_of_chars() as u8) {
        let char_width = font.get_char_width(ch.into()) as u32;
        if base_x + char_width >= width {
            base_x = 0;
            base_y += font.get_height() as u32;
        }
        font.render(ch, &mut |x, y| {
            img.set_pixel(base_x + x as u32, base_y + y as u32, px!(255, 0, 0));
        });
        base_x += char_width;
    }

    img.save(bmp_path)?;
    Ok(())
}
