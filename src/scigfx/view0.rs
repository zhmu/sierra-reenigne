use byteorder::{LittleEndian, ReadBytesExt};
use std::io::{Cursor, Seek, SeekFrom};
use anyhow::Result;

pub struct Image {
    pub width: u16,
    pub height: u16,
    pub x_place_mod: u16,
    pub y_place_mod: u16,
    pub color_key: u8,
    pub visual: Vec<u8>,
}

pub struct Group {
    pub images: Vec<Image>,
}

pub struct View0 {
    pub groups: Vec<Group>,
}

impl View0 {
    pub fn new(data: &[u8]) -> Result<Self> {
        let mut rdr = Cursor::new(&data);
        let num_image_groups = rdr.read_u16::<LittleEndian>()?;
        let _mirrored_flags = rdr.read_u16::<LittleEndian>()?;
        rdr.seek(SeekFrom::Current(4))?; // skip
        let mut cell_list_indices = vec![ 0u16; num_image_groups as usize ];
        for n in 0..(num_image_groups as usize) {
            cell_list_indices[n] = rdr.read_u16::<LittleEndian>()?;
        }

        let mut groups = Vec::new();
        for n in 0..num_image_groups {
            let mut group = Group{ images: Vec::new() };

            let offset = cell_list_indices[n as usize];
            rdr.seek(SeekFrom::Start(offset.into()))?;

            let num_image_cells = rdr.read_u16::<LittleEndian>()?;
            rdr.seek(SeekFrom::Current(2))?; // skip
            let mut image_cell_indices = vec![ 0u16; num_image_cells as usize ];

            for n in 0..(num_image_cells as usize) {
                image_cell_indices[n] = rdr.read_u16::<LittleEndian>()?;
            }

            for m in 0..num_image_cells {
                let offset = image_cell_indices[m as usize];
                rdr.seek(SeekFrom::Start(offset.into()))?;

                let width = rdr.read_u16::<LittleEndian>()?;
                let height = rdr.read_u16::<LittleEndian>()?;
                let x_place_mod = rdr.read_u8()? as u16;
                let y_place_mod = rdr.read_u8()? as u16;
                let color_key = rdr.read_u8()?; // transparency value

                let mut image = Image{ width, height, x_place_mod, y_place_mod, color_key, visual: vec![ 0u8; (width * height) as usize ] };

                let mut x: u16 = 0;
                let mut y: u16 = 0;
                while y < height {
                    let byte = rdr.read_u8()?;
                    let color = byte & 0xf;
                    let repeat = byte >> 4;
                    for _ in 0..repeat {
                        image.visual[(y * width + x) as usize] = color;
                        x += 1;
                        if x >= width {
                            x = 0;
                            y += 1;
                        }
                    }
                }
                group.images.push(image);
            }
            groups.push(group);
        }
        Ok(Self{ groups })
    }
}
