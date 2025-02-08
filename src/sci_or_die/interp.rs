use crate::{
    sciscript::{
        kcalls,
        disassemble,
        vocab
    },
    scires::resource,
    sci_or_die::{heap, resman, heap_object, kernel, ui, graphics},
};
use anyhow::{anyhow, Result};

const DEBUG_SEND: bool = false;
const DEBUG_SELECTOR_LOOKUP: bool = DEBUG_SEND;
const DEBUG_REST: bool = false;
const DEBUG_LOAD_SCRIPT: bool = false;

const STACK_SIZE: usize = 4096;
const SAVE_DIR_LENGTH: usize = 16;

const NO_CLASS_ID: u16 = 0xffff;
const SEL_PLAY: u16 = 42; // TODO maybe we need to look this up?

const SCI0_BLOCKTYPE_TERMINATOR: u16 = 0;
const SCI0_BLOCKTYPE_OBJECT: u16 = 1;
const SCI0_BLOCKTYPE_CLASS: u16 = 6;
const SCI0_BLOCKTYPE_EXPORTS: u16 = 7;
const SCI0_BLOCKTYPE_POINTERS: u16 = 8;
const SCI0_BLOCKTYPE_LOCALS: u16 = 10;

pub struct LoadedScript {
    script_id: u16,
    pub base: usize,
    length: usize,
    locals_offset: Option<usize>,
    exports_offset: Option<usize>,
    //
    symbols: Vec<(u16, String)>,
}

#[derive(Debug)]
struct LoadedClass {
    class_id: u16,
    script_id: u16,
    offset: u16,
}

pub struct Registers {
    pub acc: u16,
    prev: u16,
    object: u16,
    pc: u16,
    sp: u16,
    rest: u16,
    global_vars: u16,
    local_vars: Option<u16>,
    parm_vars: Option<u16>,
    temp_vars: Option<u16>,
}

pub struct List {
    pub items: Vec<u16>,
}

impl List {
    pub fn new() -> Self {
        Self{ items: Vec::new() }
    }
}

pub struct Node {
    pub list: u16,
    pub key: u16,
    pub value: u16,
}

impl Node {
    pub fn new(key: u16, value: u16) -> Self {
        Self{ list: 0, key, value }
    }
}

pub enum HandleContent {
    ListHandle(List),
    NodeHandle(Node),
}

pub struct Handle {
    pub id: u16,
    pub content: HandleContent,
}

pub struct Interpreter<'a> {
    pub heap: heap::Heap,
    pub ui: &'a mut ui::UI,
    pub resman: &'a mut resman::ResourceManager,
    class_table: vocab::Vocab996,
    selector_table: vocab::Vocab997,
    pub gfx: graphics::State,
    pub kvocab: kcalls::KernelVocab,
    pub regs: Registers,
    pub scripts: Vec<LoadedScript>,
    classes: Vec<LoadedClass>,
    pub handles: Vec<Handle>,
    next_handle: u16,
    pub save_dir_offset: u16,
    stack_base: u16,
    pub time: u16,
    pub terminating: bool,
}

enum SelectorLookup {
    Variable(usize),
    Method(usize),
}

impl<'a> Interpreter<'a> {
    pub fn new(ui: &'a mut ui::UI, resman: &'a mut resman::ResourceManager, class_table: vocab::Vocab996, selector_table: vocab::Vocab997, kvocab: kcalls::KernelVocab) -> Result<Self> {

        let mut heap = heap::Heap::new();
        let save_dir_offset = heap.allocate(heap::HeapItemType::SaveDirectory, SAVE_DIR_LENGTH as u16)?;
        let stack_base = heap.allocate(heap::HeapItemType::Stack, STACK_SIZE as u16)?;

        let regs = Registers{ acc: 0, prev: 0, object: u16::MAX, pc: u16::MAX, sp: stack_base, rest: 0, global_vars: u16::MAX,  local_vars: None, parm_vars: None, temp_vars: None };

        Ok(Self{ ui, resman, heap, class_table, selector_table, kvocab, scripts: Vec::new(), classes: Vec::new(), handles: Vec::new(), next_handle: 1, regs, save_dir_offset, stack_base, time: 0, gfx: graphics::State::new(), terminating: false })
    }

