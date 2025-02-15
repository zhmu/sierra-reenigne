use crate::sciscript::{
    kcalls, vocab, opcode, disassemble,
    sci0::{script0, class_defs0, object_class0}
};
use byteorder::{LittleEndian, ReadBytesExt};
use std::io::Cursor;
use anyhow::{anyhow, Result};
use std::collections::HashMap;

const SHOW_LOCALS: bool = true;

const SCI0_OBJECT_DELTA: usize = 8;

fn decode_locals(local_block: &script0::ScriptBlock) -> Result<()> {
    let mut rdr = Cursor::new(&local_block.data);
    let mut n: usize = 0;
    while rdr.position() < local_block.data.len() as u64 {
        let v = rdr.read_u16::<LittleEndian>()? as u32;
        if v >= 0x8000 {
            println!("  {} = {}, // -{}, 0x{:x}", n, v, 65536 as u32 - v, v);
        } else {
            println!("  {} = {}, // 0x{:x}", n, v, v);
        }
        n += 1;
    }
    Ok(())
}

fn lookup_selector(selector_vocab: &vocab::Vocab997, id: u16) -> String {
    if let Some(s) = selector_vocab.get_string(id as usize) {
        s.clone()
    } else {
        format!("{}", id).to_string()
    }
}

fn lookup_property_selector(class: &object_class0::ObjectClass, index: usize) -> u16 {
    class.properties[index].selector_id.unwrap()
}

fn resolve_class_name(class_defs: &class_defs0::ClassDefinitions, class_id: u16) -> Option<&str> {
    if let Some(super_class) = class_defs.find_class(class_id) {
        Some(&super_class.name)
    } else {
        None
    }
}

fn get_dispatches(script: &script0::Script) -> Vec<u16> {
    let mut dispatches = Vec::new();
    if let Some(block) = script.blocks.iter().find(|b| b.r#type == script0::BlockType::Exports) {
        let mut rdr = Cursor::new(&block.data);
        let num_exports = rdr.read_u16::<LittleEndian>().unwrap();
        for _ in 0..num_exports {
            let offset = rdr.read_u16::<LittleEndian>().unwrap();
            dispatches.push(offset);
        }
    }
    dispatches
}

fn generate_labels(script: &script0::Script, offset: usize, code: &[u8]) -> HashMap<u16, String> {
    let mut labels = HashMap::<u16, String>::new();

    // Start by creating labels for all branches
    let disasm = disassemble::Disassembler::new(offset, code);
    for ins in disasm {
        let opcode = &ins.opcode;
        for a_type in opcode.arg {
            match a_type {
                opcode::Arg::RelPos8 | opcode::Arg::RelPos16 => {
                    let offset = disassemble::relpos0_to_absolute_offset(&ins);
                    labels.insert(offset, format!("loc_{:x}", offset));
                },
                _ => { }
            }
        }
    }

    // Overwrite all dispatches
    for (n, offset) in get_dispatches(script).iter().enumerate() {
        let label = format!("dispatch_{}", n);
        labels.insert(*offset, label);
    }

    labels
}

fn decode_script0_code(script: &script0::Script, code: &[u8], code_offset: usize, kernel_vocab: &kcalls::KernelVocab, class_defs: &class_defs0::ClassDefinitions) {
    println!("      // {:x} .. {:x}", code_offset, code_offset + code.len());

    let labels = generate_labels(script, code_offset, code);
    let disasm = disassemble::Disassembler::new(code_offset, code);
    for ins in disasm {
        let opcode = &ins.opcode;

        let mut args = Vec::<String>::new();
        for (n, a_type) in opcode.arg.iter().enumerate() {
            let a_value = ins.args[n];
            match a_type {
                opcode::Arg::Imm8 | opcode::Arg::Imm16 => {
                    args.push(format!("{}", a_value).to_string());
                }
                opcode::Arg::RelPos8 | opcode::Arg::RelPos16 => {
                    let offset = disassemble::relpos0_to_absolute_offset(&ins);
                    let label = labels.get(&offset).unwrap();
                    args.push(label.clone());
                }
            }
        }

        // For kernel calls, replace the ID with the call name
        if ins.bytes[0] == 0x42 || ins.bytes[0] == 0x43 { /* callk */
            if let Some(kfunc) = kernel_vocab.get_string(ins.args[0] as usize) {
                args[0] = format!("{}", kfunc).to_string();
            }
        }

        // For super, replace the ID with the class name
        if ins.bytes[0] == 0x56 || ins.bytes[0] == 0x57 { /* super */
            let class_id = ins.args[0];
            if let Some(class_name) = resolve_class_name(class_defs, class_id) {
                args[0] = format!("{}", class_name);
            }
        }

        let offset: u16 = ins.offset.try_into().unwrap();
        if let Some(label) = labels.get(&offset) {
            println!("    {}:", label);
        }
        let mut line = "    ".to_string();
        line += &format!("{}", opcode.name).to_string();

        if !opcode.arg.is_empty() {
            while line.len() < 12 {
                line += &' '.to_string();
            }
            for arg in args {
                line += &format!(" {}", arg).to_string();
            }
        }
        println!("  {}", line);
    }
}

