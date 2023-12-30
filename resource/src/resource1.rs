use byteorder::{ReadBytesExt, LittleEndian};

use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::path::Path;
use std::io::{Read,Seek,SeekFrom,Cursor};
use anyhow::{anyhow, Result, Context};

use crate::resource;

const RESOURCE_MAP: &str = "resource.map";

#[derive(Clone)]
pub struct ResourceEntryV1 {
    pub r_type: u8,
    pub r_volnr: u8,
    pub r_id: u16,
    pub r_offset: u64
}

pub struct ResourceDataV1 {
    pub header: ResourceHeaderV1,
    pub data: Vec<u8>
}

struct ResourceTypeOffsetV1 {
    type_number: u8,
    offset: u16
}

pub struct ResourceHeaderV1 {
    pub res_type: u8,
    pub id: u16,
    pub segment_length: u16,
    pub length: u16,
    pub compress_used: u16
}

impl ResourceHeaderV1 {
    fn parse<T: Read>(mut rdr: T) -> Result<ResourceHeaderV1> {
        let res_type = rdr.read_u8()?;
        let id = rdr.read_u16::<LittleEndian>()?;
        let segment_length = rdr.read_u16::<LittleEndian>()?;
        let length = rdr.read_u16::<LittleEndian>()?;
        let compress_used = rdr.read_u16::<LittleEndian>()?;
        Ok(ResourceHeaderV1{ res_type, id, segment_length, length, compress_used })
    }
}

type ResourceDirectory = Vec<ResourceTypeOffsetV1>;

fn parse_resource_directory(input: &[u8]) -> Result<ResourceDirectory> {
    let mut res_types: ResourceDirectory = Vec::new();
    let mut rdr = Cursor::new(&input);
    loop {
        let type_number = rdr.read_u8()?;
        let offset = rdr.read_u16::<LittleEndian>()?;
        res_types.push(ResourceTypeOffsetV1{ type_number, offset });
        if type_number == 255 { break; }
    }
    Ok(res_types)
}

fn parse_map_1_5(rdirectory: &ResourceDirectory, input: &[u8]) -> Result<Vec<ResourceEntryV1>> {
    let mut entries: Vec<ResourceEntryV1> = Vec::new();
    for n in 0..rdirectory.len() - 1 {
        let position = rdirectory[n].offset as usize;
        let position_end = rdirectory[n + 1].offset as usize;
        let map_entry_data = &input[position..position_end];

        let mut rdr = Cursor::new(&map_entry_data);
        while (rdr.position() as usize) < map_entry_data.len() {
            // 5-byte entries: id (2 bytes), offset (3 bytes)
            let resid = rdr.read_u16::<LittleEndian>()?;
            let woffset1 = rdr.read_u8()?;
            let woffset2 = rdr.read_u8()?;
            let woffset3 = rdr.read_u8()?;
            let offset = ((woffset1 as u32) << 1) + ((woffset2 as u32) << 9) + ((woffset3 as u32) << 17);
            let entry = ResourceEntryV1{
                r_type: rdirectory[n].type_number,
                r_volnr: 0,
                r_id: resid,
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
        let position = rdirectory[n].offset as usize;
        let position_end = rdirectory[n + 1].offset as usize;
        let map_entry_data = &input[position..position_end];

        let mut rdr = Cursor::new(&map_entry_data);
        while (rdr.position() as usize) < map_entry_data.len() {
            // 6-byte entries: id (2 bytes), position (4 bytes)
            let r_id = rdr.read_u16::<LittleEndian>()?;
            let position = rdr.read_u32::<LittleEndian>()?;

            let r_volnr = (position >> 28) as u8;
            let r_offset: u64 = (position & 0xfffffff).into();
            let entry = ResourceEntryV1{
                r_type: rdirectory[n].type_number,
                r_volnr,
                r_id,
                r_offset
            };
            entries.push(entry);
        }
    }
    Ok(entries)
}

pub struct ResourceMapV1 {
    map: HashMap<resource::ResourceID, ResourceEntryV1>,
    files: HashMap<u8, std::fs::File>
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

        let mut map: HashMap<resource::ResourceID, ResourceEntryV1> = HashMap::new();
        let mut volumes: HashSet<u8> = HashSet::new();
        for entry in &entries {
            let r_type = entry.r_type & 0x7f;
            let rtype = resource::ResourceType::new(r_type);
            let rid = resource::ResourceID{ num: entry.r_id, rtype };
            map.insert(rid, entry.clone());
            volumes.insert(entry.r_volnr);
        }

        let mut files: HashMap<u8, std::fs::File> = HashMap::new();
        for volnr in &volumes {
            let resource_file = path.join(format!("resource.{:03}", volnr));
            let res_file = File::open(&resource_file)?;
            files.insert(*volnr, res_file);
        }

        Ok(ResourceMapV1{ map, files })
    }
}

impl resource::ResourceMap for ResourceMapV1 {
    fn read_resource(&self, rid: &resource::ResourceID) -> Result<resource::ResourceData> {
        let entry = self.map.get(rid).context("resource not found")?;
        let mut res_file = &self.files[&entry.r_volnr];

        res_file.seek(SeekFrom::Start(entry.r_offset))?;
        let rh = ResourceHeaderV1::parse(res_file)?;
        //let rh_type = (header.id >> 11) as u8;
        //let rh_id = header.id & 0x7ff;
        let info = resource::ResourceInfo{
            compressed_size: rh.segment_length,
            uncompressed_size: rh.length,
            compression_method: resource::CompressionMethod::new(rh.compress_used),
        };

        let mut data: Vec<u8> = vec![ 0u8; info.compressed_size as usize ];
        res_file.read(&mut data)?;
        Ok(resource::ResourceData{ info, data })
    }

    fn get_entries(&self) -> Vec<&resource::ResourceID> {
        self.map.keys().collect()
    }
}
