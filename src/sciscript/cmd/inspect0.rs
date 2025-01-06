use crate::sciscript::{
    {kcalls, said, vocab, opcode, disassemble},
    sci0::{class_defs0, object_class0, script0}
};
use anyhow::Result;
use byteorder::{LittleEndian, ReadBytesExt};
use std::collections::HashMap;
use std::io::Cursor;

// TODO deduplicate
type LabelMap = HashMap<u16, String>;

fn get_selector_name(selector_vocab: &vocab::Vocab997, index: u16) -> String {
    match selector_vocab.get_strings().get(index as usize) {
        Some(s) => s.clone(),
        None => format!("#{}", index)
    }
}

// SCI0
fn get_pretty_address(script: &script0::Script, address: u16, labels: &LabelMap) -> String {
    if let Some(label) = labels.get(&address) {
        return format!("{} ({:x})", label, address);
    }
    if let Some(string) = script.get_string(address as usize) {
        return format!(r#""{}" {:x}"#, string, address);
    }
    return format!("0x{:x}", address).to_string();
}


fn generate_said_labels(saids: &said::Said, labels: &mut LabelMap) {
    for said in &saids.items {
        let label = format!("said_{:x}", said.offset);
        labels.insert(said.offset.try_into().unwrap(), label);
    }
}

fn generate_code_labels(block: &script0::ScriptBlock, labels: &mut LabelMap) {
    let disasm = disassemble::Disassembler::new(block.base, &block.data);
    for ins in disasm {
        if ins.bytes[0] == 0x40 || ins.bytes[0] == 0x41 { /* call */
            let j_offset = disassemble::relpos0_to_absolute_offset(&ins);
            let label = format!("local_{:x}", j_offset);
            labels.insert(j_offset, label);
        }
    }
}

fn generate_export_labels(block: &script0::ScriptBlock, script_id: u16, labels: &mut LabelMap) -> Result<()> {
    let mut rdr = Cursor::new(&block.data);

    // XXX This does not belong here
    let num_exports = rdr.read_u16::<LittleEndian>()?;
    for n in 0..num_exports {
        let offset = rdr.read_u16::<LittleEndian>()?;

        let label = format!("export_s{}_{}", script_id, n);
        labels.insert(offset, label);
    }
    Ok(())
}

fn generate_object_class_labels(block: &script0::ScriptBlock, object_class: &object_class0::ObjectClass, selector_vocab: &vocab::Vocab997, labels: &mut LabelMap) {
    let obj_offset = block.base + 8; // skip magic/local var offset
    let label = format!("{}", object_class.name);
    labels.insert(obj_offset.try_into().unwrap(), label); // TODO need to add base offset here?

    for func in &object_class.functions {
        let selector_name = get_selector_name(selector_vocab, func.selector);
        let label = format!("{}::{}", object_class.name, selector_name);
        labels.insert(func.offset.try_into().unwrap(), label); // TODO need to add base offset here?
    }
}


fn build_label_map(script: &script0::Script, selector_vocab: &vocab::Vocab997, main_vocab: &Option<vocab::Vocab000>) -> Result<LabelMap> {
    let mut labels: LabelMap = LabelMap::new();
    for block in &script.blocks {
        match block.r#type {
            script0::BlockType::Object => {
                let object_class = object_class0::ObjectClass::new(&script, &block, object_class0::ObjectClassType::Object)?;
                generate_object_class_labels(&block, &object_class, &selector_vocab, &mut labels);
            },
            script0::BlockType::Class => {
                let object_class = object_class0::ObjectClass::new(&script, &block, object_class0::ObjectClassType::Class)?;
                generate_object_class_labels(&block, &object_class, &selector_vocab, &mut labels);
            },
            script0::BlockType::Said => {
                if let Some(vocab) = main_vocab {
                    let said = said::Said::new(&block, vocab)?;
                    generate_said_labels(&said, &mut labels);
                }
            },
            script0::BlockType::Code => {
                generate_code_labels(&block, &mut labels);
            },
            script0::BlockType::Exports => {
                generate_export_labels(&block, script.id, &mut labels)?;
            }
            _ => { }
        };
    }
    Ok(labels)
}


