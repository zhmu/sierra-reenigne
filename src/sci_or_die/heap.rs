use anyhow::{anyhow, Result};

const HEAP_SIZE: usize = 65535;

#[derive(Debug)]
pub enum HeapItemType {
    Available,
    SaveDirectory,
    Stack,
    Script(u16),
    Clone(u16),
    Node,
}

struct HeapItem {
    base: u16,
    size: u16,
    itype: HeapItemType,
}

pub struct Heap {
    data: [ u8; HEAP_SIZE ],
    items: Vec<HeapItem>,
}

impl Heap {
    pub fn new() -> Self {
        let data = [ 0u8; HEAP_SIZE ];
        let items = vec![ HeapItem{ base: 0, size: HEAP_SIZE as u16, itype: HeapItemType::Available } ];
        Self{ data, items }
    }

    pub fn data(&self) -> &[u8] { &self.data }
    pub fn data_mut(&mut self) -> &mut [u8] { &mut self.data }

    pub fn load_u8(&self, address: usize) -> u8 {
        self.data[address]
    }

    pub fn store_u8(&mut self, address: usize, value: u8) {
        self.data[address] = value;
    }

    pub fn load_u16(&self, address: usize) -> u16 {
        // let address = address as usize;
        let a = self.data[address + 0] as u16;
        let b = self.data[address + 1] as u16;
        a + (b << 8)
    }

    pub fn store_u16(&mut self, address: usize, value: u16) {
        // let address = address as usize;
        self.data[address + 0] = (value & 0xff) as u8;
        self.data[address + 1] = (value >> 8) as u8;
    }

    pub fn get_string(&self, offset: usize) -> &str {
        let data = &self.data[offset..];
        let nul_byte_end = data.iter()
            .position(|&c| c == b'\0')
            .unwrap_or(data.len());
        std::str::from_utf8(&data[0..nul_byte_end]).unwrap_or("<corrupt>")
    }

    pub fn info(&self) {
        println!("heap items");
        for item in &self.items {
            println!("  {:04x}..{:04x} type {:?}",
                item.base, item.base + item.size - 1,
                item.itype);
        }
    }

    pub fn allocate(&mut self, itype: HeapItemType, size: u16) -> Result<u16> {
        // Locate the smallest available block
        let mut avail_block_index: Option<usize> = None;
        let mut avail_block_size: Option<u16> = None;
        for (n, item) in self.items.iter().enumerate() {
            match item.itype {
                HeapItemType::Available => {
                    let block_ok = if let Some(avail_block_size) = avail_block_size {
                        item.size < avail_block_size
                    } else {
                        true
                    };
                    if block_ok && item.size >= size {
                        avail_block_index = Some(n);
                        avail_block_size = Some(item.size);
                    }
                },
                _ => {}
            }
        }

        match avail_block_index {
            Some(index) => {
                let item = &mut self.items[index];
                let avail_base = item.base + size;
                let avail_size = item.size - size;
                let item_base = item.base;
                item.size = size;
                item.itype = itype;
                self.items.insert(index + 1, HeapItem{
                    base: avail_base, size: avail_size, itype: HeapItemType::Available
                });
                Ok(item_base)
            },
            None => {
                return Err(anyhow!("out of heap trying to allocate {} bytes", size));
            }
        }
    }

    pub fn free(&mut self, address: u16) -> Result<()> {
        for (n, item) in self.items.iter_mut().enumerate() {
            if item.base != address { continue; }
            log::warn!("Heap::free() needs to be optimized to merge adjacent blocks");
            self.items[n].itype = HeapItemType::Available;
            return Ok(());
        }
        Err(anyhow!("cannot free address {:x}, not found on heap", address))
    }

    pub fn get_free_bytes(&self) -> u16 {
        self.items.iter().map(|i|
            match i.itype {
                HeapItemType::Available => i.size,
                _ => 0
            }
        ).sum()
    }

    pub fn get_largest_contiguous_block(&self) -> u16 {
        let mut result = 0;
        for item in &self.items {
            match item.itype {
                HeapItemType::Available => {
                    result = std::cmp::max(result, item.size);
                },
                _ => {}
            };
        }
        result
    }
}