    pub fn load_script(&mut self, num: u16) -> Result<()> {
        if DEBUG_LOAD_SCRIPT {
            println!("load_script: {}", num);
        }
        let script_res = self.resman.get(resource::ResourceID{ rtype: resource::ResourceType::Script, num });

        let script_base = self.heap.allocate(heap::HeapItemType::Script(num), script_res.data.len() as u16)? as usize;
        self.heap.data_mut()[script_base..script_base + script_res.data.len()].copy_from_slice(&script_res.data);

        let mut loaded_script = LoadedScript{ script_id: num, base: script_base, length: script_res.data.len(), locals_offset: None, exports_offset: None, symbols: Vec::new() };

        let mut object_offsets = Vec::new();
        let mut offset: usize = 0;
        while offset < script_res.data.len() {
            let block_type = self.heap.load_u16(script_base + offset);
            if block_type == SCI0_BLOCKTYPE_TERMINATOR { break; }
            let block_size = self.heap.load_u16(script_base + offset + 2) as usize;
            let block_data_offset = script_base + offset + 4;

            if DEBUG_LOAD_SCRIPT {
                println!(">> block_type {} block_size {}", block_type, block_size);
            }
            match block_type {
                SCI0_BLOCKTYPE_OBJECT | SCI0_BLOCKTYPE_CLASS => {
                    let object = heap_object::Object0::new(&self.heap, (block_data_offset + heap_object::OBJECT_PREFIX_HACK) as u16)?;
                    object_offsets.push(object.base as u16);

                    // Collect method offsets for relocation
                    let mut method_offsets: Vec<usize> = Vec::new();
                    let num_methods = object.get_num_methods();
                    for n in 0..num_methods {
                        method_offsets.push(object.get_method_pointer_offset(n) as usize);
                    }

                    // Apply relocations to method offsets
                    for offset in &method_offsets {
                        let offset = *offset as usize;
                        let mut value = self.heap.load_u16(offset);
                        value += script_base as u16;
                        self.heap.store_u16(offset, value);
                    }

                },
                SCI0_BLOCKTYPE_EXPORTS => {
                    loaded_script.exports_offset = Some(block_data_offset);
                },
                SCI0_BLOCKTYPE_POINTERS => {
                    let num_relocs = self.heap.load_u16(block_data_offset) as usize;
                    for n in 0..num_relocs {
                        let offset = self.heap.load_u16(block_data_offset + 2 + n * 2) as usize;

                        let mut value = self.heap.load_u16(script_base + offset);
                        value += script_base as u16;
                        self.heap.store_u16(script_base + offset, value);
                    }
                },
                SCI0_BLOCKTYPE_LOCALS => {
                    loaded_script.locals_offset = Some(block_data_offset);
                },
                _ => {},
            };

            offset += block_size;
        }

        // Register objects/classes
        for obj_offset in &object_offsets {
            let object = heap_object::Object0::new(&self.heap, *obj_offset)?;

            let info = object.get_info();
            let species_id = object.get_species();
            let super_class_id = object.get_superclass();
            if super_class_id != NO_CLASS_ID {
                if let Some(super_script_id) = self.class_table.get_script(super_class_id) {
                    if super_script_id != num && !self.scripts.iter().any(|s| s.script_id == super_script_id) {
                        if DEBUG_LOAD_SCRIPT {
                            log::info!("loading script {} for class id {}", super_script_id, super_class_id);
                        }
                        self.load_script(super_script_id)?;
                    }
                } else {
                    return Err(anyhow!("unable to locate script for class id {}", super_class_id));
                }
            }

            // Update locals pointer
            if let Some(locals_offset) = loaded_script.locals_offset {
                let offset = heap_object::get_locals_offset(*obj_offset as usize);
                assert_eq!(self.heap.load_u16(offset), 0);
                let value = locals_offset;
                self.heap.store_u16(offset, value as u16);
            }

            // Register the object/class
            if (info & heap_object::INFO_IS_CLASS) != 0 {
                let lc = LoadedClass{
                    class_id: species_id,
                    script_id: num,
                    offset: obj_offset - script_base as u16,
                };
                self.classes.push(lc);
            } else {
            }
        }

        if num == 0 {
            self.regs.global_vars = loaded_script.locals_offset.unwrap() as u16;
        }

        // Create symbol list
        for obj_offset in &object_offsets {
            let object = heap_object::Object0::new(&self.heap, *obj_offset)?;
            let object_name = self.determine_object_name(*obj_offset as u16);
            loaded_script.symbols.push((*obj_offset, object_name.clone()));

            let num_methods = object.get_num_methods();
            for n in 0..num_methods {
                let method_sel = object.get_method_selector(n);
                let method_offset = object.get_method_pointer(n);

                let name = format!("{}::{}",
                    object_name.clone(),
                    self.selector_table.get_string(method_sel as usize).unwrap_or(&"<unknown>".to_string()));

                loaded_script.symbols.push((method_offset, name));
            }
        }

        if let Some(exports_offset) = loaded_script.exports_offset {
            let num_entries = self.heap.load_u16(exports_offset) as usize;
            for n in 0..num_entries {
                let offset = loaded_script.base + self.heap.load_u16(exports_offset + 2 + (n * 2)) as usize;
                let name = format!("export_s{}_{}", num, n);
                loaded_script.symbols.push((offset as u16, name));
            }
        }
        loaded_script.symbols.sort();
        if DEBUG_LOAD_SCRIPT {
            println!("load_script: loaded {} at {:x} .. {:x}",
                num, loaded_script.base, loaded_script.base + loaded_script.length);
            for (offset, symbol) in &loaded_script.symbols {
                println!("  {:04x} {}", offset, symbol);
            }
        }

        self.scripts.push(loaded_script);
        Ok(())
    }

    pub fn info(&self) {
        println!("Loaded {} script(s)", self.scripts.len());
        println!("Global vars offset: 0x${:x}", self.regs.global_vars);
        self.heap.info();
    }

    pub fn debug_dump(&self) {
        println!("debug dump\n");
        println!("acc {:04x} object {:04x}", self.regs.acc, self.regs.object);
        self.heap.info();
    }

