use packed_struct::prelude::*;
use anyhow::{anyhow, Result};

#[derive(PackedStruct)]
#[packed_struct(endian="lsb")]
pub struct FontHeader {
    pub low_char: u16,
    pub high_char: u16,
    pub point_size: u16,
}

pub struct Glyph {
    height: u8,
    width: u8,
    offset: usize,
}

impl Glyph {
    fn render(&self, data: &[u8], plot: &mut dyn FnMut(u16, u16)) {
        let mut index = self.offset;
        for m in 0..self.height {
            let mut byte = data[index]; index += 1;
            let mut n: u16 = 0;
            let mut bl: u8 = 0;
            loop {
                //let dim_mask = 0xffu8; // style & 1 == 0, penY & 1 == 0
                let carry = (byte & 0x80) != 0;
                byte = byte << 1;
                if carry {
                    plot(n, m as u16);
                }
                bl += 1;
                n += 1;
                if bl == self.width { break; }
                if (bl & 7) == 0 {
                    byte = data[index];
                    index += 1;
                }
            }
        }
    }
}

pub struct Font {
    point_size: u16,
    glyphs: Vec<Glyph>,
    data: Vec<u8>,
}

impl Font {
    pub fn new(data: &[u8]) -> Result<Self> {
        let header = FontHeader::unpack_from_slice(&data[0..6]).unwrap();
        // SCI does not properly account for non-zero first chars
        if header.low_char != 0 { return Err(anyhow!("first char must be zero, but isn't")); }

        let point_size = header.point_size;
        let data = data.to_vec();
        let mut glyphs = Vec::new();
        for n in header.low_char..header.high_char {
            let offset: usize = (6 + n as u16 * 2).into();
            let mut offset: usize = (data[offset + 0] as u16 + (data[offset + 1] as u16) * 256).into();

            let width = data[offset]; offset += 1;
            let height = data[offset]; offset += 1;
            glyphs.push(Glyph{ height, width, offset });
        }
        Ok(Self{ point_size, glyphs, data })
    }

    pub fn get_height(&self) -> u16 {
        self.point_size
    }

    pub fn render(&self, ch: u8, plot: &mut dyn FnMut(u16, u16)) {
        let glyph = &self.glyphs[ch as usize];
        glyph.render(&self.data, plot);
    }

    pub fn get_number_of_chars(&self) -> usize {
        self.glyphs.len()
    }

    pub fn get_char_width(&self, ch: usize) -> u8 {
        self.glyphs[ch].width
    }
}
