use std::io::{Cursor, Seek, SeekFrom};
use anyhow::{anyhow, Result};
use byteorder::{LittleEndian, ReadBytesExt};
use std::str;

const OBJID_MAGIC: u16 = 0x1234; // magic value identifing a class/object
const SCRIPT_OBJECT: u16 = 0xffff; // magic value identifing this as an object

const INDEX_OBJID: usize = 0; // -objID-
const INDEX_SIZE: usize = 1; // -size-
const INDEX_PROP_DICT: usize = 2; // -propDict- (only used in classes)
const INDEX_METH_DICT: usize = 3; // -methDict-
const _INDEX_CLASS_SCRIPT: usize = 4; // -classScript- (always overwritten)
const INDEX_SCRIPT: usize = 5; // -script-
const INDEX_SUPER_CLASS: usize = 6; // -super-
const _INDEX_INFO: usize = 7;

const NUM_SYSTEM_PROPERTIES: u16 = 8;

const SELECTOR_NAME: u16 = 20; // TODO look this up

pub struct Method {
    pub index: u16,
    pub offset: u16,
}

pub struct Property {
    pub selector: u16,
    pub value: u16
}

pub struct Object1 {
    super_class: u16,
    methods: Vec<Method>,
    property_values: Vec<u16>,
}

impl Object1 {
    pub fn get_property_values(&self) -> &Vec<u16> {
        &self.property_values
    }
}

pub struct Class1 {
    class_id: u16,
    super_class: u16,
    methods: Vec<Method>,
    property: Vec<Property>,
}

impl ObjectOrClass {
    pub fn get_methods(&self) -> &Vec<Method> {
        match self {
            ObjectOrClass::Object(obj) => &obj.methods,
            ObjectOrClass::Class(class) => &class.methods
        }
    }

    pub fn get_mut_methods(&mut self) -> &mut Vec<Method> {
        match self {
            ObjectOrClass::Object(obj) => &mut obj.methods,
            ObjectOrClass::Class(class) => &mut class.methods
        }
    }

    pub fn get_super_class_id(&self) -> u16 {
        match self {
            ObjectOrClass::Object(obj) => obj.super_class,
            ObjectOrClass::Class(class) => class.super_class
        }
    }
}

impl Class1 {
    pub fn get_methods(&self) -> &Vec<Method> {
        &self.methods
    }

    pub fn get_properties(&self) -> &Vec<Property> {
        &self.property
    }

    pub fn get_class_id(&self) -> u16 {
        self.class_id
    }
}

pub enum ObjectOrClass {
    Object(Object1),
    Class(Class1)
}

fn parse_object_class(rdr: &mut Cursor<&[u8]>, script1: &Script1Data) -> Result<Option<ObjectOrClass>> {
    // Every object/class must contain at least all system properties, so fetch
    // these first
    let initial_position = rdr.position();
    let mut property_values = Vec::<u16>::with_capacity(NUM_SYSTEM_PROPERTIES.into());
    for _ in 0..NUM_SYSTEM_PROPERTIES {
        let value = rdr.read_u16::<LittleEndian>();
        if value.is_err() {
            rdr.seek(SeekFrom::Start(initial_position))?;
            return Ok(None);
        }
        property_values.push(value.unwrap());
    }

    // objID, must be magic value (-objid-)
    if property_values[INDEX_OBJID] != OBJID_MAGIC {
        rdr.seek(SeekFrom::Start(initial_position))?;
        return Ok(None);
    }
    let size = property_values[INDEX_SIZE];
    if size < NUM_SYSTEM_PROPERTIES { return Err(anyhow!("invalid -size- value of {}", size)); }

    // Read the remaining properties
    for _ in NUM_SYSTEM_PROPERTIES..size {
        let value = rdr.read_u16::<LittleEndian>()?;
        property_values.push(value);
    }

    let meth_dict = property_values[INDEX_METH_DICT];
    let script = property_values[INDEX_SCRIPT];
    let super_class = property_values[INDEX_SUPER_CLASS];

    // Read methods
    let mut hunk_rdr = Cursor::new(&script1.hunk[meth_dict as usize..]);
    let nr_meths = hunk_rdr.read_u16::<LittleEndian>()?;
    let mut methods = Vec::<Method>::with_capacity(nr_meths as usize);
    for _ in 0..nr_meths {
        let index = hunk_rdr.read_u16::<LittleEndian>()?;
        let offset = hunk_rdr.read_u16::<LittleEndian>()?;
        methods.push(Method{ index, offset });
    }

    if script == SCRIPT_OBJECT {
        // We're an object - no property dictionary to load (prop_dict is used here)
        let obj = Object1{ super_class, methods, property_values };
        return Ok(Some(ObjectOrClass::Object(obj)));
    }

    // We're a class - the prop_dict offset on the hunk contains the selectors in the proper order
    let mut property = Vec::<Property>::with_capacity(size as usize);

    // Read the property dictionary and fill out the properties values (which we already read)
    let prop_dict = property_values[INDEX_PROP_DICT];
    let mut hunk_rdr = Cursor::new(&script1.hunk[prop_dict as usize..(prop_dict + size * 2) as usize]);
    for n in 0..size as usize {
        let selector = hunk_rdr.read_u16::<LittleEndian>()?;
        property.push(Property{ selector, value: property_values[n] });
    }

    let class = Class1{ class_id: script, super_class, methods, property };
    Ok(Some(ObjectOrClass::Class(class)))
}

