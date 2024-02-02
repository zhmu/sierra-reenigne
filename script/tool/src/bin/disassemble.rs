extern crate sciscript;

use anyhow::Result;
use sciscript::{opcode, disassemble, vocab, said, kcalls};
use sciscript::sci0::{class_defs0, object_class0, script0};
use sciscript::sci1::{class_defs1, script1};
use std::collections::HashMap;
use byteorder::{ByteOrder, LittleEndian, ReadBytesExt, WriteBytesExt};
use std::io::Cursor;
use clap::{Parser, Subcommand};

use std::fs::File;
use std::io::Write;

type LabelMap = HashMap<u16, String>;

fn print_selectors(extract_path: &str) -> Result<()> {
    let selector_vocab = get_selectors(extract_path)?;
    for (n, s) in selector_vocab.get_strings().iter().enumerate() {
        println!("{} 0x{:x} {}", n, n, s);
    }
    Ok(())
}

fn get_selector_name(selector_vocab: &vocab::Vocab997, index: u16) -> String {
    match selector_vocab.get_strings().get(index as usize) {
        Some(s) => s.clone(),
        None => format!("#{}", index)
    }
}

fn get_pretty_address(script: &script0::Script, address: u16, labels: &LabelMap) -> String {
    if let Some(label) = labels.get(&address) {
        return format!("{} ({:x})", label, address);
    }
    if let Some(string) = script.get_string(address as usize) {
        return format!(r#""{}" {:x}"#, string, address);
    }
    return format!("0x{:x}", address).to_string();
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
                        let j_offset = script0::relpos0_to_absolute_offset(&ins);
                        let pretty_address = get_pretty_address(&script, j_offset, &labels);
                        line += &format!(" {}", pretty_address).to_string();
                    }
                }
            }
        }

        if ins.bytes[0] == 0x72 || ins.bytes[0] == 0x73 { /* lofsa */
            let address = ((offset as usize + ins.bytes.len() + ins.args[0] as usize) & 0xffff) as u16;
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
            let j_offset = script0::relpos0_to_absolute_offset(&ins);
            let label = format!("local_{:x}", j_offset);
            labels.insert(j_offset, label);
        }
    }
}

