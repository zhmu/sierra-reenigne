use crate::sciscript::{
    vocab, kcalls, opcode, disassemble,
    sci1::{script1, class_defs1}
};

use anyhow::Result;
use std::collections::HashMap;
use std::collections::HashSet;

// TODO deduplicate
fn get_selector_name(selector_vocab: &vocab::Vocab997, index: u16) -> String {
    match selector_vocab.get_strings().get(index as usize) {
        Some(s) => s.clone(),
        None => format!("#{}", index)
    }
}

// SCI1
type LabelMap = HashMap<u16, String>;

fn get_pretty_address(script: &script1::Script1, address: u16, labels: &LabelMap) -> String {
    if let Some(label) = labels.get(&address) {
        return format!("{} ({:x})", label, address);
    }
    if let Some(s) = script.get_string(address as usize) {
        return format!(r#""{}" {:x}"#, s, address);
    }
    format!("0x{:x}", address)
}

fn build_label_map1(script: &script1::Script1, class_definitions: &class_defs1::ClassDefinitions1, selector_vocab: &vocab::Vocab997) -> Result<LabelMap> {
    let mut labels: LabelMap = LabelMap::new();
    for (n, dispatch) in script.get_dispatches().iter().enumerate() {
        if let script1::Dispatch::Offset(offset) = dispatch {
            let label = format!("dispatch_{}", n);
            labels.insert(*offset, label);
        }
    }
    for (n, item) in script.get_items().iter().enumerate() {
        let super_class_id = item.get_super_class_id();
        let super_script = class_definitions.get_script_for_class_id(super_class_id);

        let name: String;
        match item {
            script1::ObjectOrClass::Object(obj) => {
                if let Some(super_script) = super_script {
                    let super_class = super_script.get_class_by_id(super_class_id).expect("superclass not found");
                    name = script.get_object_name(&obj, super_class).to_string();
                } else {
                    name = format!("object{}", n).to_string();
                }
            },
            script1::ObjectOrClass::Class(class) => {
                let item_name = script.get_class_name(class);
                name = format!("class_{}", item_name).to_string();
            }
        }
        let offset = item.get_offset();
        labels.insert(offset, name.clone());

        for method in item.get_methods() {
            let selector_name = get_selector_name(selector_vocab, method.index);

            let label = format!("{}::{}", name, selector_name);
            labels.insert(method.offset, label);
        }
    }
    Ok(labels)
}

fn disassemble_script1_code(script: &script1::Script1, kernel_vocab: &kcalls::KernelVocab, labels: &LabelMap, code: &script1::Code) {
    let script_fixups = script.get_script_fixup_offsets().iter().collect::<HashSet<_>>();
    println!("fixups {:x?}", script_fixups);

    let opcodes = &script.get_hunk()[code.get_offset() as usize..(code.get_offset() + code.get_length()) as usize];
    let disasm = disassemble::Disassembler::new(code.get_offset() as usize, opcodes);
    for ins in disasm {
        let offset: u16 = ins.offset.try_into().unwrap();
        if let Some(label) = labels.get(&offset) {
            println!("{}:", label);
        }

        let mut line: String = format!("{:04x}: ", offset);
        let mut n: usize = 0;
        while n < ins.bytes.len() {
            let value_offset = offset + n as u16;
            if script_fixups.contains(&value_offset) {
                line += &format!("[{:02x}{:02x}]", ins.bytes[n], ins.bytes[n + 1]);
                n += 2;
            } else {
                line += &format!("{:02x}", ins.bytes[n]);
                n += 1;
            }
        }
        while line.len() < 20 {
            line += &' '.to_string();
        }
        let opcode = &ins.opcode;
        line += &format!("{}", opcode.name).to_string();
        if !opcode.arg.is_empty() {
            while line.len() < 30 {
                line += &' '.to_string();
            }
            for (n, a_type) in opcode.arg.iter().enumerate() {
                let a_value = ins.args[n];
                match a_type {
                    opcode::Arg::Imm8 | opcode::Arg::Imm16 => {
                        line += &format!(" {}", a_value).to_string();
                    }
                    opcode::Arg::RelPos8 | opcode::Arg::RelPos16 => {
                        let j_offset = disassemble::relpos0_to_absolute_offset(&ins);
                        let pretty_address = get_pretty_address(script, j_offset, &labels);
                        line += &format!(" {}", pretty_address).to_string();
                    }
                }
            }
        }

        if ins.bytes[0] == 0x72 || ins.bytes[0] == 0x73 { /* lofsa */
            let address = disassemble::sci1_get_lofsa_address(&ins);
            let pretty_address = get_pretty_address(script, address, &labels);
            line += &format!(" # {}", &pretty_address).as_str();
        }
        if ins.bytes[0] == 0x42 || ins.bytes[0] == 0x43 { /* callk */
            if let Some(kfunc) = kernel_vocab.get_string(ins.args[0] as usize) {
                line += &format!(" # {}", kfunc).as_str();
            }
        }
        println!("  {}", line);
    }
}


pub fn inspect_script1(script: &script1::Script1, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs1::ClassDefinitions1) -> Result<()> {
/*
    println!("local variables");
    for (n, v) in script.get_locals().iter().enumerate() {
        let v = *v as u32;
        if v >= 0x8000 {
            println!("  local_{} = {} (-{}, 0x{:x})", n, v, 65536 as u32 - v, v);
        } else {
            println!("  local_{} = {} (0x{:x})", n, v, v);
        }
    }
*/
    let labels = build_label_map1(&script, class_definitions, selector_vocab)?;

    println!("\nOBJECTS/CLASSES\n");
    for (item_index, item) in script.get_items().iter().enumerate() {
        let super_class_id = item.get_super_class_id();
        let super_script = class_definitions.get_script_for_class_id(super_class_id);

        match item {
            script1::ObjectOrClass::Object(obj) => {
                if let Some(super_script) = super_script {
                    let super_class = super_script.get_class_by_id(super_class_id).expect("superclass not found");
                    let super_properties = super_class.get_properties();

                    let item_name = script.get_object_name(obj, super_class);
                    let class_name = super_script.get_class_name(super_class);
                    println!("[offset {:x}] object {} super_class {}", item.get_offset(), item_name, class_name);

                    // Safety
                    assert_eq!(super_properties.len(), obj.get_property_values().len());

                    println!("  property values");
                    for (n, value) in obj.get_property_values().iter().enumerate() {
                        if *value == super_properties[n].value { continue; }
                        println!("    {}. {} = {} (was {})", n, get_selector_name(selector_vocab, super_properties[n].selector), value, super_properties[n].value);
                    }
                } else {
                    println!("{}: <script for superclass {} in object is not available>", item_index, item.get_super_class_id());

                }
            },
            script1::ObjectOrClass::Class(class) => {
                let item_name = script.get_class_name(class);
                println!("[offset {:x}] class {} super_class {}", item.get_offset(), item_name, super_class_id);

                let properties = class.get_properties();

                if let Some(super_script) = super_script {
                    let super_class = super_script.get_class_by_id(super_class_id).expect("superclass not found");
                    let super_properties = super_class.get_properties();

                    // Safety
                    assert!(super_properties.len() <= class.get_properties().len());

                    println!("  properties");
                    for (n, class_prop) in properties.iter().enumerate() {
                        let selector_name = get_selector_name(selector_vocab, class_prop.selector);
                        if n < super_properties.len() && properties[n].value == super_properties[n].value { continue; }
                        println!("    {}. {} = {}", n, selector_name, properties[n].value);
                    }
                } else {
                    // This should only happen for RootObj ...
                    println!("  properties [note: no superclass here?!]");
                    for (n, class_prop) in properties.iter().enumerate() {
                        let selector_name = get_selector_name(selector_vocab, class_prop.selector);
                        println!("    {}. {} = {}", n, selector_name, properties[n].value);
                    }
                }
            },
        }

        println!("  methods");
        for (method_index, m) in item.get_methods().iter().enumerate() {
            let selector_name = get_selector_name(selector_vocab, m.index);
            println!("    {}. '{}' offset {:x}", method_index, selector_name, m.offset);

            let code = script.find_item_by_code(item_index, method_index);
            disassemble_script1_code(&script, kernel_vocab, &labels, code);
        }
    }
    println!("\nDISPATCHES\n");
    for code in script.get_code() {
        match code {
            script1::Code::Dispatch(..) => {
                // Note: dispatch offset is part of labels and will be printed
                disassemble_script1_code(&script, kernel_vocab, &labels, code);
            },
            _ => { }
        }
    }
    for (n, dispatch) in script.get_dispatches().iter().enumerate() {
        match dispatch {
            script1::Dispatch::Offset(_) => { }, // code
            script1::Dispatch::Item(index) => {
                println!("dispatch {} refers to item index {}", n, index);
            },
            script1::Dispatch::Invalid(offset) => {
                println!("dispatch {} refers to invalid offset {:x}", n, offset);
            },
        }
    }
    Ok(())
}

