use std::fmt;
use std::fmt::Formatter;
use std::io::{Read, Seek, SeekFrom};

use anyhow::{Result, Context};
use std::collections::HashMap;

#[derive(PartialEq,Eq,Hash,Clone,Copy)]
pub enum ResourceType {
    View,
    Picture,
    Script,
    Text,
    Sound,
    Memory,
    Vocab,
    Font,
    Cursor,
    Patch,
    Bitmap,
    Palette,
    Wave,
    Audio,
    Sync,
    Msg,
    Map,
    Heap,
    Audio36,
    Sync36,
    Xlate,
    Unknown(u8)
}

#[derive(Clone,Copy,PartialEq)]
pub enum CompressionMethod {
    None,
    LZW,
    LZW1,
    LZW1View,
    LZW1Pic,
    Huffman,
    Implode,
    Unknown(u16)
}

impl ResourceType {
    pub fn new(value: u8) -> ResourceType {
        match value {
            0 => { ResourceType::View },
            1 => { ResourceType::Picture },
            2 => { ResourceType::Script },
            3 => { ResourceType::Text },
            4 => { ResourceType::Sound },
            5 => { ResourceType::Memory },
            6 => { ResourceType::Vocab },
            7 => { ResourceType::Font },
            8 => { ResourceType::Cursor },
            9 => { ResourceType::Patch },
            10 => { ResourceType::Bitmap },
            11 => { ResourceType::Palette },
            12 => { ResourceType::Wave },
            13 => { ResourceType::Audio },
            14 => { ResourceType::Sync },
            15 => { ResourceType::Msg },
            16 => { ResourceType::Map },
            17 => { ResourceType::Heap },
            18 => { ResourceType::Audio36 },
            19 => { ResourceType::Sync36 },
            20 => { ResourceType::Xlate },
            _ => { ResourceType::Unknown(value) }
        }
    }
}

impl CompressionMethod {
    pub fn new(value: u16) -> CompressionMethod {
        match value {
            0 => { CompressionMethod::None },
            1 => { CompressionMethod::LZW },
            2 => { CompressionMethod::Huffman},
            3 => { CompressionMethod::LZW1View },
            4 => { CompressionMethod::LZW1Pic },
            18 | 19 | 20 => { CompressionMethod::Implode },
            _ => { CompressionMethod::Unknown(value) }
        }
    }
}

#[derive(PartialEq,Eq,Hash,Clone,Copy)]
pub struct ResourceID {
    pub rtype: ResourceType,
    pub num: u16,
}

#[derive(Clone)]
pub struct ResourceInfo {
    pub compressed_size: u16,
    pub uncompressed_size: u16,
    pub compression_method: CompressionMethod,
    pub volume: u8,
    pub offset: u64,
}

pub struct ResourceData {
    pub info: ResourceInfo,
    pub data: Vec<u8>
}

impl fmt::Display for ResourceType {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            ResourceType::View => { write!(f, "view") },
            ResourceType::Picture => { write!(f, "pic") },
            ResourceType::Script => { write!(f, "script") },
            ResourceType::Text => { write!(f, "text") },
            ResourceType::Sound => { write!(f, "sound") },
            ResourceType::Memory => { write!(f, "memory") },
            ResourceType::Vocab => { write!(f, "vocab") },
            ResourceType::Font => { write!(f, "font") },
            ResourceType::Cursor => { write!(f, "cursor") },
            ResourceType::Patch => { write!(f, "patch") },
            ResourceType::Bitmap => { write!(f, "bitmap") },
            ResourceType::Palette => { write!(f, "palette") },
            ResourceType::Wave => { write!(f, "wave") },
            ResourceType::Audio => { write!(f, "audio") },
            ResourceType::Sync => { write!(f, "sync") },
            ResourceType::Msg => { write!(f, "msg") },
            ResourceType::Map => { write!(f, "map") },
            ResourceType::Heap => { write!(f, "heap") },
            ResourceType::Audio36 => { write!(f, "audio36") },
            ResourceType::Sync36 => { write!(f, "sync36") },
            ResourceType::Xlate => { write!(f, "xlate") },
            ResourceType::Unknown(v) => { write!(f, "unk{}", v) }
        }
    }
}

impl fmt::Display for CompressionMethod {
    fn fmt(&self, f: &mut Formatter) -> fmt::Result {
        match self {
            CompressionMethod::None => { write!(f, "none") },
            CompressionMethod::LZW => { write!(f, "lzw") },
            CompressionMethod::LZW1 => { write!(f, "lzw1") },
            CompressionMethod::LZW1View => { write!(f, "lzw1view") },
            CompressionMethod::LZW1Pic => { write!(f, "lzw1pic") },
            CompressionMethod::Huffman => { write!(f, "huffman") },
            CompressionMethod::Implode => { write!(f, "implode") },
            CompressionMethod::Unknown(v) => { write!(f, "unk{}", v) }
        }
    }
}

impl From<u16> for ResourceID {
    fn from(id: u16) -> Self {
        let rtype = ((id >> 11) & 0x7f) as u8;
        let rtype = ResourceType::new(rtype);
        let num = id & 0x7ff;
        ResourceID{ num, rtype }
    }
}

impl fmt::Display for ResourceID {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{}.{:03}", self.rtype, self.num)
    }
}

pub struct ResourceMap {
    map: HashMap<ResourceID, ResourceInfo>,
    volumes: HashMap<u8, std::fs::File>
}

impl ResourceMap {
    pub fn new(map: HashMap<ResourceID, ResourceInfo>, volumes: HashMap<u8, std::fs::File>) -> Self {
        ResourceMap{ map, volumes }
    }

    pub fn read_resource(&self, rid: &ResourceID) -> Result<ResourceData> {
        let entry = self.map.get(rid).context("resource not found")?;
        let mut res_file = &self.volumes[&entry.volume];

        res_file.seek(SeekFrom::Start(entry.offset))?;

        let mut data: Vec<u8> = vec![ 0u8; entry.compressed_size as usize ];
        res_file.read(&mut data)?;
        Ok(ResourceData{ info: entry.clone(), data })
    }

    pub fn get_entries(&self) -> Vec<&ResourceID> {
        self.map.keys().collect()
    }
}
