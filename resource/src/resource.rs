use anyhow::{Result};
use std::fmt;
use std::fmt::Formatter;

#[derive(PartialEq,Eq,Hash,Clone,Copy,Debug)]
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

#[derive(Clone)]
pub enum CompressionMethod {
    None,
    LZW,
    Huffman,
    Explode,
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
            18 | 19 | 20 => { CompressionMethod::Explode },
            _ => { CompressionMethod::Unknown(value) }
        }
    }
}

#[derive(PartialEq,Eq,Hash,Clone,Copy,Debug)]
pub struct ResourceID {
    pub rtype: ResourceType,
    pub num: u16,
}

#[derive(Clone)]
pub struct ResourceInfo {
    pub compressed_size: u16,
    pub uncompressed_size: u16,
    pub compression_method: CompressionMethod
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
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            CompressionMethod::None => { write!(f, "none") },
            CompressionMethod::LZW => { write!(f, "lzw") },
            CompressionMethod::Huffman => { write!(f, "huffman") },
            CompressionMethod::Explode => { write!(f, "explode") },
            CompressionMethod::Unknown(v) => { write!(f, "unk{}", v) }
        }
    }
}

pub trait ResourceMap {
    fn read_resource(&self, rid: &ResourceID) -> Result<ResourceData>;
    fn get_entries(&self) -> Vec<&ResourceID>;
}
