use byteorder::{ReadBytesExt, LittleEndian};

use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::fs::File;
use std::path::Path;
use std::io::{Read,Seek,SeekFrom,Cursor};
use anyhow::{anyhow, Result, Context};

use crate::resource;

const RESOURCE_MAP: &str = "resource.map";

#[derive(Clone)]
pub struct ResourceEntryV1 {
    pub r_id: resource::ResourceID,
    pub r_volnr: u8,
    pub r_offset: u64
}

struct ResourceInfoV1 {
    entry: ResourceEntryV1,
    header: ResourceHeaderV1,
}

pub struct ResourceDataV1 {
    pub header: ResourceHeaderV1,
    pub data: Vec<u8>
}

struct ResourceTypeOffsetV1 {
    rtype: resource::ResourceType,
    offset: u16
}

pub struct ResourceHeaderV1 {
    pub id: resource::ResourceID,
    pub compressed_length: u16,
    pub uncompressed_length: u16,
    pub comp_method: resource::CompressionMethod
}

impl ResourceHeaderV1 {
    fn parse<T: Read>(mut rdr: T) -> Result<ResourceHeaderV1> {
        let rtype = rdr.read_u8()?;
        let num = rdr.read_u16::<LittleEndian>()?;
        let compressed_length = rdr.read_u16::<LittleEndian>()?;
        let uncompressed_length = rdr.read_u16::<LittleEndian>()?;
        let comp_method = rdr.read_u16::<LittleEndian>()?;

        let rtype = resource::ResourceType::new(rtype & 0x7f);
        let comp_method = resource::CompressionMethod::new(comp_method);
        Ok(ResourceHeaderV1{ id: resource::ResourceID{ rtype, num }, compressed_length, uncompressed_length, comp_method })
    }
}

type ResourceDirectory = Vec<ResourceTypeOffsetV1>;

fn parse_resource_directory(input: &[u8]) -> Result<ResourceDirectory> {
    let mut res_types: ResourceDirectory = Vec::new();
    let mut rdr = Cursor::new(&input);
    loop {
        let rtype = rdr.read_u8()?;
        let rtype = resource::ResourceType::new(rtype & 0x7f);
        let offset = rdr.read_u16::<LittleEndian>()?;
        res_types.push(ResourceTypeOffsetV1{ rtype, offset });
        if rtype == resource::ResourceType::Unknown(0x7f) { break; }
    }
    Ok(res_types)
}

fn parse_map_1_5(rdirectory: &ResourceDirectory, input: &[u8]) -> Result<Vec<ResourceEntryV1>> {
    let mut entries: Vec<ResourceEntryV1> = Vec::new();
    for n in 0..rdirectory.len() - 1 {
        let rtype = rdirectory[n].rtype;
        let position = rdirectory[n].offset as usize;
        let position_end = rdirectory[n + 1].offset as usize;
        if position_end <= position { return Err(anyhow!("corrupt map: resource end is before start")); }
        let map_entry_data = &input[position..position_end];

        let mut rdr = Cursor::new(&map_entry_data);
        while (rdr.position() as usize) < map_entry_data.len() {
            // 5-byte entries: id (2 bytes), offset (3 bytes)
            let num = rdr.read_u16::<LittleEndian>()?;
            let woffset1 = rdr.read_u8()?;
            let woffset2 = rdr.read_u8()?;
            let woffset3 = rdr.read_u8()?;
            let offset = ((woffset1 as u32) << 1) + ((woffset2 as u32) << 9) + ((woffset3 as u32) << 17);

            let entry = ResourceEntryV1{
                r_id: resource::ResourceID{ rtype, num },
                r_volnr: 0,
                r_offset: offset as u64
            };
            entries.push(entry);
        }
    }
    Ok(entries)
}

fn parse_map_1_6(rdirectory: &ResourceDirectory, input: &[u8]) -> Result<Vec<ResourceEntryV1>> {
    let mut entries: Vec<ResourceEntryV1> = Vec::new();
    for n in 0..rdirectory.len() - 1 {
        println!(">> rtype {}", rdirectory[n].rtype);
        let rtype = rdirectory[n].rtype;
        let position = rdirectory[n].offset as usize;
        let position_end = rdirectory[n + 1].offset as usize;
        if position_end <= position { return Err(anyhow!("corrupt map: resource end is before start")); }
        let map_entry_data = &input[position..position_end];

        let mut rdr = Cursor::new(&map_entry_data);
        while (rdr.position() as usize) < map_entry_data.len() {
            // 6-byte entries: id (2 bytes), position (4 bytes)
            let num = rdr.read_u16::<LittleEndian>()?;
            let position = rdr.read_u32::<LittleEndian>()?;

            let r_volnr = (position >> 28) as u8;
            let r_offset: u64 = (position & 0xfffffff).into();
            let entry = ResourceEntryV1{
                r_id: resource::ResourceID{ num, rtype },
                r_volnr,
                r_offset
            };
            entries.push(entry);
        }
    }
    Ok(entries)
}

pub struct ResourceMapV1 {
    map: HashMap<resource::ResourceID, ResourceInfoV1>,
    volumes: HashMap<u8, std::fs::File>
}

impl ResourceMapV1 {
    pub fn new(path: &Path) -> Result<ResourceMapV1> {
        let resource_map_data = std::fs::read(path.join(RESOURCE_MAP))?;

        let rdirectory = parse_resource_directory(&resource_map_data)?;
        let entries;
        if let Ok(e) = parse_map_1_5(&rdirectory, &resource_map_data) {
            entries = e;
        } else if let Ok(e) = parse_map_1_6(&rdirectory, &resource_map_data) {
            entries = e;
        } else {
            return Err(anyhow!("unable to parse resource map"))
        }
        if entries.is_empty() {
            return Err(anyhow!("no entries found"))
        }

        let mut map: HashMap<resource::ResourceID, ResourceInfoV1> = HashMap::new();
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
            let header = ResourceHeaderV1::parse(res_file)?;
            if header.id != entry.r_id {
                return Err(anyhow!("resource id mismatch: map has {}, resource.{:03} has {}", entry.r_id, entry.r_volnr, header.id));
            }
            map.insert(entry.r_id, ResourceInfoV1{ entry: entry.clone(), header });
        }

        Ok(ResourceMapV1{ map, volumes })
    }
}

impl resource::ResourceMap for ResourceMapV1 {
    fn read_resource(&self, rid: &resource::ResourceID) -> Result<resource::ResourceData> {
        let entry = self.map.get(rid).context("resource not found")?;
        let mut res_file = &self.volumes[&entry.entry.r_volnr];

        // Go directly to the resource data - we've already parsed the header
        res_file.seek(SeekFrom::Start(entry.entry.r_offset + 9))?;

        let mut data: Vec<u8> = vec![ 0u8; entry.header.compressed_length as usize ];
        res_file.read(&mut data)?;

        let info = resource::ResourceInfo{
            compressed_size: entry.header.compressed_length,
            uncompressed_size: entry.header.uncompressed_length,
            compression_method: entry.header.comp_method,
        };
        Ok(resource::ResourceData{ info, data })
    }

    fn get_entries(&self) -> Vec<&resource::ResourceID> {
        self.map.keys().collect()
    }
}