    // Runs the pmachine until a return instruction is encountered
    fn run_pmachine(&mut self) -> Result<()> {
        println!("run_pmachine: object {:04x} pc {:04x} sp {:04x} local_vars {:04x?} parm_vars {:04x?} temp_vars {:04x?}",
            self.regs.object, self.regs.pc, self.regs.sp, self.regs.local_vars, self.regs.parm_vars, self.regs.temp_vars);

        while !self.terminating {
            let mut disasm = disassemble::Disassembler::new(self.regs.pc as usize, &self.heap.data()[self.regs.pc as usize..]);
            if let Some(instr) = disasm.next() {
                let mut bytes = String::new();
                for byte in instr.bytes {
                    bytes += &format!("{:02x}", byte);
                }

                let location = self.resolve_pc();
                let tos = self.heap.load_u16((self.regs.sp - 2) as usize);
                let p1 = if let Some(p) = self.regs.parm_vars {
                    self.heap.load_u16(p as usize + 2)
                } else {
                    u16::MAX
                };
                println!("{:04x}: [acc {:04x}] [sp {:04x}] [tos {:04x}] [p1 {:04x}] {:20} {:8} {:8} {}", instr.offset, self.regs.acc, self.regs.sp, tos, p1, location, bytes, instr.opcode.name, instr.args.iter().map(|v| format!("{}", v)).collect::<Vec<_>>().join(" "));
            } else {
                println!("{:04x}: {:02x} ???", self.regs.pc, self.heap.data()[self.regs.pc as usize]);
            }

            let opcode = self.load_pc_u8();

            match opcode {
                0x00 | 0x01 => { // bnot
                    self.regs.acc = self.regs.acc ^ 0xffff;
                },
                0x02 => { // add
                    self.regs.acc = self.regs.acc.overflowing_add(self.pop()?).0;
                },
                0x04 => { // sub
                    self.regs.acc = self.pop()?.overflowing_sub(self.regs.acc).0;
                },
                0x06 => { // mul
                    self.regs.acc = self.regs.acc.overflowing_mul(self.pop()?).0;
                },
                0x08 => { // div
                    if self.regs.acc != 0 {
                        self.regs.acc = self.pop()?.overflowing_div(self.regs.acc).0;
                    }
                },
                0x0a => { // mod
                    if self.regs.acc != 0 {
                        self.regs.acc = self.pop()? % self.regs.acc;
                    }
                },
                0x0c => { // shr
                    self.regs.acc = self.pop()? >> self.regs.acc;
                },
                0x0e => { // shl
                    self.regs.acc = self.pop()? << self.regs.acc;
                },
                0x10 => { // xor
                    self.regs.acc = self.regs.acc ^ self.pop()?;
                },
                0x12 => { // and
                    self.regs.acc = self.regs.acc & self.pop()?;
                },
                0x14 => { // or
                    self.regs.acc = self.regs.acc | self.pop()?;
                },
                0x16 => { // neg
                    self.regs.acc = self.regs.acc ^ 0x8000; /* TODO: is this correct */
                },
                0x18 => { // not
                    self.regs.acc = if self.regs.acc == 0 { 1 } else { 0 };
                },
                0x1a => { // eq?
                    self.regs.prev = self.regs.acc;
                    self.regs.acc = if self.pop()? == self.regs.acc {
                        1
                    } else {
                        0
                    };
                },
                0x1c => { // ne?
                    self.regs.prev = self.regs.acc;
                    self.regs.acc = if self.pop()? != self.regs.acc {
                        1
                    } else {
                        0
                    };
                },
                0x1e => { // gt?
                    self.regs.prev = self.regs.acc;
                    self.regs.acc = if (self.pop()? as i16) > (self.regs.acc as i16) {
                        1
                    } else {
                        0
                    };
                },
                0x20 => { // ge?
                    self.regs.prev = self.regs.acc;
                    self.regs.acc = if (self.pop()? as i16) >= (self.regs.acc as i16) {
                        1
                    } else {
                        0
                    };
                },
                0x22 => { // lt?
                    self.regs.prev = self.regs.acc;
                    self.regs.acc = if (self.pop()? as i16) < (self.regs.acc as i16) {
                        1
                    } else {
                        0
                    };
                },
                0x24 => { // le?
                    self.regs.prev = self.regs.acc;
                    self.regs.acc = if (self.pop()? as i16) <= (self.regs.acc as i16) {
                        1
                    } else {
                        0
                    };
                },
                0x26 => { // ugt?
                    self.regs.prev = self.regs.acc; // TODO is this correct?
                    self.regs.acc = if self.pop()? > self.regs.acc {
                        1
                    } else {
                        0
                    };
                },
                0x28 => { // uge?
                    self.regs.prev = self.regs.acc; // TODO is this correct?
                    self.regs.acc = if self.pop()? >= self.regs.acc {
                        1
                    } else {
                        0
                    };
                },
                0x2a => { // ult?
                    self.regs.prev = self.regs.acc; // TODO is this correct?
                    self.regs.acc = if self.pop()? < self.regs.acc {
                        1
                    } else {
                        0
                    };
                },
                0x2c => { // ule?
                    self.regs.prev = self.regs.acc; // TODO is this correct?
                    self.regs.acc = if self.pop()? <= self.regs.acc {
                        1
                    } else {
                        0
                    };
                },
                0x2e | 0x2f => { // bt
                    let relpos = if opcode == 0x2e {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    if self.regs.acc != 0 {
                        self.regs.pc = self.regs.pc.overflowing_add(relpos).0;
                    }
                },
                0x30 | 0x31 => { // bnt
                    let relpos = if opcode == 0x30 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    if self.regs.acc == 0 {
                        self.regs.pc = self.regs.pc.overflowing_add(relpos).0;
                    }
                },
                0x32 | 0x33 => { // jmp
                    let relpos = if opcode == 0x32 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    self.regs.pc = self.regs.pc.overflowing_add(relpos).0;
                },
                0x34 | 0x35 => { // ldi
                    self.regs.acc = if opcode == 0x34 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_s8()
                    };
                },
                0x36 => { // push
                    self.push(self.regs.acc)?;
                },
                0x38 | 0x39 => { // pushi
                    let v = if opcode == 0x38 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_s8()
                    };
                    self.push(v)?;
                },
                0x3a => { // toss
                    self.pop()?;
                },
                0x3c => { // dup
                    let tos = self.heap.load_u16((self.regs.sp - 2) as usize);
                    self.push(tos)?;
                },
                0x3e | 0x3f => { // link
                    let size = if opcode == 0x3e {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    // Note: SCI1 seems to use sp+2 here ??
                    self.regs.temp_vars = Some(self.regs.sp);
                    for n in 0..size as usize {
                        self.heap.store_u16(self.regs.sp as usize + n * 2, 0xfade);
                    }
                    self.regs.sp = self.regs.sp + size * 2;
                    self.verify_stack()?;
                    println!(">> link: temp_vars now {:x?}, sp {:x}", self.regs.temp_vars, self.regs.sp);
                },
                0x40 | 0x41 => { // call
                    let relpos = if opcode == 0x40 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_s8()
                    };
                    let frame_size = self.load_pc_u8() as u16;
                    println!("CALL {:x} {:x} - curious if this is okay", relpos, frame_size);
                    let old_pc = self.regs.pc;
                    let old_parm = self.regs.parm_vars;
                    let old_temp = self.regs.temp_vars;
                    let parm_vars = self.regs.sp - frame_size - self.regs.rest;
                    self.regs.parm_vars = Some(parm_vars);

                    // Update parameter count
                    let mut v = self.heap.load_u16(parm_vars as usize);
                    v += self.regs.rest / 2;
                    self.heap.store_u16(parm_vars as usize, v);
                    self.regs.rest = 0;

                    // Handle the call
                    self.regs.pc = self.regs.pc.overflowing_add(relpos).0;
                    self.run_pmachine()?;

                    // Restore registers
                    self.regs.sp = parm_vars - 2;
                    self.regs.parm_vars = old_parm;
                    self.regs.temp_vars = old_temp;
                    self.regs.pc = old_pc;
                },
                0x42 | 0x43 => { // callk
                    let nr = if opcode == 0x42 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    // TODO: &rest could be a later SCI0 addition ...
                    let nr_parms = self.load_pc_u8() as u16;
                    self.regs.sp = self.regs.sp - (nr_parms + 2 + self.regs.rest);

                    // Update parameter count
                    let mut v = self.heap.load_u16(self.regs.sp as usize);
                    v += self.regs.rest / 2;
                    self.heap.store_u16(self.regs.sp as usize, v);
                    self.regs.rest = 0;

                    // Gather parameters and handle kernel function
                    let mut args = Vec::new();
                    let nr_parms = nr_parms + 2; // argument count
                    for n in (0..nr_parms).step_by(2) {
                        let value = self.heap.load_u16((self.regs.sp + n) as usize);
                        args.push(value);
                    }
                    kernel::handle_kcall(self, nr, &args)?;

                    // Restore registers
                    // XXX We need to restore sp ??
                }
                0x44 | 0x45 => { // callb,
                    let disp_index = if opcode == 0x44 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let nr_parms = self.load_pc_u8() as u16;
                    self.call_external_script(0, disp_index, nr_parms)?;
                },
                0x46 | 0x47 => { // calle
                    let script_num;
                    let disp_index;
                    if opcode == 0x46 {
                        script_num = self.load_pc_u16();
                        disp_index = self.load_pc_u16();
                    } else {
                        script_num = self.load_pc_u8() as u16;
                        disp_index = self.load_pc_u8() as u16;
                    };
                    let nr_parms = self.load_pc_u8() as u16;
                    self.call_external_script(script_num, disp_index, nr_parms)?;
                },
                0x48 => { // ret
                    return Ok(());
                },
                0x49 | 0x4a => { // send
                    let nr_parms = self.load_pc_u8() as u16;
                    self.handle_send(self.regs.acc, self.regs.acc, nr_parms)?;
                },
                0x50 | 0x51 => { // class
                    let class_id = if opcode == 0x50 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    self.regs.acc = self.get_class_offset(class_id)? as u16;
                },
                0x54 => { // self
                    let nr_parms = self.load_pc_u8() as u16;
                    self.handle_send(self.regs.object, self.regs.object, nr_parms)?;
                },
                0x56 | 0x57 => { // super
                    let class_id = if opcode == 0x56 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let nr_parms = self.load_pc_u8() as u16;
                    let class = self.get_class_offset(class_id)? as u16;
                    self.handle_send(self.regs.object, class, nr_parms)?;
                },
                0x59 => { // &rest
                    let param_index = self.load_pc_u8() as u16;

                    let parm_vars = self.regs.parm_vars.expect("&rest without local parms");

                    // Argument count is first value on parameter stack
                    let argc = self.heap.load_u16(parm_vars as usize);
                    if DEBUG_REST {
                        println!("&rest: current argc {}", argc);
                    }
                    for n in 0..argc {
                        let value = self.heap.load_u16((parm_vars + n) as usize);
                        if DEBUG_REST {
                            println!("  arg {}: 0x{:x} {}", n, value, value);
                        }
                    }

                    let extra_params = if argc >= param_index { (argc - param_index) + 1 } else { 0 };
                    if DEBUG_REST {
                        println!("argc {} param_index {} -> extra_params {}", argc, param_index, extra_params);
                    }
                    for n in 0..extra_params {
                        let value = self.heap.load_u16((parm_vars + (param_index + n) * 2) as usize);
                        if DEBUG_REST {
                            println!("  adding arg {}: 0x{:x} {}", n, value, value);
                        }
                        self.push(value)?;
                    }
                    self.regs.rest += extra_params * 2;
                    if DEBUG_REST {
                        println!(">>> &rest -> rest reg now {}", self.regs.rest);
                        println!("dumping last few args...");
                        for n in 1..10 {
                            let sp_mod = n * 2;
                            let value = self.heap.load_u16((self.regs.sp - sp_mod) as usize);
                            println!("  sp-{}: arg {}: {} {:x}", sp_mod, n, value, value);
                        }
                    }
                },
                0x5a | 0x5b => { // lea
                    let typ;
                    let index;
                    if opcode == 0x5a {
                        typ = self.load_pc_u16();
                        index = self.load_pc_u16();
                    } else {
                        typ = self.load_pc_u8() as u16;
                        index = self.load_pc_u8() as u16;
                    }

                    let vtype = (typ >> 1) & 3;
                    let acc_index = (typ & 0x10) != 0;
                    let mut address = match vtype {
                        0 => self.regs.global_vars,
                        1 => self.regs.local_vars.expect("lea without local_vars"),
                        2 => self.regs.temp_vars.expect("lea without temp_vars"),
                        3 => self.regs.parm_vars.expect("lea without parm_vars"),
                        _ => unreachable!()
                    };
                    if acc_index {
                        address = address.overflowing_add(self.regs.acc * 2).0;
                    }
                    self.regs.acc = address.overflowing_add(index * 2).0;
                },
                0x5c => { // selfid
                    self.regs.acc = self.regs.object;
                },
                0x60 => { // pprev
                    self.push(self.regs.prev)?;
                },
                0x62 | 0x63 => { // pToa
                    let offset = if opcode == 0x62 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let value = self.heap.load_u16(self.regs.object as usize + offset as usize);
                    self.regs.acc = value;
                },
                0x64 | 0x65 => { // aTop
                    let offset = if opcode == 0x64 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    self.heap.store_u16(self.regs.object as usize + offset as usize, self.regs.acc);
                },
                0x66 | 0x67 => { // pTos
                    let offset = if opcode == 0x66 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let value = self.heap.load_u16(self.regs.object as usize + offset as usize);
                    self.push(value)?;
                },
                0x68 | 0x69 => { // sTop
                    let offset = if opcode == 0x68 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let value = self.pop()?;
                    self.heap.store_u16(self.regs.object as usize + offset as usize, value);
                },
                0x6a | 0x6b => { // ipToa
                    let offset = if opcode == 0x6a {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let prop_offset = self.regs.object as usize + offset as usize;
                    let value = self.heap.load_u16(prop_offset).overflowing_add(1).0;
                    self.heap.store_u16(prop_offset, value);
                    self.regs.acc = value;
                },
                0x6c | 0x6d => { // dpToa
                    let offset = if opcode == 0x6c {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let prop_offset = self.regs.object as usize + offset as usize;
                    let value = self.heap.load_u16(prop_offset).overflowing_sub(1).0;
                    self.heap.store_u16(prop_offset, value);
                    self.regs.acc = value;
                },
                0x6e | 0x6f => { // ipTos
                    let offset = if opcode == 0x6e {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let prop_offset = self.regs.object as usize + offset as usize;
                    let value = self.heap.load_u16(prop_offset).overflowing_add(1).0;
                    self.heap.store_u16(prop_offset, value);
                    self.push(value)?;
                },
                0x70 | 0x71 => { // dpTos
                    let offset = if opcode == 0x70 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    let prop_offset = self.regs.object as usize + offset as usize;
                    let value = self.heap.load_u16(prop_offset).overflowing_sub(1).0;
                    self.heap.store_u16(prop_offset, value);
                    self.push(value)?;
                },
                0x72 | 0x73 => { // lofsa
                    let offset = if opcode == 0x72 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    println!("lofsa: pc {:x}, offset {:x} -> {:x}",
                        self.regs.pc, offset,
                        self.regs.pc.overflowing_add(offset).0
                    );
                    self.regs.acc = self.regs.pc.overflowing_add(offset).0;
                },
                0x74 | 0x75 => { // lofss
                    let offset = if opcode == 0x72 {
                        self.load_pc_u16()
                    } else {
                        self.load_pc_u8() as u16
                    };
                    self.push(self.regs.pc.overflowing_add(offset).0)?;
                },
                0x76 => { // push0
                    self.push(0)?;
                },
                0x78 => { // push1
                    self.push(1)?;
                },
                0x7a => { // push2
                    self.push(2)?;
                },
                0x7c => { // pushself
                    self.push(self.regs.object)?;
                },
                opcode @ 0x80..=0xff => {
                    // [ls+-]    [as]    [gltp] i?
                    // oper    on_stack  typ    acc_modifier
                    let is8bit = (opcode & 1) != 0;
                    let typ = (opcode >> 1) & 3;
                    let acc_modifier = (opcode & 0x10) != 0;
                    let on_stack = (opcode & 0x8) != 0;
                    let mut oper = (opcode >> 5) & 3;
                    let index = if is8bit {
                        self.load_pc_u8() as u16
                    } else {
                        self.load_pc_u16()
                    };

                    let mut var_offset;
                    match typ {
                        0 => { // global
                            var_offset = self.regs.global_vars.overflowing_add(index * 2).0;
                        },
                        1 => { // local
                            var_offset = self.regs.local_vars.expect("opcode without local_vars").overflowing_add(index * 2).0;
                        },
                        2 => { // temporary
                            var_offset = self.regs.temp_vars.expect("opcode without temp_vars").overflowing_add(index * 2).0;
                        },
                        3 => { // parameter
                            var_offset = self.regs.parm_vars.expect("opcode without parm_vars").overflowing_add(index * 2).0;
                        },
                        _ => unreachable!()
                    };
                    if acc_modifier {
                        var_offset = var_offset.overflowing_add(self.regs.acc * 2).0;
                    }

                    match oper {
                        2 => { /* increment var, then load to acc/stack */
                            let mut v = self.heap.load_u16(var_offset as usize);
                            v = v.overflowing_add(1).0;
                            self.heap.store_u16(var_offset as usize, v);
                            oper = 0;
                        },
                        3 => { /* decrement var, then load to acc/stack */
                            let mut v = self.heap.load_u16(var_offset as usize);
                            v = v.overflowing_sub(1).0;
                            self.heap.store_u16(var_offset as usize, v);
                            oper = 0;
                        },
                        _ => {}
                    };

                    match oper {
                        0 => { // load variable to acc/stack
                            let v = self.heap.load_u16(var_offset as usize);
                            if on_stack {
                                self.push(v)?;
                            } else {
                                self.regs.acc = v;
                            }
                        },
                        1 => { // store acc/stack to variable
                            // if !on_stack && acc_modifier {
                            //    todo!("special case?");
                            // }
                            let v = if on_stack {
                                self.pop()?
                            } else {
                                self.regs.acc
                            };
                            self.heap.store_u16(var_offset as usize, v);
                        },
                        _ => unreachable!()
                    };
                },
                _ => { todo!("unimplemented opcode {:x}", opcode); }
            }

            /*if self.regs.pc == 0x2431 {
                todo!("hack");
            }*/
        }
        Ok(())
    }

    fn load_pc_u8(&mut self) -> u8 {
        let v = self.heap.load_u8(self.regs.pc as usize);
        self.regs.pc += 1;
        v
    }

    fn load_pc_u16(&mut self) -> u16 {
        let a = self.load_pc_u8() as u16;
        let b = self.load_pc_u8() as u16;
        a + (b << 8)
    }

    fn load_pc_s8(&mut self) -> u16 {
        let mut v = self.load_pc_u8() as u16;
        if (v & 0x80) != 0 {
            v = v | 0xff;
        }
        v
    }

    fn verify_stack(&self) -> Result<()> {
        let stack_begin = self.stack_base as u16;
        let stack_end = stack_begin + STACK_SIZE as u16;
        if self.regs.sp < stack_begin { return Err(anyhow!("stack underflow, sp {:x} begin {:x}", self.regs.sp, stack_begin)); }
        if self.regs.sp >= stack_end { return Err(anyhow!("stack overflow, sp {:x} end {:x}", self.regs.sp, stack_end)); }
        Ok(())
    }

    fn push(&mut self, value: u16) -> Result<()> {
        self.verify_stack()?;
        self.heap.store_u16(self.regs.sp as usize, value);
        self.regs.sp += 2;
        Ok(())
    }

    fn pop(&mut self) -> Result<u16> {
        self.verify_stack()?;
        self.regs.sp -= 2;
        Ok(self.heap.load_u16(self.regs.sp as usize))
    }

    pub fn execute_code(&mut self, object: u16, selector: u16, args: &[u16]) -> Result<()> {
        match self.lookup_selector(object, selector)? {
            SelectorLookup::Variable(_offset) => {
                return Err(anyhow!("attempt to execute variable, object {} (0x{:x}) selector {} ({})",
                    self.determine_object_name(object), object,
                    self.selector_table.get_string(selector as usize).unwrap_or(&"<unknown>".to_string()), selector)
                );
            },
            SelectorLookup::Method(offset) => {
                if args.len() != 0 {
                    log::warn!("execute_code() with arguments, IMPLEMENT ME");
                }
                let old_object = self.regs.object;
                let old_pc = self.regs.pc;
                let old_sp = self.regs.sp;
                let old_local_vars = self.regs.local_vars;
                self.regs.object = object;
                self.regs.local_vars = Some(self.heap.load_u16(heap_object::get_locals_offset(object as usize)));
                self.regs.pc = offset as u16;
                self.run_pmachine()?;
                self.regs.pc = old_pc;
                self.regs.object = old_object;
                self.regs.local_vars = old_local_vars;
                self.regs.sp = old_sp;
            }
        };
        Ok(())
    }

    pub fn run(&mut self) -> Result<()> {
        let script0 = self.scripts.iter().find(|s| s.script_id == 0).expect("script 0 not loaded");
        let game_obj = self.get_export_entry(script0, 0).expect("script 0 export 0 missing");
        println!("game_obj @ {:x} - script0 base {:x}", game_obj, script0.base);
        self.execute_code(script0.base as u16 + game_obj, SEL_PLAY, &[])
    }

    pub fn get_export_entry(&self, script: &LoadedScript, num: u16) -> Option<u16> {
        if let Some(exports_offset) = script.exports_offset {
            let num_entries = self.heap.load_u16(exports_offset);
            if num < num_entries {
                let offset = self.heap.load_u16(exports_offset + 2 + (num as usize * 2));
                return Some(offset);
            }
        }
        None
    }

    fn handle_send(&mut self, object: u16, search_object: u16, nr_parms: u16) -> Result<()> {
        println!("handle_send: rest {}", self.regs.rest);
        let nr_parms = nr_parms + self.regs.rest; // TODO is this correct?

        let send_sp = self.regs.sp - nr_parms;
        if DEBUG_SEND{
            println!("handle_send(): object {} (0x{:x}) search_object 0x{:x} nr_parms {}",
                self.determine_object_name(object), object, search_object,
                nr_parms);
        }

        let mut n: u16 = 0;
        while n < nr_parms {
            let selector_id = self.heap.load_u16((send_sp + n) as usize);
            if DEBUG_SEND {
                println!("  send: selector '{}' ({}) ", self.selector_table.get_string(selector_id as usize).unwrap_or(&"<unknown>".to_string()), selector_id);
            }

            let parm_offset = (send_sp + n + 2) as usize;
            let mut num_args = self.heap.load_u16((send_sp + n + 2) as usize);
            if self.regs.rest > 0 {
                if DEBUG_REST {
                    println!("send: got rest {}, updating num_args from {} -> {}",
                        self.regs.rest,
                        num_args,
                        num_args + self.regs.rest / 2);
                }
                num_args += self.regs.rest / 2;
                self.heap.store_u16((send_sp + n + 2) as usize, num_args);
                self.regs.rest = 0; // XXX correct?
                if DEBUG_REST {
                    println!("dumping last few args...");
                    for n in 0..10 {
                        let sp_mod = n * 2;
                        let value = self.heap.load_u16((parm_offset + sp_mod) as usize);
                        println!("  send-sp+{}: arg {}: {} {:x}", sp_mod, n, value, value);
                    }
                }
            }
            if DEBUG_SEND {
                println!("  send: num_args {}", num_args);
                for m in 0..num_args {
                    let v = self.heap.load_u16((send_sp + n + 4 + m) as usize);
                    println!("    value 0x{:x} ({})", v, v);
                }
            }

            match self.lookup_selector(search_object, selector_id)? {
                SelectorLookup::Variable(offset) => {
                    if num_args == 0 {
                        self.regs.acc = self.heap.load_u16(offset);
                    } else {
                        if num_args > 1 {
                            log::warn!("got send to object {} (0x{:x}) variable selector {} ({}) with >1 arguments, treating as one",
                                self.determine_object_name(object), object,
                                self.selector_table.get_string(selector_id as usize).unwrap_or(&"<unknown>".to_string()), selector_id);
                        }
                        let value = self.heap.load_u16((send_sp + n + 4) as usize);
                        self.heap.store_u16(offset, value);
                        if DEBUG_SEND {
                            println!("!! setting selector to value {}", value);
                        }
                    }
                },
                SelectorLookup::Method(offset) => {
                    if DEBUG_SEND {
                        println!("!! invoking method due to send, pc {:x} sp {:x} param_offset {:x}", offset, self.regs.sp, parm_offset);
                    }
                    let old_sp = self.regs.sp;
                    let old_pc = self.regs.pc;
                    let old_object = self.regs.object;
                    let old_parm_vars = self.regs.parm_vars;
                    let old_temp_vars = self.regs.temp_vars;
                    let old_local_vars = self.regs.local_vars;
                    self.regs.pc = offset as u16;
                    self.regs.object = object;
                    self.regs.parm_vars = Some(parm_offset as u16);
                    self.regs.local_vars = Some(self.heap.load_u16(heap_object::get_locals_offset(object as usize)));
                    self.run_pmachine()?;
                    self.regs.local_vars = old_local_vars;
                    self.regs.parm_vars = old_parm_vars;
                    self.regs.temp_vars = old_temp_vars;
                    self.regs.object = old_object;
                    self.regs.pc = old_pc;
                    self.regs.sp = old_sp;
                },
            };
            n += 2 + 2 + num_args * 2; // 2 id, 2 num_vars
        }

        self.regs.sp = self.regs.sp - nr_parms;
        Ok(())
    }

    pub fn get_script(&mut self, script_id: u16) -> Result<usize> {
        loop {
            if let Some(index) = self.scripts.iter().position(|s| s.script_id == script_id) {
                return Ok(index);
            }
            self.load_script(script_id)?;
            // Next loop iterator will find the script
        }
    }

    fn get_class_offset(&mut self, class_id: u16) -> Result<usize> {
        loop {
            if let Some(class) = self.classes.iter().find(|c| c.class_id == class_id) {
                let script = self.scripts.iter().find(|s| s.script_id == class.script_id).unwrap();
                return Ok(script.base + class.offset as usize);
            }
            if let Some(script_id) = self.class_table.get_script(class_id) {
                self.load_script(script_id)?;
                // Next iteration will find the class
            } else {
                return Err(anyhow!("unable to locate script for class id {}", class_id));
            }
        }
    }

    fn lookup_selector(&mut self, object: u16, selector_id: u16) -> Result<SelectorLookup> {
        if DEBUG_SELECTOR_LOOKUP {
            println!("+lookup_selector: object {} (0x{:x}) selector {} (0x{:x})",
                self.determine_object_name(object), object,
                self.selector_table.get_string(selector_id as usize).unwrap_or(&"<unknown>".to_string()),
                selector_id);
        }

        let send_object = heap_object::Object0::new(&self.heap, object)?;
        let species_id = send_object.get_species();

        // Look up the species. This will contain the list of value selector ID's, which allows us
        // to look up the object property value if it exists
        let species_object = self.get_class_offset(species_id)?;
        let species_object = heap_object::Object0::new(&self.heap, species_object as u16)?;

        // Re-initialize send_objec - get_class_offset() is mutable as it may load the
        // class
        let send_object = heap_object::Object0::new(&self.heap, object)?;

        let num_vars = species_object.get_num_variables() as usize;
        for n in 0..num_vars {
            let sel_id = species_object.get_variable_selector_id(n);
            if sel_id == selector_id {
                let value_offset = send_object.get_variable_offset(n) as usize;
                let sel_value = self.heap.load_u16(value_offset);
                if DEBUG_SELECTOR_LOOKUP {
                    println!("-lookup_selector: found variable -> index {} value {}", n, sel_value);
                }
                return Ok(SelectorLookup::Variable(value_offset));
            }
        }

        // Not a variable selector. Try methods now
        let mut lookup_object = heap_object::Object0::new(&self.heap, object)?;
        loop {
            let num_methods = lookup_object.get_num_methods();
            for n in 0..num_methods {
                let method_sel = lookup_object.get_method_selector(n);
                let method_func = lookup_object.get_method_pointer(n);
                if method_sel == selector_id {
                    if DEBUG_SELECTOR_LOOKUP {
                        println!("-lookup_selector: found method -> offset 0x{:x}", method_func);
                    }
                    return Ok(SelectorLookup::Method(method_func as usize));
                }
            }

            // Not in this object, go to the superclass
            let superclass_id = lookup_object.get_variable_value(heap_object::PROP_IDX_SUPERCLASS);
            if DEBUG_SELECTOR_LOOKUP {
                println!("  lookup object {}, method not found, going deeper to superclass {}", lookup_object.base, superclass_id);
            }

            let super_class = self.classes.iter().find(|c| c.class_id == superclass_id).unwrap();
            let super_script = self.scripts.iter().find(|s| s.script_id == super_class.script_id).unwrap();

            lookup_object = heap_object::Object0::new(&self.heap, super_script.base as u16 + super_class.offset)?;
        }
    }

    pub fn dump_object(&self, object: u16) {
        println!("dump_object {:x}", object);
        let object = heap_object::Object0::new(&self.heap, object);
        if object.is_err() {
            println!("  magic mismatch - not dumping more");
            return;
        }
        let object = object.unwrap();
        let species = object.get_species();
        let superclass = object.get_superclass();
        let info = object.get_info();

        println!("  species     {:04x}", species);
        println!("  superclass  {:04x}", superclass);
        println!("  info        {:04x}", info);

        let num_vars = object.get_num_variables();
        if (info & heap_object::INFO_IS_CLASS) != 0 {
            for n in 0..num_vars {
                let sel_id = object.get_variable_selector_id(n);
                let sel_value = object.get_variable_value(n);
                println!("  variable {}: selector {} value {:04x} ({})", n, sel_id, sel_value, sel_value);
            }
        } else {
            for n in 0..num_vars {
                let sel_value = object.get_variable_value(n);
                println!("  variable {}: value {:04x} ({})", n, sel_value, sel_value);
            }
        }

        let num_methods = object.get_num_methods();
         for n in 0..num_methods {
            let method_sel = object.get_method_selector(n);
            let method_offset = object.get_method_pointer(n);
            println!("  method {}: selector {} value {:04x}", n, method_sel, method_offset);
        }
    }

    fn call_external_script(&mut self, script_num: u16, disp_index: u16, nr_parms: u16) -> Result<()> {
        let script_idx = self.get_script(script_num)?;
        let script = &self.scripts[script_idx];
        if let Some(entry) = self.get_export_entry(script, disp_index) {
            let param_offset = self.regs.sp - (nr_parms + 2 + self.regs.rest);
            println!("calle: check if this is okay, with parameters");
            self.regs.rest = 0;

            println!("call_external_script: nr_parms {} param_offset {:x} sp {:x}", nr_parms, param_offset, self.regs.sp);
            for n in (0..nr_parms+2).step_by(2) {
                let offset = (param_offset + n) as usize;
                println!("param {} @ {:x}: {:04x}", n, offset,
                    self.heap.load_u16(offset));

            }

            let old_pc = self.regs.pc;
            let old_parm_vars = self.regs.parm_vars;
            self.regs.pc = script.base as u16 + entry;
            self.regs.parm_vars = Some(param_offset);
            // TODO do we have to set local_vars here?
            self.run_pmachine()?;
            self.regs.parm_vars = old_parm_vars;
            self.regs.pc = old_pc;

            self.regs.sp = param_offset;
            self.regs.rest = 0;

        } else {
            return Err(anyhow!("calle: cannot find export {} in script {}", disp_index, script_num));
        }
        Ok(())
    }

    fn determine_object_name(&self, object: u16) -> String {
        let object = heap_object::Object0::new(&self.heap, object);
        if object.is_err() {
            return "<corrupt>".to_string();
        }
        let object = object.unwrap();

        let name_offset = object.get_variable_value(heap_object::PROP_IDX_NAME);
        if name_offset == 0 {
            return "<unnamed>".to_string();
        }
        let s = self.heap.get_string(name_offset as usize);
        s.to_string()
    }

    pub fn allocate_handle(&mut self, content: HandleContent) -> u16 {
        let id = self.next_handle;
        self.handles.push(Handle{ id, content });
        self.next_handle += 1;
        id
    }

    pub fn free_handle(&mut self, handle: u16) {
        if let Some(index) = self.handles.iter().position(|h| h.id == handle) {
            self.handles.remove(index);
        } else {
            log::warn!("free_handle: handle {} not found", handle);
        }
    }

    pub fn find_list_by_handle(&self, handle: u16) -> Option<&List> {
        if let Some(item) = self.handles.iter().find(|h| h.id == handle) {
            match &item.content {
                HandleContent::ListHandle(list) => Some(list),
                _ => None,
            }
        } else {
            None
        }
    }

    pub fn find_mut_list_by_handle(&mut self, handle: u16) -> Option<&mut List> {
        if let Some(item) = self.handles.iter_mut().find(|h| h.id == handle) {
            match &mut item.content {
                HandleContent::ListHandle(list) => Some(list),
                _ => None,
            }
        } else {
            None
        }
    }

    pub fn find_node_by_handle(&self, handle: u16) -> Option<&Node> {
        if let Some(item) = self.handles.iter().find(|h| h.id == handle) {
            match &item.content {
                HandleContent::NodeHandle(node) => Some(node),
                _ => None,
            }
        } else {
            None
        }
    }

    pub fn find_mut_node_by_handle(&mut self, handle: u16) -> Option<&mut Node> {
        if let Some(item) = self.handles.iter_mut().find(|h| h.id == handle) {
            match &mut item.content {
                HandleContent::NodeHandle(node) => Some(node),
                _ => None,
            }
        } else {
            None
        }
    }

    fn resolve_pc(&self) -> String {
        let mut result = "???".to_string();

        let pc = self.regs.pc as usize;
        // scripts
        for script in &self.scripts {
            if pc < script.base { continue; }
            if pc >= script.base + script.length { continue; }

            // Note: symbols is sorted, so the last match suffices
            // TODO: walk from the back to the front instead
            for sym in &script.symbols {
                if pc < sym.0 as usize { continue; }
                result = format!("{}+{}", sym.1, pc as u16 - sym.0);
            }
        }
        result
    }

    pub fn find_class_id(&self, offset: usize) -> u16 {
        for class in &self.classes {
            let script = self.scripts.iter().find(|s| s.script_id == class.script_id).unwrap();
            if script.base + class.offset as usize == offset {
                return class.class_id;
            }
        }
        NO_CLASS_ID
    }

    pub fn get_object_value_index(&mut self, object_id: u16, selector_id: u16) -> Result<usize> {
        let object = heap_object::Object0::new(&self.heap, object_id)?;
        let species_id = object.get_species();

        let species_object = self.get_class_offset(species_id)?;
        let species_object = heap_object::Object0::new(&self.heap, species_object as u16)?;
        let num_vars = species_object.get_num_variables() as usize;
        for n in 0..num_vars {
            let sel_id = species_object.get_variable_selector_id(n);
            if sel_id == selector_id {
                return Ok(n);
            }
        }
        Err(anyhow!("object {} species {} does not have selector {}", object_id, species_id, selector_id))
    }

    pub fn read_object_by_selector(&mut self, object: u16, selector_id: u16) -> Result<u16> {
        let index = self.get_object_value_index(object, selector_id)?;
        let object = heap_object::Object0::new(&self.heap, object)?;
        Ok(object.get_variable_value(index))
    }

    pub fn read_variables(&self, object: u16) -> Result<Vec<u16>> {
        let object = heap_object::Object0::new(&self.heap, object)?;
        let num_vars = object.get_num_variables() as usize;
        let mut values = vec![ 0u16; num_vars ];
        for n in 0..num_vars {
            values[n] = object.get_variable_value(n);
        }
        Ok(values)
    }

    pub fn write_variables(&mut self, object: u16, values: &[u16]) -> Result<()> {
        let object = heap_object::Object0::new(&self.heap, object)?;
        let num_vars = object.get_num_variables() as usize;
        if num_vars != values.len() { return Err(anyhow!("invalid value count")); }
        let base_offset = object.get_variable_offset(0);
        for n in 0..num_vars {
            self.heap.store_u16(base_offset + (n * 2), values[n]);
        }
        Ok(())
    }

    pub fn write_object_by_selector(&mut self, object: u16, selector_id: u16, value: u16) -> Result<()> {
        let index = self.get_object_value_index(object, selector_id)?;
        let object = heap_object::Object0::new(&self.heap, object)?;
        let offset = object.get_variable_offset(index);
        self.heap.store_u16(offset, value);
        Ok(())
    }
}