#[derive(Debug)]
pub enum Code {
    Method(u16, u16, usize, usize),
    Dispatch(u16, u16, usize),
    Final(u16),
}

impl Code {
    pub fn get_offset(&self) -> u16 {
        match self {
            Code::Method(offs, _, _, _) => *offs,
            Code::Dispatch(offs, _, _) => *offs,
            Code::Final(offs) => *offs,
        }
    }

    pub fn get_length(&self) -> u16 {
        match self {
            Code::Method(_, len, _, _) => *len,
            Code::Dispatch(_, len, _) => *len,
            Code::Final(_) => 0,
        }
    }
}

pub struct Script1 {
    script1: Script1Data,
    heap1: Heap1Data,
    code: Vec<Code>
}

pub enum Dispatch {
    Offset(u16),
    Invalid(u16)
}

struct Script1Data {
    hunk: Vec<u8>,
    dispatches: Vec<Dispatch>,
    fixup_offsets: Vec<u16>,
    far_text_flag: u16
}

fn read_u16_array(rdr: &mut Cursor<&[u8]>) -> Result<Vec<u16>> {
    let count = rdr.read_u16::<LittleEndian>()? as usize;
    let mut values = Vec::<u16>::with_capacity(count);
    for _ in 0..count {
        let fixup = rdr.read_u16::<LittleEndian>()?;
        values.push(fixup);
    }
    Ok(values)
}

fn load_script1(script_data: &[u8]) -> Result<Script1Data> {
    // Script resource - this goes on the hunk
    let mut script = Cursor::new(script_data);
    let fixup_offset = script.read_u16::<LittleEndian>()? as usize;
    let _script_node_ptr = script.read_u16::<LittleEndian>()? as usize;
    let far_text_flag = script.read_u16::<LittleEndian>()?;

    // Dispatches
    let dispatch_offsets = read_u16_array(&mut script)?;
    let mut dispatches = Vec::<Dispatch>::with_capacity(dispatch_offsets.len());
    for (n, offset) in dispatch_offsets.iter().enumerate() {
        // Note: QfG3 script.034 seems to contain dispatch offsets to items
        // on the heap (the uhuraTalker / Uhuru objects) - I have no idea
        // which purpose this serves
        let offs = *offset as usize;
        if offs >= (8 + dispatch_offsets.len() * 2) && offs < fixup_offset {
            dispatches.push(Dispatch::Offset(*offset));
        } else {
            println!("warning: encountered out-of-range dispatch {} offset {:x}", n, offs);
            dispatches.push(Dispatch::Invalid(*offset));
        }
    }

    // Copy script to the hunk - this discards the fixups (which are't part of
    // the script data)
    let mut hunk: Vec<u8> = Vec::with_capacity(fixup_offset );
    hunk.extend_from_slice(&script_data[0..fixup_offset ]);

    // Read fixups
    script.seek(SeekFrom::Start(fixup_offset  as u64))?;
    let fixup_offsets = read_u16_array(&mut script)?;
    Ok(Script1Data{ hunk, dispatches, fixup_offsets, far_text_flag } )
}

struct Heap1Data {
    data: Vec<u8>,
    data_offset: usize,
    variables: Vec<u16>,
    items: Vec<ObjectOrClass>,
    fixup_offsets: Vec<u16>,
}

