use crate::sciscript::{
    vocab,
    sci0::class_defs0,
    sci1::{class_defs1, helpers1}
};
use anyhow::Result;

pub fn sci0_print_classes(class_definitions: &class_defs0::ClassDefinitions, class_vocab: &vocab::Vocab996) -> Result<()> {
    for class_id in class_definitions.get_class_ids() {
        match class_definitions.find_class(class_id) {
            Some(obj_class) => {
                println!("{} {} (script.{:03})", class_id, obj_class.name, class_vocab.get_script(class_id).unwrap_or(u16::MAX));
            },
            None => { println!("unable to find class class {}, skipping", class_id); }
        }
    }
    Ok(())
}

pub fn sci1_print_classes(class_definitions: &class_defs1::ClassDefinitions1, class_vocab: &vocab::Vocab996) -> Result<()> {
    for class_id in class_definitions.get_class_ids() {
        if let Some(name) = helpers1::resolve_class_name(class_definitions, class_id) {
            println!("{} {} (script.{:03})", class_id, name, class_vocab.get_script(class_id).unwrap_or(u16::MAX));
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
