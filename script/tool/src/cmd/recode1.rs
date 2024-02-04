use crate::sci1::{script1, class_defs1};
use crate::{kcalls, vocab};
use anyhow::Result;
use byteorder::{ByteOrder, LittleEndian, WriteBytesExt};

use std::fs::File;
use std::io::Write;

pub fn recode_script1(script: &script1::Script1, selector_vocab: &vocab::Vocab997, kernel_vocab: &kcalls::KernelVocab, class_definitions: &class_defs1::ClassDefinitions1) -> Result<()> {
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
    let dispatches = script.get_dispatches();
    script_out.write_u16::<LittleEndian>(dispatches.len() as u16)?;
    for dispatch in dispatches {
        let offset = match dispatch {
            script1::Dispatch::Offset(offs) => *offs,
            script1::Dispatch::Invalid(offs) => *offs,
            script1::Dispatch::Item(index) => { script.get_items()[*index].get_offset() }
        };
        script_out.write_u16::<LittleEndian>(offset)?;
    }

    // Object/classes
    for item in script.get_items() {
        match item {
            script1::ObjectOrClass::Object(obj) => {
                // Write property values to the heap
                let properties = obj.get_property_values();
                for value in properties {
                    heap_out.write_u16::<LittleEndian>(*value)?;
                }
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

    // Write data to heap
    heap_out.write(script.get_data())?;

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

