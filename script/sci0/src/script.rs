use std::io::{Cursor, Seek, SeekFrom};
use anyhow::{anyhow, Result};
use byteorder::{LittleEndian, ReadBytesExt};
use std::str;

use crate::{disassemble, opcode};

#[derive(PartialEq,Debug)]
pub enum BlockType {
    Terminator,
    Object,
    Code,
    Synonyms,
    Said,
    Strings,
    Class,
    Exports,
    Pointers,
    PreloadText,
    LocalVars,
    Unknown(u16)
}

impl BlockType {
    fn from(v: u16) -> BlockType {
        match v {
            0 => BlockType::Terminator,
            1 => BlockType::Object,
            2 => BlockType::Code,
            3 => BlockType::Synonyms,
            4 => BlockType::Said,
            5 => BlockType::Strings,
            6 => BlockType::Class,
            7 => BlockType::Exports,
            8 => BlockType::Pointers,
            9 => BlockType::PreloadText,
            10 => BlockType::LocalVars,
            _ => BlockType::Unknown(v),
        }
    }
}

pub struct ScriptBlock<'a> {
    pub r#type: BlockType,
    pub base: usize,
    pub data: &'a [u8]
}

pub struct Script<'a> {
    pub id: i16,
    pub blocks: Vec<ScriptBlock<'a>>
}

impl<'a> Script<'a> {
    pub fn new(id: i16, input: &'a [u8]) -> Result<Script<'a>> {
        let mut rdr = Cursor::new(&input);

        let mut blocks: Vec<ScriptBlock> = Vec::new();
        while (rdr.position() as usize) < input.len() {
            let block_type = rdr.read_u16::<LittleEndian>()?;
            let block_type = BlockType::from(block_type);
            if block_type == BlockType::Terminator {
                break;
            }

            let mut block_size = rdr.read_u16::<LittleEndian>()? as usize;
            if block_size < 4 {
                return Err(anyhow!("block size too small"));
            }
            block_size -= 4;

            let base = rdr.position() as usize;
            if base + block_size > input.len() {
                println!("warning: block type {:?} with size {} too large, truncating to {}", block_type, block_size, input.len() - base);
                block_size = input.len() - base
            }
            let block_data = &input[base..base + block_size];

            // If this is an object or class, look for the magic identifier. If
            // it doesn't match, reject the script
            if block_type == BlockType::Object || block_type == BlockType::Class {
                if block_size < 8 { return Err(anyhow!("block too small to be a class/object block")); }
                let magic = rdr.read_u16::<LittleEndian>()?;
                if magic != 0x1234 {
                    return Err(anyhow!("corrupt object/classs block (invalid magic)"));
                }
                rdr.seek(SeekFrom::Current(block_size as i64 - 2))?;
            } else {
                rdr.seek(SeekFrom::Current(block_size as i64))?;
            }

            blocks.push(ScriptBlock{ r#type: block_type, base, data: block_data });
        }

        Ok(Script{ id, blocks })
    }

    pub fn get_string(&self, address: usize) -> Option<&str> {
        for block in &self.blocks {
            if block.r#type == BlockType::Strings {
                if address >= block.base && address < block.base + block.data.len() {
                    let data = get_string(&block.data[address - block.base..]);
                    return Some(data);
                }
            }
        }
        None
    }
}

pub fn get_string(data: &[u8]) -> &str {
    let nul_byte_end = data.iter()
        .position(|&c| c == b'\0')
        .unwrap_or(data.len());
    str::from_utf8(&data[0..nul_byte_end]).unwrap_or("<corrupt>")
}

// Note: always uses the first argument
pub fn relpos0_to_absolute_offset(ins: &disassemble::Instruction) -> u16
{
    let a_type = &ins.opcode.arg[0];
    let a_value: usize = ins.args[0].into();
    let offset: usize = ins.offset as usize + ins.bytes.len();
    match a_type {
        opcode::Arg::RelPos8 => {
            if (a_value & 0x80) != 0 {
                panic!("implement signed bits here");
            }
            let j_offset: usize = offset + a_value;
            j_offset as u16
        }
        opcode::Arg::RelPos16 => {
            let j_offset = (offset + a_value) & 0xffff;
            j_offset as u16
        }
        _ => { panic!("only to be called with relative positions"); }
    }
}
