use std::io::{Cursor, Seek, SeekFrom};
use anyhow::{anyhow, Result};
use byteorder::{LittleEndian, ReadBytesExt};

const OBJID_MAGIC: u16 = 0x1234; // magic value identifing a class/object
const SCRIPT_OBJECT: u16 = 0xffff; // magic value identifing this as an objecvt

const INDEX_OBJID: usize = 0; // -objID-
const INDEX_SIZE: usize = 1; // -size-
const INDEX_PROP_DICT: usize = 2; // -propDict- (only used in classes)
const INDEX_METH_DICT: usize = 3; // -methDict-
const _INDEX_CLASS_SCRIPT: usize = 4; // -classScript- (always overwritten)
const INDEX_SCRIPT: usize = 5; // -script-
const INDEX_SUPER_CLASS: usize = 6; // -super-
const _INDEX_INFO: usize = 7;

const NUM_SYSTEM_PROPERTIES: u16 = 8;

pub struct Method {
    pub index: u16,
    pub offset: u16
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
    let mut property_values = Vec::<u16>::with_capacity(NUM_SYSTEM_PROPERTIES.into());
    for _ in 0..NUM_SYSTEM_PROPERTIES {
        let value = rdr.read_u16::<LittleEndian>();
        if value.is_err() { return Ok(None); }
        property_values.push(value.unwrap());
    }

    // objID, must be magic value (-objid-)
    if property_values[INDEX_OBJID] != OBJID_MAGIC { return Ok(None); }
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

pub struct Script1 {
    script1: Script1Data,
    heap1: Heap1Data
}

struct Script1Data {
    hunk: Vec<u8>,
    dispatch_offsets: Vec<u16>
}

fn load_script1(script_data: &[u8]) -> Result<Script1Data> {
    // Script resource - this goes on the hunk
    let mut script = Cursor::new(&script_data);
    let fixup_offset  = script.read_u16::<LittleEndian>()? as usize;
    let script_node_ptr = script.read_u16::<LittleEndian>()? as usize;
    let far_text = script.read_u16::<LittleEndian>()?;

    // Dispatches
    let num_dispatch = script.read_u16::<LittleEndian>()?;
    let mut dispatch_offsets: Vec<u16> = Vec::new();
    for _ in 0..num_dispatch {
        let dispatch_offset = script.read_u16::<LittleEndian>()?;
        dispatch_offsets.push(dispatch_offset);
    }

    // Copy script to the hunk - this discards the fixups (which we don't need)
    let mut hunk: Vec<u8> = Vec::with_capacity(fixup_offset );
    hunk.extend_from_slice(&script_data[0..fixup_offset ]);
    // TODO fixups (do we need them?)

    script.seek(SeekFrom::Start(fixup_offset  as u64))?;
    let num_fixups = script.read_u16::<LittleEndian>()? as usize;
    for _ in 0..num_fixups {
        let _fixup = script.read_u16::<LittleEndian>()? as usize;
    }
    Ok(Script1Data{ hunk, dispatch_offsets } )
}

struct Heap1Data {
    variables: Vec<u16>,
    items: Vec<ObjectOrClass>
}

fn load_heap1(heap_data: &[u8], script1: &Script1Data) -> Result<Heap1Data> {
    let mut heap_curs = Cursor::new(heap_data);
    let fixup_offset = heap_curs.read_u16::<LittleEndian>()? as usize;
    let num_vars = heap_curs.read_u16::<LittleEndian>()? as usize;

    let mut variables = Vec::<u16>::new();
    for _ in 0..num_vars {
        let v = heap_curs.read_u16::<LittleEndian>()?;
        variables.push(v);
    }

    // Fixups
    heap_curs.seek(SeekFrom::Start(fixup_offset as u64))?;
    let num_fixups = heap_curs.read_u16::<LittleEndian>()? as usize;
    for _ in 0..num_fixups {
        let _fixup = heap_curs.read_u16::<LittleEndian>()? as usize;
        // println!("heap fixup {:x}", _fixup);
    }

    // Objects, directly after the variables
    let mut items = Vec::<ObjectOrClass>::new();
    heap_curs.seek(SeekFrom::Start(4 + (num_vars * 2) as u64))?;
    loop {
        let item = parse_object_class(&mut heap_curs, script1)?;
        match item {
            Some(item) => { items.push(item); },
            None => { break; }
        }
    }
    Ok(Heap1Data{ variables, items })
}

impl Script1 {
    pub fn new(script_data: &[u8], heap_data: &[u8]) -> Result<Script1> {
        // Note: script.nnn is loaded on the HUNK [ locked ]
        //       ^^ this contains the selector id's, methods, code...
        //       heap.nnn   is loaded on the HEAP [ variables ]
        //       ^ this contains the objects/classes, strings

        let script1 = load_script1(&script_data)?;
        let heap1 = load_heap1(&heap_data, &script1)?;
        Ok(Script1{ script1, heap1 })
    }

    pub fn get_dispatch_offsets(&self) -> &Vec<u16> {
        &self.script1.dispatch_offsets
    }

    pub fn get_code_base(&self) -> usize {
        // All CODE is on the HUNK - we have all offsets to the code because
        // these are either the dispatches or methods
        let mut code_offset = u16::MAX;
        for offset in &self.script1.dispatch_offsets {
            code_offset = std::cmp::min(code_offset, *offset);
        }

        // And combine this with the smallest method
        for item in &self.heap1.items {
            for method in item.get_methods() {
                code_offset = std::cmp::min(code_offset, method.offset);
            }
        }
        code_offset.into()
    }

    pub fn get_code(&self) -> &[u8] {
         &self.script1.hunk[self.get_code_base()..]
    }

    pub fn get_locals(&self) -> &Vec<u16> {
        &self.heap1.variables
    }

    pub fn get_items(&self) -> &Vec<ObjectOrClass> {
        &self.heap1.items
    }
}
