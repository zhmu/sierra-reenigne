use std::io::{Cursor, Seek, SeekFrom};
use anyhow::{anyhow, Result};
use byteorder::{LittleEndian, ReadBytesExt};
use std::str;

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

pub struct ScriptBlock {
    pub r#type: BlockType,
    pub base: usize,
    pub data: Vec<u8>
}

pub struct Script {
    pub id: u16,
    pub blocks: Vec<ScriptBlock>
}

impl Script {
    pub fn new(id: u16, input: &[u8]) -> Result<Script> {
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
                log::warn!("script.{:03}: block type {:?} with size {} too large, truncating to {}", id, block_type, block_size, input.len() - base);
                block_size = input.len() - base
            }
            let mut block_data = Vec::<u8>::with_capacity(block_size);
            block_data.extend_from_slice(&input[base..base + block_size]);

            // If this is an object or class, look for the magic identifier. If
            // it doesn't match, reject the script
            if block_type == BlockType::Object || block_type == BlockType::Class {
                if block_size < 8 { return Err(anyhow!("block too small to be a class/object block")); }
                let magic = rdr.read_u16::<LittleEndian>()?;
                if magic != 0x1234 {
                    return Err(anyhow!("corrupt object/class block (invalid magic)"));
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

pub fn load_sci0_script(extract_path: &str, script_id: u16) -> Result<Script> {
    let script_data = std::fs::read(format!("{}/script.{:03}", extract_path, script_id))?;
    Script::new(script_id, &script_data)
}

