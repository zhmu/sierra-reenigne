use byteorder::{ReadBytesExt, LittleEndian};

use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::fs::File;
use std::path::Path;
use std::io::{Read,Seek,SeekFrom,Cursor};
use anyhow::{anyhow, Result};

use crate::resource;

const RESOURCE_MAP: &str = "resource.map";

struct ResourceEntryV0 {
    r_id: resource::ResourceID,
    r_volnr: u8,
    r_offset: u64
}

struct ResourceHeaderV0 {
    id: resource::ResourceID,
    comp_size: u16,
    decomp_size: u16,
    comp_method: resource::CompressionMethod
}

impl ResourceHeaderV0 {
    fn parse<T: Read>(mut rdr: T) -> Result<ResourceHeaderV0> {
        let id = rdr.read_u16::<LittleEndian>()?;
        let comp_size = rdr.read_u16::<LittleEndian>()?;
        let decomp_size = rdr.read_u16::<LittleEndian>()?;
        let comp_method = rdr.read_u16::<LittleEndian>()?;

        let id = resource::ResourceID::from(id);
        let comp_size = comp_size - 4;
        let comp_method = resource::CompressionMethod::new(comp_method);
        Ok(ResourceHeaderV0{ id, comp_size, decomp_size, comp_method })
    }
}

fn parse_resource_map_v0(input: &[u8]) -> Result<Vec<ResourceEntryV0>> {
    let mut entries: Vec<ResourceEntryV0> = Vec::new();
    let mut rdr = Cursor::new(&input);
    while (rdr.position() as usize) < input.len() {
        // 6-byte entries: id (2 bytes), position (4 bytes)
        let type_number = rdr.read_u16::<LittleEndian>()?;
        let position = rdr.read_u32::<LittleEndian>()?;
        if type_number == 0xffff && position == 0xffffffff {
            break
        }

        let entry = ResourceEntryV0{
            r_id: resource::ResourceID::from(type_number),
            r_volnr: (position >> 26) as u8,
            r_offset: (position & 0x3ffffff) as u64
        };
        entries.push(entry);
    }
    Ok(entries)
}

fn guess_sci_version(entries: &mut HashMap<resource::ResourceID, resource::ResourceInfo>) {
    // Later versions of SCI0 changed the meaning of the compression methods:
    // Originally (SCI0):  1 = LZW, 2 = Huffman
    // Later:              1 = Huffman, 2 = LZW1

    // We use pic.* resources to detect this - they should be compressed using
    // Huffman (or not at all)
    let all_pic_sci0 = entries.iter()
        .filter(|&(k, _)| k.rtype == resource::ResourceType::Picture)
        .all(|(&_, &ref v)| match v.compression_method {
            resource::CompressionMethod::Huffman | resource::CompressionMethod::None => true,
            _ => false
        });
    if all_pic_sci0 {
        return;
    }

    // SCI01: Remap all compression types
    for (_key, resource) in entries.iter_mut() {
        resource.compression_method = match resource.compression_method {
            resource::CompressionMethod::Huffman => { resource::CompressionMethod::LZW1 },
            resource::CompressionMethod::LZW => { resource::CompressionMethod::Huffman },
            _ => { resource.compression_method }
        };
    }
}

pub fn parse_v0(path: &Path) -> Result<resource::ResourceMap> {
    let resource_map_data = std::fs::read(path.join(RESOURCE_MAP))?;
    let entries = parse_resource_map_v0(&resource_map_data)?;

    let mut map: HashMap<resource::ResourceID, resource::ResourceInfo> = HashMap::new();
    let mut volumes: HashMap<u8, std::fs::File> = HashMap::new();
    for entry in &entries {
        // Obtain/open matching resource.nnn file
        let res_file = match volumes.entry(entry.r_volnr) {
            Entry::Occupied(o) => o.into_mut(),
            Entry::Vacant(v) => {
                let resource_file = path.join(format!("resource.{:03}", entry.r_volnr));
                let res_file = File::open(&resource_file)?;
                v.insert(res_file)
            }
        };

        // Fetch resource header from resource.nnn file
        res_file.seek(SeekFrom::Start(entry.r_offset))?;
        let header = ResourceHeaderV0::parse(res_file)?;
        if header.id != entry.r_id {
            return Err(anyhow!("resource id mismatch: map has {}, resource.{:03} has {}", entry.r_id, entry.r_volnr, header.id));
        }
        map.insert(entry.r_id, resource::ResourceInfo{
            compressed_size: header.comp_size,
            uncompressed_size: header.decomp_size,
            compression_method: header.comp_method,
            volume: entry.r_volnr,
            offset: entry.r_offset + 8
        });
    }

    guess_sci_version(&mut map);
    Ok(resource::ResourceMap::new(map, volumes))
}

