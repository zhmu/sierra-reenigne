use crate::sci_or_die::heap;

use anyhow::{anyhow, Result};

// Within SCI0, the objects have the following layout:
// -8   u16  object_id   hardcoded 0x1234
// -6   u16  <internal> local variable offset
// -4   u16  <internally used by sci0>
// -2   u16  number of variables (#v)
// 0    u16  variable values (times #v)
// [..] u16  (class only) variable sector id's (times #v)
// [..] u16  number of methods (#m)
// [..] u16  method selector id (times #m)
// [..] u16  always 0
// [..] u16  method code offset (times #m)
//
// The value in 'local variable offset' is filled out during loading

const ID_OBJECT: u16 = 0x1234;

const PROP_IDX_SPECIES: usize = 0;
pub const PROP_IDX_SUPERCLASS: usize = 1;
const PROP_IDX_INDEX: usize = 2;
pub const PROP_IDX_NAME: usize = 3;

const OFFSET_OBJ_MAGICID: usize = 0;
const OFFSET_OBJ_LOCALS_OFFSET: usize = 2;
const OFFSET_OBJ_VARIABLE_NUM: usize = 6;
const OFFSET_OBJ_VARIABLE: usize = 8;
const OFFSET_OBJ_METHOD_NUM: usize = 8;

pub const OBJECT_PREFIX_HACK: usize = 8;

pub const INFO_IS_CLONE: u16 = 0x0001;
pub const INFO_IS_CLASS: u16 = 0x8000;


pub struct Object0<'a> {
    heap: &'a heap::Heap,
    pub base: usize,
}

impl<'a> Object0<'a> {
    pub fn new(heap: &'a heap::Heap, base: u16) -> Result<Self> {
        let base = base as usize;
        if base < OBJECT_PREFIX_HACK {
            return Err(anyhow!("invalid object address {:x}", base));
        }
        let magic_value = heap.load_u16(get_objectid_offset(base));
        if magic_value != ID_OBJECT {
            return Err(anyhow!("corrupt magic {:x} for object {:x}", magic_value, base));
        }
        Ok(Self{ heap, base })
    }

    pub fn get_locals(&self) -> u16 {
        self.heap.load_u16(get_locals_offset(self.base))
    }

    pub fn get_species(&self) -> u16 {
        self.heap.load_u16(get_species_offset(self.base))
    }

    pub fn set_species(&self, heap: &mut heap::Heap, value: u16) {
        heap.store_u16(get_species_offset(self.base), value);
    }

    pub fn get_superclass(&self) -> u16 {
        self.heap.load_u16(get_superclass_offset(self.base))
    }

    pub fn set_superclass(&self, heap: &mut heap::Heap, value: u16) {
        heap.store_u16(get_superclass_offset(self.base), value);
    }

    pub fn get_info(&self) -> u16 {
        self.heap.load_u16(get_info_offset(self.base))
    }

    pub fn set_info(&self, heap: &mut heap::Heap, value: u16) {
        heap.store_u16(get_info_offset(self.base), value);
    }

    pub fn get_num_variables(&self) -> usize {
        self.heap.load_u16(get_num_selectors_offset(self.base)) as usize
    }

    pub fn get_num_methods(&self) -> usize {
        let info = self.get_info();
        let num_vars = self.get_num_variables();
        self.heap.load_u16(get_method_selector_offset(self.base, info, num_vars)) as usize
    }

    pub fn get_zero_offset(&self) -> usize {
        let info = self.get_info();
        let num_vars = self.get_num_variables();
        let method_selector_offset = get_method_selector_offset(self.base, info, num_vars);
        let num_methods = self.get_num_methods();
        method_selector_offset + 2 * num_methods + 2
    }

    pub fn get_variable_selector_id(&self, n: usize) -> u16 {
        let info = self.get_info();
        assert!((info & INFO_IS_CLASS) != 0);
        let num_vars = self.get_num_variables();
        self.heap.load_u16(get_selector_id_offset(self.base, num_vars, n))
    }

    pub fn get_variable_offset(&self, n: usize) -> usize {
        get_selector_value_offset(self.base, n)
    }

    pub fn get_variable_value(&self, index: usize) -> u16 {
        let offset = self.get_variable_offset(index);
        self.heap.load_u16(offset)
    }

    pub fn get_method_selector(&self, n: usize) -> u16 {
        let info = self.get_info();
        let num_vars = self.get_num_variables();
        let method_num_offset = get_method_selector_offset(self.base, info, num_vars);
        self.heap.load_u16(method_num_offset + 2 + (2 * n))
    }

    pub fn get_method_pointer_offset(&self, n: usize) -> usize {
        let info = self.get_info();
        let num_vars = self.get_num_variables();
        let num_methods = self.get_num_methods();
        let method_num_offset = get_method_selector_offset(self.base, info, num_vars);
        method_num_offset + 2 /* num */ + 2 /* zero */ + num_methods * 2 + (2 * n)
    }