fn load_heap1(heap_data: &[u8], script1: &Script1Data) -> Result<Heap1Data> {
    let mut heap_curs = Cursor::new(heap_data);
    let fixup_offset = heap_curs.read_u16::<LittleEndian>()? as usize;
    let variables = read_u16_array(&mut heap_curs)?;

    // Objects, directly after the variables
    let mut items = Vec::<ObjectOrClass>::new();
    loop {
        let item = parse_object_class(&mut heap_curs, script1)?;
        match item {
            Some(item) => { items.push(item); },
            None => { break; }
        }
    }

    // The current offset didn't contain an object/class - data starts here
    let data_offset = heap_curs.position() as usize;

    // Copy heap data
    let mut data: Vec<u8> = Vec::with_capacity(fixup_offset - data_offset);
    data.extend_from_slice(&heap_data[data_offset..fixup_offset]);

    // Fixups
    heap_curs.seek(SeekFrom::Start(fixup_offset as u64))?;
    let fixup_offsets = read_u16_array(&mut heap_curs)?;
    Ok(Heap1Data{ data, data_offset, variables, items, fixup_offsets })
}

impl Script1 {
    pub fn new(script_data: &[u8], heap_data: &[u8]) -> Result<Script1> {
        // Note: script.nnn is loaded on the HUNK [ locked ]
        //       ^^ this contains the selector id's, methods, code...
        //       heap.nnn   is loaded on the HEAP [ variables ]
        //       ^ this contains the objects/classes, strings

        let script1 = load_script1(&script_data)?;
        let heap1 = load_heap1(&heap_data, &script1)?;

        // Store all code offsets
        let mut code = Vec::<Code>::new();
        for (item_index, item) in heap1.items.iter().enumerate() {
            for (method_index, method) in item.get_methods().iter().enumerate() {
                code.push(Code::Method(method.offset, 0, item_index, method_index));
            }
        }

        // Add dispatches
        for (n, d) in script1.dispatches.iter().enumerate() {
            if let Dispatch::Offset(offs) = d {
                code.push(Code::Dispatch(*offs, 0, n));
            }
        }

        // Add final offset
        code.push(Code::Final(script1.hunk.len() as u16));
        code.sort_by(|a, b| a.get_offset().cmp(&b.get_offset()));

        for n in 0..(code.len() - 1) {
            let next_offset = code[n + 1].get_offset();
            let new_offset = match code[n] {
                Code::Method(offs, _, item_index, method_index) => { Code::Method(offs, next_offset - offs, item_index, method_index) },
                Code::Dispatch(offs, _, index) => { Code::Dispatch(offs, next_offset - offs, index) },
                _ => { unreachable!() }
            };
            code[n] = new_offset;
        }
        Ok(Script1{ script1, heap1, code })
    }

    pub fn has_far_text(&self) -> u16 {
        self.script1.far_text_flag
    }

    pub fn get_dispatches(&self) -> &Vec<Dispatch> {
        &self.script1.dispatches
    }

    pub fn get_script_fixup_offsets(&self) -> &Vec<u16> {
        &self.script1.fixup_offsets
    }

    pub fn get_heap_fixup_offsets(&self) -> &Vec<u16> {
        &self.heap1.fixup_offsets
    }

    pub fn get_code(&self) -> &Vec<Code> {
        &self.code
    }

    pub fn get_data(&self) -> &[u8] {
        &self.heap1.data
    }

    pub fn get_hunk(&self) -> &[u8] {
         &self.script1.hunk
    }

    pub fn get_locals(&self) -> &Vec<u16> {
        &self.heap1.variables
    }

    pub fn get_items(&self) -> &Vec<ObjectOrClass> {
        &self.heap1.items
    }

    pub fn get_string(&self, offset: usize) -> &str {
        assert!(offset >= self.heap1.data_offset);
        // strings are on the heap
        let data = &self.heap1.data[offset - self.heap1.data_offset..];
        let nul_byte_end = data.iter()
            .position(|&c| c == b'\0')
            .unwrap_or(data.len());
        str::from_utf8(&data[0..nul_byte_end]).unwrap_or("<corrupt>")
    }

    pub fn get_class_name(&self, class: &Class1) -> &str {
        let props = class.get_properties();
        if let Some(prop) = props.iter().find(|&p| p.selector == SELECTOR_NAME) {
           self.get_string(prop.value.into())
        } else {
            "???"
        }
    }

    pub fn get_object_name(&self, obj: &Object1, super_class: &Class1) -> &str {
        let prop_vals = obj.get_property_values();
        let superclass_props = super_class.get_properties();
        if let Some(n) = superclass_props.iter().position(|p| p.selector == SELECTOR_NAME) {
           self.get_string(prop_vals[n].into())
        } else {
            "???"
        }
    }
}

pub fn load_sci1_script(extract_path: &str, script_id: u16) -> Result<Script1> {
    let script_data = std::fs::read(format!("{}/script.{:03}", extract_path, script_id))?;
    let heap_data = std::fs::read(format!("{}/heap.{:03}", extract_path, script_id))?;
    println!(">> loading script {}", script_id);
    Script1::new(&script_data, &heap_data)
}