fn find_code_block(script: &script0::Script, offset: usize) -> Option<&script0::ScriptBlock> {
    script.blocks.iter().find(|b| b.r#type == script0::BlockType::Code && offset >= b.base && offset < b.base + b.data.len())
}

fn decode_object_class(script: &script0::Script, item: &object_class0::ObjectClass, class_defs: &class_defs0::ClassDefinitions, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab) -> Result<()> {
    let super_class_name = if let Some(super_class) = class_defs.find_class(item.get_superclass()) {
        &super_class.name
    } else {
        &format!("{}", item.get_superclass())
    };
    let species_class = class_defs.find_class(item.get_species());

    if item.r#type == object_class0::ObjectClassType::Class {
        println!("class {} : super_class {} {{", item.name, super_class_name);
    } else {
        println!("object {} : super_class {} {{", item.name, super_class_name);
    }
    println!("  properties {{");
    for (n, prop) in item.properties.iter().enumerate() {
        let value = prop.selector;
        if let Some(selector_id) = prop.selector_id {
            let selector_name = lookup_selector(selector_vocab, selector_id);
            println!("    {} = {}, // {}", selector_name, value, n);
        } else if let Some(species) = species_class {
            // Look up the selector in the species
            let selector_id = lookup_property_selector(species, n);
            let selector_name = lookup_selector(selector_vocab, selector_id);
            println!("    {} = {}, // {}", selector_name, value, n);
        } else {
            return Err(anyhow!("species class {} undefined", item.get_species()));
        }
    }
    println!("  }}");

    // We'll assume that all functions are in a separate script block
    let mut method_block: Option<_> = None;
    let mut method_offsets: Vec<_> = item.functions.iter().map(|f| f.offset).collect();
    method_offsets.sort();
    if let Some(first_offset) = method_offsets.first() {
        let first_offset = *first_offset as usize;
        if let Some(block) = find_code_block(script, first_offset) {
            method_block = Some(block);
            method_offsets.push((block.base + block.data.len()) as u16);
        } else {
            return Err(anyhow!("method offset {:x} not found in script code", first_offset));
        }
    }

    println!("  methods {{");
    for (_n, method) in item.functions.iter().enumerate() {
        let selector_name = lookup_selector(selector_vocab, method.selector);
        println!("    {} {{", selector_name);
        let method_offset_index = method_offsets.iter().position(|m| *m == method.offset).unwrap();
        let code_start = method_offsets[method_offset_index] as usize;
        let code_end = method_offsets[method_offset_index + 1] as usize;

        let method_block = method_block.unwrap();

        let code = &method_block.data[code_start - method_block.base..code_end - method_block.base];
        decode_script0_code(script, &code, code_start, kernel_vocab, class_defs);
        println!("    }}");
        println!();
    }
    println!("  }}");

    println!("}}");
    Ok(())
}

pub fn decode_script0(script: &script0::Script, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_defs: &class_defs0::ClassDefinitions) -> Result<()> {
    println!("locals {{");
    if let Some(local_block) = script.blocks.iter().find(|b| b.r#type == script0::BlockType::LocalVars) {
        if SHOW_LOCALS { decode_locals(local_block)?; }
    }
    println!("}}");

    let script_length = script.blocks.iter().map(|b| b.base + b.data.len()).max().unwrap() as u16;

    let mut all_code_offsets = Vec::new();
    for block in &script.blocks {
        let item = match block.r#type {
            script0::BlockType::Object => {
                object_class0::ObjectClass::new(script, block, object_class0::ObjectClassType::Object)?
            },
            script0::BlockType::Class => {
                object_class0::ObjectClass::new(script, block, object_class0::ObjectClassType::Class)?
            },
            _ => { continue; }
        };
        all_code_offsets.append(&mut item.functions.iter().map(|f| f.offset).collect::<Vec<_>>());
        decode_object_class(script, &item, class_defs, selector_vocab, kernel_vocab)?;
    }
    all_code_offsets.append(&mut get_dispatches(script).iter().filter(|d| **d < script_length).map(|d| *d).collect::<Vec<_>>());
    all_code_offsets.sort();

    println!("dispatches {{");
    for (index, offset) in get_dispatches(script).iter().enumerate() {
        if let Some(block) = script.blocks.iter().find(|b| b.base + SCI0_OBJECT_DELTA == *offset as usize) {
            if block.r#type != script0::BlockType::Object {
                return Err(anyhow!("dispatch {}/{:x} to non-object", index, offset));
            }
            let item = object_class0::ObjectClass::new(script, block, object_class0::ObjectClassType::Object).expect("reference to corrupt object");
            println!("  {} = &{}", index, item.name);
        } else {
            // Reference not found - assume it's code
            let offset = *offset as usize;
            if let Some(block) = find_code_block(script, offset) {
                println!("  {} {{", index);
                // Find where this dispatch ends - this will find the first entry larger than the
                // function's offset, which is the next function and thus where the functio ends
                // println!("all offset {:x?} offset {:x} {:x} {:x}", all_code_offsets, offset, block.base, block.base + block.data.len());
                let mut end_offset = if let Some(offset) = all_code_offsets.iter().find(|o| **o as usize > offset) {
                    *offset as usize
                } else {
                    usize::MAX
                };
                end_offset = std::cmp::min(end_offset, block.base + block.data.len());

                let code = &block.data[offset - block.base..end_offset - block.base];
                decode_script0_code(script, code, offset, kernel_vocab, class_defs);
                println!("  }}");
            } else {
                println!("  {} = 0x{:x}", index, offset);
            }
        }
    }
    println!("}}");
    Ok(())
}

