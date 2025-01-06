use std::rc::Rc;
use std::collections::HashMap;

use crate::scires::resource;

pub struct LoadedResource {
    pub id: resource::ResourceID,
    pub data: Vec<u8>,
}

pub struct ResourceManager {
    path: String,
    cache: HashMap<resource::ResourceID, Rc<LoadedResource>>,
}

impl ResourceManager {
    pub fn new(path: String) -> Self {
        Self{path, cache: HashMap::new() }
    }

    pub fn get(&mut self, id: resource::ResourceID) -> Rc<LoadedResource> {
        let entry = self.cache.entry(id).or_insert_with(|| {
            let path = format!("{}/{}", self.path, id);
            let data = match std::fs::read(path) {
                Ok(data) => data,
                Err(_) => Vec::new()
            };
            Rc::new(LoadedResource{ id, data })
        });
        entry.clone()
    }
}