    pub fn get_method_pointer(&self, n: usize) -> u16 {
        let method_offset = self.get_method_pointer_offset(n);
        self.heap.load_u16(method_offset)
    }
}

pub fn clone_object0(heap: &mut heap::Heap, source_object: u16, class_id: u16) -> Result<u16> {
    let object = Object0::new(heap, source_object)?;

    let info_val = object.get_info(); // elf. self.heap.load_u16(get_info_offset(object));
    let locals = object.get_locals(); // self.heap.load_u16(get_locals_offset(object));
    let species = object.get_species(); // self.heap.load_u16(get_species_offset(object));
    let super_class = object.get_superclass(); // self.heap.load_u16(get_superclass_offset(object));
    let num_vars = object.get_num_variables(); // self.heap.load_u16(get_num_selectors_offset(object)) as usize;
    let num_methods = object.get_num_methods(); // self.heap.load_u16(method_num_offset) as usize;
    let zero_offset = object.get_zero_offset(); // method_num_offset + 2 + num_methods * 2;
    assert_eq!(heap.load_u16(zero_offset), 0);

    let mut source_vars: Vec<u16> = Vec::new();
    for n in 0..num_vars {
        source_vars.push(object.get_variable_value(n));
    }

    let mut source_methods: Vec<(u16, u16)> = Vec::new();
    for n in 0..num_methods {
        let method_sel = object.get_method_selector(n);
        let method_offset = object.get_method_pointer(n);
        source_methods.push((method_sel, method_offset));
    }

    let object_size: u16 =
        (2 /* magic */ +
         2 /* local vars */ +
         2 /* sci0 internal var */ +
         2 /* #vars */ +
         2 * num_vars /* variable values */ +
         2 /* #methods */ +
         2 * num_methods /* method selectors */ +
         2 /* zero */ +
         2 * num_methods /* method offsets */
        ) as u16;

    // Determine length of new object
    let clone_offset = heap.allocate(heap::HeapItemType::Clone(source_object), object_size)?;
    let clone_object = clone_offset as usize + OBJECT_PREFIX_HACK;
    heap.store_u16(get_objectid_offset(clone_object), ID_OBJECT);
    heap.store_u16(get_locals_offset(clone_object), locals);
    heap.store_u16(get_species_offset(clone_object), species);
    let clone_info = (info_val & !INFO_IS_CLASS) | INFO_IS_CLONE;
    heap.store_u16(get_info_offset(clone_object), clone_info);
    if (info_val & INFO_IS_CLASS) != 0 {
        // XXX We should store pointers...
        heap.store_u16(get_superclass_offset(clone_object), class_id);
    } else {
        heap.store_u16(get_superclass_offset(clone_object), super_class);
    }
    heap.store_u16(get_num_selectors_offset(clone_object), num_vars as u16);

    // Skip internal variables
    for n in 4..num_vars {
        let selector_value = source_vars[n];
        heap.store_u16(get_selector_value_offset(clone_object, n), selector_value);
    }

    let clone_method_num_offset = get_method_selector_offset(clone_object, clone_info, num_vars);
    heap.store_u16(clone_method_num_offset, num_methods as u16);
    let clone_zero_offset = clone_method_num_offset + 2 + num_methods * 2;
    heap.store_u16(clone_zero_offset, 0);
    for n in 0..num_methods {
        let method_sel = source_methods[n].0;
        let method_offset = source_methods[n].1;

        let clone_method_offset = clone_method_num_offset + 2 + (2 * n);
        let clone_func_offset = clone_method_num_offset + 2 /* num */ + 2 /* zero */ + num_methods * 2 + (2 * n);
        heap.store_u16(clone_method_offset, method_sel);
        heap.store_u16(clone_func_offset, method_offset);
    }
    Ok(clone_object as u16)
}

fn get_objectid_offset(object: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_MAGICID
}

pub fn get_locals_offset(object: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_LOCALS_OFFSET
}

fn get_species_offset(object: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_VARIABLE + PROP_IDX_SPECIES * 2
}

fn get_superclass_offset(object: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_VARIABLE + PROP_IDX_SUPERCLASS * 2
}

fn get_info_offset(object: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_VARIABLE + PROP_IDX_INDEX * 2
}

fn get_num_selectors_offset(object: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_VARIABLE_NUM
}

fn get_selector_value_offset(object: usize, index: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_VARIABLE + index * 2
}

fn get_selector_id_offset(object: usize, num_selectors: usize, index: usize) -> usize {
    object - OBJECT_PREFIX_HACK + OFFSET_OBJ_VARIABLE + num_selectors * 2 + index * 2
}

fn get_method_selector_offset(object: usize, info_val: u16, num_vars: usize) -> usize {
    let mut method_num_offset = object - OBJECT_PREFIX_HACK + OFFSET_OBJ_METHOD_NUM + num_vars * 2;
    if (info_val & INFO_IS_CLASS) != 0 {
        method_num_offset += num_vars * 2; // skip selectors
    }
    method_num_offset
}
