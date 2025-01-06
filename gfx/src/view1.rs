use packed_struct::prelude::*;
use crate::{cel};
use anyhow::Result;

#[derive(PackedStruct)]
#[packed_struct(endian="lsb")]
pub struct ViewHeader {
    pub header_size: u16, // excluding this field
    pub num_loops: u8,
    pub v_flags: u8,
    pub hisplit_flag: u8,
    pub dummy2: u8,
    pub cel_count: u16,
    pub palette_offset: u32,
    pub loop_header_size: u8,
    pub cel_header_size: u8,
    pub animation_offset: u32,
}

#[derive(PackedStruct)]
#[packed_struct(endian="lsb")]
pub struct LoopHeader {
    pub alt_loop: u8,
    pub flags: u8,
    pub num_cels: u8,
    pub dummy: u8,
    pub start_cel: u8,
    pub ending_cel: u8,
    pub repeat_count: u8,
    pub step_size: u8,
    pub palette_offset: u32,
    pub cel_offset: u32,
}

pub struct Loop {
    pub cels: Vec<cel::Cel>,
}

pub struct View1 {
    pub loops: Vec<Loop>,
}

impl View1 {
    pub fn new(data: &[u8]) -> Result<Self> {
        let view = ViewHeader::unpack_from_slice(&data[0..18]).unwrap();

        let mut loops = Vec::new();
        for n in 0..(view.num_loops as u16) {
            let loop_offset = ((n * view.loop_header_size as u16) + view.header_size + 2) as usize;
            let lop = LoopHeader::unpack_from_slice(&data[loop_offset..loop_offset+16]).unwrap();

            let mut cels = Vec::new();
            for m in 0..(lop.num_cels as u32) {
                let cel_offset = ((m * view.cel_header_size as u32) + lop.cel_offset) as usize;
                let mut cel = cel::Cel::new();
                cel.load(&data, cel_offset);

                cels.push(cel);
            }
            loops.push(Loop{ cels })
        }
        Ok(Self{ loops })
    }
}
