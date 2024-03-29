use crate::sci0::class_defs0;
use crate::sci1::{class_defs1, helpers1};
use crate::vocab;
use anyhow::Result;

pub fn sci0_print_classes(class_definitions: &class_defs0::ClassDefinitions) -> Result<()> {
    for class_id in class_definitions.get_class_ids() {
        match class_definitions.find_class(class_id) {
            Some(obj_class) => {
                println!("{} {}", class_id, obj_class.name);
            },
            None => { println!("unable to find class class {}, skipping", class_id); }
        }
    }
    Ok(())
}

pub fn sci1_print_classes(class_definitions: &class_defs1::ClassDefinitions1) -> Result<()> {
    for class_id in class_definitions.get_class_ids() {
        if let Some(name) = helpers1::resolve_class_name(class_definitions, class_id) {
            println!("{} {}", class_id, name);
        } else {
            println!("warning: class {} is supposed to exist in script, but could not be found", class_id);
        }
    }
    Ok(())
}

pub fn print_selectors(selector_vocab: &vocab::Vocab997) -> Result<()> {
    for (n, s) in selector_vocab.get_strings().iter().enumerate() {
        println!("{} 0x{:x} {}", n, n, s);
    }
    Ok(())
}
