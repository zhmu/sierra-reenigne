use bmp::{Image, Pixel, px};
use anyhow::Result;

pub fn render_bitmap(fname: &str, width: u32, height: u32, bits: &[u8], palette: &[ u8; 768 ]) -> Result<()> {
    let mut img = Image::new(width, height);
    for (x, y) in img.coordinates() {
        let v = bits[(width * y + x) as usize] as usize;
        let r = palette[v * 3 + 0];
        let g = palette[v * 3 + 1];
        let b = palette[v * 3 + 2];
        img.set_pixel(x, y, px!(r, g, b));
    }
    img.save(fname)?;
    Ok(())
}

