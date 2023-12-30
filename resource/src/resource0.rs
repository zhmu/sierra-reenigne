use byteorder::{ReadBytesExt, LittleEndian};

use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::path::Path;
use std::io::{Read,Seek,SeekFrom,Cursor};
use anyhow::{Result, Context};

use crate::resource;

const RESOURCE_MAP: &str = "resource.map";

#[derive(Clone)]
struct ResourceEntryV0 {
    r_type: u8,
    r_number: u16,
    r_volnr: u8,
    r_offset: u64
}

struct ResourceHeaderV0 {
    id: u16,
    comp_size: u16,
    decomp_size: u16,
    comp_method: u16
}

impl ResourceHeaderV0 {
    fn parse<T: Read>(mut rdr: T) -> Result<ResourceHeaderV0> {
        let id = rdr.read_u16::<LittleEndian>()?;
        let comp_size = rdr.read_u16::<LittleEndian>()?;
        let decomp_size = rdr.read_u16::<LittleEndian>()?;
        let comp_method = rdr.read_u16::<LittleEndian>()?;
        Ok(ResourceHeaderV0{ id, comp_size, decomp_size, comp_method })
    }
}

pub struct ResourceMapV0 {
    map: HashMap<resource::ResourceID, ResourceEntryV0>,
    files: HashMap<u8, std::fs::File>
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
            r_type: (type_number >> 11) as u8,
            r_number: type_number & 0x7ff,
            r_volnr: (position >> 26) as u8,
            r_offset: (position & 0x3ffffff) as u64
        };
        entries.push(entry);
    }
    Ok(entries)
}

impl ResourceMapV0 {
    pub fn new(path: &Path) -> Result<ResourceMapV0> {
        let resource_map_data = std::fs::read(path.join(RESOURCE_MAP))?;
        let entries = parse_resource_map_v0(&resource_map_data)?;

        let mut map: HashMap<resource::ResourceID, ResourceEntryV0> = HashMap::new();
        let mut volumes: HashSet<u8> = HashSet::new();
        for entry in &entries {
            let r_type = entry.r_type & 0x7f;
            let rtype = resource::ResourceType::new(r_type);
            let rid = resource::ResourceID{ num: entry.r_number, rtype };
            map.insert(rid, entry.clone());
            volumes.insert(entry.r_volnr);
        }

        let mut files: HashMap<u8, std::fs::File> = HashMap::new();
        for volnr in &volumes {
            let resource_file = path.join(format!("resource.{:03}", volnr));
            let res_file = File::open(&resource_file)?;
            files.insert(*volnr, res_file);
        }
        Ok(ResourceMapV0{ map, files })
    }
}

impl resource::ResourceMap for ResourceMapV0 {
    fn read_resource(&self, rid: &resource::ResourceID) -> Result<resource::ResourceData> {
        let entry = self.map.get(rid).context("resource not found")?;
        let mut res_file = &self.files[&entry.r_volnr];

        res_file.seek(SeekFrom::Start(entry.r_offset))?;
        let rh = ResourceHeaderV0::parse(res_file)?;
        let comp_size = rh.comp_size - 4;

        let mut data: Vec<u8> = vec![ 0u8; comp_size as usize ];
        res_file.read(&mut data)?;

        let info = resource::ResourceInfo{
            compressed_size: comp_size,
            uncompressed_size: rh.decomp_size,
            compression_method: resource::CompressionMethod::new(rh.comp_method),
        };
        Ok(resource::ResourceData{ info, data })
    }

    fn get_entries(&self) -> Vec<&resource::ResourceID> {
        self.map.keys().collect()
    }
}
