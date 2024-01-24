use std::collections::{HashMap, HashSet};
use anyhow::Result;

use crate::sci1::script1;
use crate::vocab;

pub struct ClassDefinitions1 {
    all_scripts: HashMap<u16, script1::Script1>,
    classes: HashMap<u16, u16>
}

impl ClassDefinitions1 {
    pub fn new(extract_path: &str, class_vocab: &vocab::Vocab996) -> Result<ClassDefinitions1> {
        let mut script_ids = HashSet::<u16>::new();

        // Convert class_vocab to class_id -> script_id map
        let mut classes = HashMap::<u16, u16>::new();
        for class_id in 0..class_vocab.get_number_of_classes() {
            let script_id = class_vocab.get_script(class_id as u16).unwrap();
            classes.insert(class_id as u16, script_id);
            script_ids.insert(script_id);
        }

        // Try to load all scripts we need
        let mut all_scripts = HashMap::<u16, script1::Script1>::new();
        for script_id in script_ids {
            match script1::load_sci1_script(extract_path, script_id) {
                Ok(script) => { all_scripts.insert(script_id, script); },
                Err(_) => { /* ignore unavailable scripts for now */ },
            }
        }
        Ok(ClassDefinitions1{ all_scripts, classes })
    }

    pub fn get_script(&self, script_id: u16) -> Option<&script1::Script1> {
        self.all_scripts.get(&script_id)
    }

    pub fn get_script_for_class_id(&self, class_id: u16) -> Option<&script1::Script1> {
        if let Some(script_id) = self.classes.get(&class_id) {
            if let Some(script) = self.all_scripts.get(&script_id) {
                return Some(script);
            }
        }
        None
    }
}
