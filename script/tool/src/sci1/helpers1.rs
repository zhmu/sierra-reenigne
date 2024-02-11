use crate::sci1::{class_defs1, script1};

pub fn resolve_class_name<'a>(class_definitions: &'a class_defs1::ClassDefinitions1, class_id: u16) -> Option<&'a str> {
    if let Some(class_script) = class_definitions.get_script_for_class_id(class_id) {
        let class = class_script.get_items().iter().filter(|x| match x { script1::ObjectOrClass::Class(cl) => cl.get_class_id() == class_id, _ => false }).next();
        if let Some(class) = class {
            let class = match class { script1::ObjectOrClass::Class(class) => class, _ => { unreachable!(); } };
            return Some(class_script.get_class_name(class))
        }
    }
    None
}

pub fn resolve_item_name<'a>(class_definitions: &'a class_defs1::ClassDefinitions1, script: &'a script1::Script1, item: &script1::ObjectOrClass) -> Option<&'a str> {
    let super_class_id = item.get_super_class_id();
    if let Some(super_script) = class_definitions.get_script_for_class_id(super_class_id) {
        if let Some(super_class) = super_script.get_class_by_id(super_class_id) {
            return match item {
                script1::ObjectOrClass::Object(obj) => {
                    Some(script.get_object_name(obj, super_class))
                },
                script1::ObjectOrClass::Class(class) => {
                    Some(script.get_class_name(class))
                }
            }
        }
    }
    None
}