fn decode_object_class(script: &script0::Script, block: &script0::ScriptBlock, selector_vocab: &vocab::Vocab997, class_definitions: &class_defs0::ClassDefinitions, oc_type: object_class0::ObjectClassType) -> Result<()> {
    let object_class = object_class0::ObjectClass::new(&script, &block, oc_type.clone())?;

    let object_or_class = if oc_type == object_class0::ObjectClassType::Class { "class" } else { "object" };
    let species = object_class.get_species();
    let species_class = class_definitions.find_class(species).unwrap();

    let inherits_from: String;
    if species != 0 {
        inherits_from = format!(" : {}", species_class.name);
    } else {
         inherits_from = "".to_string();
    }

    println!("  {} {}{} {{", object_or_class, object_class.name, inherits_from);

    let property_vec = species_class.get_class_properties(selector_vocab);

    for (n, prop) in object_class.properties.iter().enumerate() {
        let prop_name;
        if n < property_vec.len() {
            prop_name = property_vec[n].0.as_str();
        } else {
            prop_name = "(???)";
        }
        let value: String = match n {
            object_class0::SELECTOR_INDEX_SPECIES |
            object_class0::SELECTOR_INDEX_SUPERCLASS => {
                match class_definitions.find_class(prop.selector) {
                    Some(s) => { format!("{} ({})", s.name, prop.selector) }
                    None => { format!("? ({})", prop.selector) }
                }
            },
            object_class0::SELECTOR_INDEX_NAME => {
                match script.get_string(prop.selector as usize) {
                    Some(s) => { format!("'{}' (0x{:x})", s, prop.selector) },
                    None => { format!("0x{:x}", prop.selector) }
                }
            },
            _ => {
                format!("{}", prop.selector)
            }
        };
        println!("    property {}. {} = {}", n, prop_name, value);
    }

    for (n, func) in object_class.functions.iter().enumerate() {
        let selector_name = get_selector_name(selector_vocab, func.selector);
        println!("    function {}. selector '{}' ({:x}) offset {:x}", n, selector_name, func.selector, func.offset);
    }
    println!("  }}");
    Ok(())
}

fn disassemble_block(script: &script0::Script, block: &script0::ScriptBlock, labels: &LabelMap, kernel_vocab: &kcalls::KernelVocab) {
    let disasm = disassemble::Disassembler::new(block.base, &block.data);
    for ins in disasm {
        let offset: u16 = ins.offset.try_into().unwrap();
        if let Some(label) = labels.get(&offset) {
            println!("{}:", label);
        }

        let mut line: String = format!("{:04x}: ", offset);
        for n in ins.bytes {
            line += &format!("{:02x}", n);
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
                        let pretty_address = get_pretty_address(&script, j_offset, &labels);
                        line += &format!(" {}", pretty_address).to_string();
                    }
                }
            }
        }

        if ins.bytes[0] == 0x72 || ins.bytes[0] == 0x73 { /* lofsa */
            let address = disassemble::sci0_get_lofsa_address(&ins, offset);
            let pretty_address = get_pretty_address(&script, address, &labels);
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

fn decode_said(block: &script0::ScriptBlock, vocab: &vocab::Vocab000) -> Result<()> {
    let said = said::Said::new(&block, &vocab)?;
    for s in &said.items {
        println!("{:x}: {}", s.offset, s.said);
    }
    Ok(())
}

fn dump_block(_script: &script0::Script, block: &script0::ScriptBlock) -> Result<()> {
    const BYTES_PER_LINE: usize = 16;

    let mut n: usize = 0;
    while n < block.data.len() {
        let mut s: String = format!("{:04x}:", n);
        let num_bytes: usize = std::cmp::min(block.data.len() - n, BYTES_PER_LINE);
        for b in &block.data[n..n+num_bytes] {
            s += format!(" {:02x}", b).as_str();
        }
        for _ in num_bytes..BYTES_PER_LINE {
            s += "   ";
        }
        s += "  ";
        for b in &block.data[n..n+num_bytes] {
            let b = *b as char;
            if b >= ' ' && b <= '~' {
                s += format!("{}", b).as_str();
            } else {
                s += ".";
            }
        }
        println!("{}", s);
        n += num_bytes;
    }
    Ok(())
}


pub fn inspect_script0(script: &script0::Script, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs0::ClassDefinitions, main_vocab: &Option<vocab::Vocab000>) -> Result<()> {
    let labels = build_label_map(&script, selector_vocab, main_vocab)?;
    for block in &script.blocks {
        println!("block @ {:x} type {:?} size {}", block.base, block.r#type, block.data.len());
        match block.r#type {
            script0::BlockType::Code => { disassemble_block(&script, &block, &labels, &kernel_vocab); }
            script0::BlockType::Object => { decode_object_class(&script, &block, selector_vocab, class_definitions, object_class0::ObjectClassType::Object)?; }
            script0::BlockType::Class => { decode_object_class(&script, &block, selector_vocab, class_definitions, object_class0::ObjectClassType::Class)?; }
            script0::BlockType::Said => {
                if let Some(vocab) = main_vocab {
                    decode_said(&block, vocab)?;
                } else {
                    println!("*** Cannot decode said block, vocabulary not loaded");
                }
            },
            _ => { dump_block(&script, &block)?; }
        };
        println!();
    }
    Ok(())
}

// sci1
