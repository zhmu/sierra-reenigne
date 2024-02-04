use crate::sci1::{script1, class_defs1};
use crate::{kcalls, vocab, opcode, disassemble};
use anyhow::Result;

use std::collections::{HashSet, HashMap};

// TODO deduplicate
fn get_selector_name(selector_vocab: &vocab::Vocab997, index: u16) -> String {
    match selector_vocab.get_strings().get(index as usize) {
        Some(s) => s.clone(),
        None => format!("#{}", index)
    }
}

fn generate_labels(script: &script1::Script1, offset: u16, opcodes: &[u8]) -> HashMap<u16, String> {
    let mut labels = HashMap::<u16, String>::new();

    // Start by creating labels for all branches
    let disasm = disassemble::Disassembler::new1(offset as usize, opcodes);
    for ins in disasm {
        let opcode = &ins.opcode;
        for (n, a_type) in opcode.arg.iter().enumerate() {
            let a_value = ins.args[n];
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
    for (n, dispatch) in script.get_dispatches().iter().enumerate() {
        if let script1::Dispatch::Offset(offset) = dispatch {
            let label = format!("dispatch_{}", n);
            labels.insert(*offset, label);
        }
    }
    labels
}

fn decode_script1_code(script: &script1::Script1, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs1::ClassDefinitions1, code: &script1::Code) {
    // Make a set of all hunk fixup offsets - if the instruction's operand is
    // in here, we know it's an address
    let script_fixups = script.get_script_fixup_offsets().iter().collect::<HashSet<_>>();

    let opcodes = &script.get_hunk()[code.get_offset() as usize..(code.get_offset() + code.get_length()) as usize];
    let labels = generate_labels(script, code.get_offset(), opcodes);
    let disasm = disassemble::Disassembler::new1(code.get_offset() as usize, opcodes);
    for ins in disasm {
        let opcode = &ins.opcode;

        // Assemble the arguments
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

        //
        let offset: u16 = ins.offset.try_into().unwrap();
        if let Some(label) = labels.get(&offset) {
            println!("    {}:", label);
        }
        let mut line = "    ".to_string();
        line += &format!("{}", opcode.name).to_string();
        if !opcode.arg.is_empty() {
            // All opcodes are single-byte; if the next byte contains a fixup,
            // we know it's a pointer
            if script_fixups.contains(&(offset + 1)) {
                let item = script.find_item_by_offset(ins.args[0]);
                if let Some(item) = item {
                    let super_class_id = item.get_super_class_id();
                    let super_script = class_definitions.get_script_for_class_id(super_class_id).unwrap();
                    let super_class = super_script.get_class_by_id(super_class_id).expect("superclass not found");

                    match item {
                        script1::ObjectOrClass::Object(obj) => {
                            args[0] = format!("&{}", script.get_object_name(obj, super_class));
                        },
                        script1::ObjectOrClass::Class(class) => {
                            args[0] = format!("&{}", script.get_class_name(class));
                        }
                    };
                } else if let Some(s) = script.get_string(ins.args[0] as usize) {
                    args[0] = format!("\"{}\"", s);
                } else {
                    args[0] = format!("0x{:x}", ins.args[0]);
                }
            }

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

pub fn decode_script1(script: &script1::Script1, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs1::ClassDefinitions1) -> Result<()> {

    println!("locals {{");
    for (n, v) in script.get_locals().iter().enumerate() {
        let v = *v as u32;
        if v >= 0x8000 {
            println!("  {} = {}, // -{}, 0x{:x}", n, v, 65536 as u32 - v, v);
        } else {
            println!("  {} = {}, // 0x{:x}", n, v, v);
        }
    }
    println!("}}\n");

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
                    println!("object {} : super_class {} {{", item_name, class_name);

                    println!("  properties {{");
                    for (n, value) in obj.get_property_values().iter().enumerate() {
                        if *value == super_properties[n].value { continue; }
                        println!("    {} = {}, // was {}", get_selector_name(selector_vocab, super_properties[n].selector), value, super_properties[n].value);
                    }
                    println!("  }}\n");
                } else {
                    println!("// {}: <script for superclass {} in object is not available>, skipped", item_index, item.get_super_class_id());

                }
            },
            script1::ObjectOrClass::Class(class) => {
                let item_name = script.get_class_name(class);
                println!("class {} : super_class {} {{", item_name, super_class_id);

                let properties = class.get_properties();

                if let Some(super_script) = super_script {
                    let super_class = super_script.get_class_by_id(super_class_id).expect("superclass not found");
                    let super_properties = super_class.get_properties();

                    // Safety
                    assert!(super_properties.len() <= class.get_properties().len());

                    println!("  properties {{");
                    for (n, class_prop) in properties.iter().enumerate() {
                        let selector_name = get_selector_name(selector_vocab, class_prop.selector);
                        if n < super_properties.len() && properties[n].value == super_properties[n].value { continue; }
                        println!("    {} = {}, // {}", selector_name, properties[n].value, n);
                    }
                    println!("  }}");
                } else {
                    // This should only happen for RootObj ...
                    println!("  // note: no superclass here?");
                    println!("  properties {{");
                    for (n, class_prop) in properties.iter().enumerate() {
                        let selector_name = get_selector_name(selector_vocab, class_prop.selector);
                        println!("    {} = {}, //", selector_name, properties[n].value);
                    }
                    println!("  }}");
                }
            },
        }

        println!("  methods {{");
        for (method_index, m) in item.get_methods().iter().enumerate() {
            let selector_name = get_selector_name(selector_vocab, m.index);
            println!("    {} {{", selector_name);

            let code = script.find_item_by_code(item_index, method_index);
            decode_script1_code(&script, kernel_vocab, class_definitions, code);
            println!("    }}\n");
        }
        println!("  }}");
        println!("}}\n");
    }
    println!("dispatches {{");
    for (index, dispatch) in script.get_dispatches().iter().enumerate() {
        match dispatch {
            script1::Dispatch::Offset(offset) => {
                let code = script.get_code().iter()
                    .filter(|c| match c { script1::Code::Dispatch(offs, _, _) => { offs == offset }, _ => false })
                    .next().unwrap();

                println!("  {} {{", index);
                decode_script1_code(&script, kernel_vocab, class_definitions, code);
                println!("  }}\n");
            },
            script1::Dispatch::Item(item_index) => {
                let item = &script.get_items()[*item_index];
                let super_class_id = item.get_super_class_id();
                let super_script = class_definitions.get_script_for_class_id(super_class_id).expect("class not found");
                let super_class = super_script.get_class_by_id(super_class_id).expect("superclass not found");

                let name = match item {
                    script1::ObjectOrClass::Object(obj) => {
                        script.get_object_name(&obj, super_class)
                    },
                    script1::ObjectOrClass::Class(class) => {
                        script.get_class_name(&class)
                    }
                };
                println!("  {} = &{}", index, name);
            },
            script1::Dispatch::Invalid(offset) => {
                println!("  {} = 0x{:x}", index, offset);
            }
        }
    }
    println!("}}");
    Ok(())
}