fn generate_export_labels(block: &script0::ScriptBlock, script_id: u16, labels: &mut LabelMap) -> Result<()> {
    let mut rdr = Cursor::new(&block.data);

    let num_exports = rdr.read_u16::<LittleEndian>()?;
    for n in 0..num_exports {
        let offset = rdr.read_u16::<LittleEndian>()?;

        let label = format!("export_s{}_{}", script_id, n);
        labels.insert(offset, label);
    }
    Ok(())
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

fn build_label_map1(script: &script1::Script1, class_definitions: &class_defs1::ClassDefinitions1, selector_vocab: &vocab::Vocab997) -> Result<LabelMap> {
    let mut labels: LabelMap = LabelMap::new();
    for (n, offset) in script.get_dispatch_offsets().iter().enumerate() {
        let label = format!("dispatch_{}", n);
        labels.insert(*offset, label);
    }
    for (n, item) in script.get_items().iter().enumerate() {
        let super_class_id = item.get_super_class_id();
        let super_script = class_definitions.get_script_for_class_id(super_class_id);

        let name: String;
        match item {
            script1::ObjectOrClass::Object(obj) => {
                if let Some(super_script) = super_script {
                    let super_class = get_class_from_script1(&super_script, super_class_id).expect("superclass not found");
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


        for method in item.get_methods() {
            let selector_name = get_selector_name(selector_vocab, method.index);

            let label = format!("{}::{}", name, selector_name);
            labels.insert(method.offset, label);
        }
    }
    Ok(labels)
}

fn process_script0(script: &script0::Script, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs0::ClassDefinitions, main_vocab: &Option<vocab::Vocab000>) -> Result<()> {
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

fn get_class_from_script1(script: &script1::Script1, class_id: u16) -> Option<&script1::Class1> {
    for item in script.get_items() {
        match item {
            script1::ObjectOrClass::Class(class) => {
                if class.get_class_id() == class_id {
                    return Some(class);
                }
            },
            _ => { }
        }
    }
    None
}

fn disassemble_script1_code(script: &script1::Script1, kernel_vocab: &kcalls::KernelVocab, labels: &LabelMap, code: &script1::Code) {
    let opcodes = &script.get_hunk()[code.get_offset() as usize..(code.get_offset() + code.get_length()) as usize];
    let disasm = disassemble::Disassembler::new1(code.get_offset() as usize, opcodes);
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
                        let _j_offset = script0::relpos0_to_absolute_offset(&ins);
                        let pretty_address = "???"; // get_pretty_address(&script, j_offset, &labels);
                        line += &format!(" {}", pretty_address).to_string();
                    }
                }
            }
        }

        if ins.bytes[0] == 0x72 || ins.bytes[0] == 0x73 { /* lofsa */
            let _address = ((offset as usize + ins.bytes.len() + ins.args[0] as usize) & 0xffff) as u16;
            let pretty_address = "???"; // get_pretty_address(&script, address, &labels);
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

fn script1_find_item_code<'a>(script: &'a script1::Script1, item_index: usize, method_index: usize) -> &'a script1::Code {
    script.get_code().iter()
        .filter(|c| match c { script1::Code::Method(_, _, i_idx, m_idx) => { *i_idx == item_index && *m_idx == method_index }, _ => false })
        .next()
        .unwrap()
}

fn process_script1(script: &script1::Script1, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs1::ClassDefinitions1) -> Result<()> {
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
                    let super_class = get_class_from_script1(&super_script, super_class_id).expect("superclass not found");
                    let super_properties = super_class.get_properties();

                    let item_name = script.get_object_name(obj, super_class);
                    let class_name = super_script.get_class_name(super_class);
                    println!("{}: object {} super_class {}", item_index, item_name, class_name);

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
                println!("{}: class {} super_class {}", item_index, item_name, super_class_id);

                let properties = class.get_properties();

                if let Some(super_script) = super_script {
                    let super_class = get_class_from_script1(&super_script, super_class_id).expect("superclass not found");
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

            let code = script1_find_item_code(&script, item_index, method_index);
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
    Ok(())
}

#[derive(Subcommand)]
enum CliCommand {
    /// Decodes internal script.nnn structure
    Decode {
        /// Script to decode
        script_id: u16
    },
    /// Decodes and encodes script.nnn
    Recode {
        /// Script to decode
        script_id: u16
    },
    /// Display selector nams
    Selectors { },
    /// Display classes
    Classes{ },
}

/// Disassembles Sierra scripts
#[derive(Parser)]
struct Cli {
    #[clap(long, default_value_t=false)]
    /// Treat input as SCI1 (default: SCI0)
    sci1: bool,
    #[clap(long, default_value_t=false)]
    /// If set, external scripts will not be loaded
    no_externals: bool,
    /// Input directory
    in_dir: String,
    #[command(subcommand)]
    command: CliCommand
}

fn sci0_decode(extract_path: &str, script_id: u16, kernel_vocab: &kcalls::KernelVocab, selector_vocab: &vocab::Vocab997) -> Result<()> {
    let class_definitions = sci0_get_class_defs(extract_path)?;

    let main_vocab: Option<vocab::Vocab000>;
    if let Ok(vocab_000_data) = std::fs::read(format!("{}/vocab.000", extract_path)) {
        match vocab::Vocab000::new(&vocab_000_data) {
            Ok(v) => { main_vocab = Some(v); },
            Err(e) => {
                println!("error: vocab.000 is corrupt: {}", e);
                main_vocab = None;
            }
        }
    } else {
        main_vocab = None;
    }

    let script0 = script0::load_sci0_script(extract_path, script_id as u16)?;
    process_script0(&script0, selector_vocab, &kernel_vocab, &class_definitions, &main_vocab)
}

fn sci0_get_class_defs(extract_path: &str)-> Result<class_defs0::ClassDefinitions> {
    let vocab_996_data = std::fs::read(format!("{}/vocab.996", extract_path))?;
    let class_vocab = vocab::Vocab996::new(&vocab_996_data)?;
    Ok(class_defs0::ClassDefinitions::new(extract_path.to_string(), &class_vocab))
}

fn sci1_get_class_defs(extract_path: &str, load_externals: bool) -> Result<class_defs1::ClassDefinitions1> {
    let vocab_996_data = std::fs::read(format!("{}/vocab.996", extract_path))?;
    let class_vocab = vocab::Vocab996::new(&vocab_996_data)?;
    let class_extract_path = if load_externals { Some(extract_path) } else { None };
    class_defs1::ClassDefinitions1::new(class_extract_path, &class_vocab)
}

fn sci1_decode(extract_path: &str, script_id: u16, kernel_vocab: &kcalls::KernelVocab, selector_vocab: &vocab::Vocab997, no_externals: bool) -> Result<()> {
    let class_definitions = sci1_get_class_defs(extract_path, !no_externals)?;
    let script1 = script1::load_sci1_script(extract_path, script_id as u16)?;
    process_script1(&script1, selector_vocab, &kernel_vocab, &class_definitions)
}

fn get_selectors(extract_path: &str) -> Result<vocab::Vocab997> {
    let vocab_997_data = std::fs::read(format!("{}/vocab.997", extract_path))?;
    vocab::Vocab997::new(&vocab_997_data)
}

fn decode(extract_path: &str, script_id: u16, args: &Cli, no_externals: bool) -> Result<()> {
    let selector_vocab = get_selectors(extract_path)?;
    let kernel_vocab = kcalls::load_kernel_vocab(extract_path);

    if args.sci1 {
        sci1_decode(extract_path, script_id, &kernel_vocab, &selector_vocab, no_externals)
    } else {
        sci0_decode(extract_path, script_id, &kernel_vocab, &selector_vocab)
    }
}

fn sci0_print_classes(extract_path: &str) -> Result<()> {
    let class_definitions = sci0_get_class_defs(extract_path)?;
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

fn sci1_print_classes(extract_path: &str) -> Result<()> {
    let class_definitions = sci1_get_class_defs(extract_path, true)?;
    for class_id in class_definitions.get_class_ids() {
        match class_definitions.get_script_for_class_id(class_id) {
            Some(script) => {
                let class = script.get_items().iter().filter(|x| match x { script1::ObjectOrClass::Class(cl) => cl.get_class_id() == class_id, _ => false }).next();
                if let Some(class) = class {
                    let class = match class { script1::ObjectOrClass::Class(class) => class, _ => { unreachable!(); } };
                    let name = script.get_class_name(class);
                    println!("{} {}", class_id, name);
                } else {
                    println!("warning: class {} is supposed to exist in script, but could not be found", class_id);
                }
            },
            None => { println!("unable to load script for class {}, skipping", class_id); }
        }
    }
    Ok(())
}

fn recode(extract_path: &str, script_id: u16, args: &Cli) -> Result<()> {
    let selector_vocab = get_selectors(extract_path)?;
    let kernel_vocab = kcalls::load_kernel_vocab(extract_path);

    if args.sci1 {
        sci1_recode(extract_path, script_id, &kernel_vocab, &selector_vocab)
    } else {
        todo!("not implemented for sci0");
    }
}

fn sci1_recode(extract_path: &str, script_id: u16, kernel_vocab: &kcalls::KernelVocab, selector_vocab: &vocab::Vocab997) -> Result<()> {
    let class_definitions = sci1_get_class_defs(extract_path, true)?;
    let script1 = script1::load_sci1_script(extract_path, script_id as u16)?;
    recode_script1(&script1, selector_vocab, &kernel_vocab, &class_definitions)
}

fn recode_script1(script: &script1::Script1, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs1::ClassDefinitions1) -> Result<()> {
    let mut script_out = Vec::<u8>::new();
    let mut heap_out = Vec::<u8>::new();

    // Script: [header] [dispatches]
    //         [objclasses]: property selectors
    //                       method selector/offsets
    //         [fixups]

    // Heap: [header] [variables]
    //       [objclasses]: property values
    //       [strings]
    //       [fixups]

    // Script: Header
    let script_fixup_offset: u16 = 0;
    let script_node_ptr: u16 = 0;
    let script_far_text = script.has_far_text();
    script_out.write_u16::<LittleEndian>(script_fixup_offset)?;
    script_out.write_u16::<LittleEndian>(script_node_ptr)?;
    script_out.write_u16::<LittleEndian>(script_far_text)?;

    // Heap: header
    let heap_fixup_offset: u16 = 0;
    heap_out.write_u16::<LittleEndian>(heap_fixup_offset)?;

    // Heap: variables
    let locals = script.get_locals();
    heap_out.write_u16::<LittleEndian>(locals.len() as u16)?;
    for local in locals {
        heap_out.write_u16::<LittleEndian>(*local)?;
    }

    // Script: Dispatches
    let dispatches = script.get_dispatch_offsets();
    script_out.write_u16::<LittleEndian>(dispatches.len() as u16)?;
    for offset in dispatches {
        script_out.write_u16::<LittleEndian>(*offset)?;
    }

    // Object/classes
    for item in script.get_items() {
        match item {
            script1::ObjectOrClass::Object(_obj) => {
                todo!();
            },
            script1::ObjectOrClass::Class(class) => {
                // Write property values to the heap
                let properties = class.get_properties();
                for prop in properties {
                    heap_out.write_u16::<LittleEndian>(prop.value)?;
                }

                // Write selector id's to the script
                for prop in properties {
                    script_out.write_u16::<LittleEndian>(prop.selector)?;
                }
            }
        }

        // Methods
        let methods = item.get_methods();
        script_out.write_u16::<LittleEndian>(methods.len() as u16)?;
        for method in methods {
            script_out.write_u16::<LittleEndian>(method.index)?;
            script_out.write_u16::<LittleEndian>(method.offset)?;
        }
    }

    // Write code to the script
    for code in script.get_code() {
        let opcodes = &script.get_hunk()[code.get_offset() as usize..(code.get_offset() + code.get_length()) as usize];
        script_out.write(opcodes)?;
    }

    // TODO Write all strings to the heap!

    // TODO For now, copy all the script fixups - we need to construct
    // these
    let mut script_fixups = Vec::<u16>::new();
    for offset in script.get_script_fixup_offsets() {
        script_fixups.push(*offset);
    }

    // Script fixups
    let script_len = script_out.len();
    LittleEndian::write_u16(&mut script_out[0..2], script_len as u16);
    script_out.write_u16::<LittleEndian>(script_fixups.len() as u16)?;
    for fixup in script_fixups {
        script_out.write_u16::<LittleEndian>(fixup)?;
    }

    // TODO For now, copy all the heap fixups - we need to construct
    // these
    let mut heap_fixups = Vec::<u16>::new();
    for offset in script.get_heap_fixup_offsets() {
        heap_fixups.push(*offset);
    }

    // Heap fixups
    let heap_len = heap_out.len();
    LittleEndian::write_u16(&mut heap_out[0..2], heap_len as u16);
    heap_out.write_u16::<LittleEndian>(heap_fixups.len() as u16)?;
    for fixup in heap_fixups {
        heap_out.write_u16::<LittleEndian>(fixup)?;
    }

    let mut out_script_f = File::create("/tmp/script.bin")?;
    out_script_f.write(&script_out)?;

    let mut out_heap_f = File::create("/tmp/heap.bin")?;
    out_heap_f.write(&heap_out)?;
    Ok(())
}

fn main() -> Result<()> {
    let args = Cli::parse();
    let extract_path = args.in_dir.as_str();

    match args.command {
        CliCommand::Decode{ script_id } => {
            decode(extract_path, script_id, &args, args.no_externals)
        },
        CliCommand::Recode{ script_id } => {
            recode(extract_path, script_id, &args)
        },
        CliCommand::Selectors{ } => {
            print_selectors(extract_path)
        },
        CliCommand::Classes{ } => {
            if args.sci1 {
                sci1_print_classes(extract_path)
            } else {
                sci0_print_classes(extract_path)
            }
        },
    }
}
