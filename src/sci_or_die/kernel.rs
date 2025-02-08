use crate::{
    scires::{resource, text},
    sci_or_die::{heap_object, interp, graphics, movement, ui},
};
use anyhow::{anyhow, Result, Context};

const DEBUG_CLONE: bool = false;
const DEBUG_LIST: bool = true;

const SCI_FALSE: u16 = 0;
const SCI_TRUE: u16 = 1;

const SEL_TYPE: u16 = 34;
const SEL_MESSAGE: u16 = 40;

const EVT_TYPE_MOUSEDOWN: u16 = 0x0001;
const _EVT_TYPE_KEYDOWN: u16 = 0x0004;
const _EVT_TYPE_KEYUP: u16 = 0x0008;

pub fn handle_kcall(interp: &mut interp::Interpreter, nr: u16, args: &[u16]) -> Result<()> {
    println!("handle_kcall: {} - {} {:?}", nr, interp.kvocab.get_string(nr as usize).unwrap_or(&"<???>".to_string()), args);
    match nr {
        0x02 => /* ScriptID */ {
            let script_id = args[1];
            let index = if args[0] >= 2 { args[2] } else { 0 };

            let script_idx = interp.get_script(script_id)?;
            let script = &interp.scripts[script_idx];
            if let Some(entry) = interp.get_export_entry(script, index) {
                interp.regs.acc = script.base as u16 + entry;
            } else {
                return Err(anyhow!("kScriptID: script {} index {} does not exist", script_id, index));
            }
        },
        0x04 => /* Clone */ {
            let source_object = args[1];

            let class_id = interp.find_class_id(source_object as usize);
            let clone_object = heap_object::clone_object0(&mut interp.heap, source_object, class_id)?;

            interp.regs.acc = clone_object;
            if DEBUG_CLONE {
                println!("kClone: ORIGINAL OBJECT 0x{:x}", args[1]);
                interp.dump_object(args[1]);
                println!("kClone: CLONED OBJECT 0x{:x}", clone_object);
                interp.dump_object(clone_object as u16);
            }
        },
        0x05 => /* DisposeClone */ {
            let object = heap_object::Object0::new(&interp.heap, args[1])?;
            if (object.get_info() & heap_object::INFO_IS_CLONE) != 0 {
                let address = (object.base - heap_object::OBJECT_PREFIX_HACK) as u16;
                interp.heap.free(address)?;
            } else {
                log::warn!("kDisposeClone: attempt to dispose object {:x} which is not a clone", object.base);
            }
        },
        0x06 => /* IsObject */ {
            let object = args[1];

            if heap_object::Object0::new(&interp.heap, object).is_ok() {
                interp.regs.acc = SCI_TRUE;
            } else {
                interp.regs.acc = SCI_FALSE;
            }
        },
        0x08 => /* DrawPic */ {
            let pic_nr = args[1];
            let animation = if args[0] >= 1 { args[2] } else { u16::MAX };
            let flags = if args[0] >= 2 { args[3] } else { 1 /* clear screen */ };
            graphics::draw_pic(interp, pic_nr, animation, flags);
        },
        0x0b => /* Animate */ {
            let cast = if args[0] >= 1 { args[1] } else { 0 };
            graphics::animate(interp, cast)?;
        },
        0x0e => /* NumCels */ {
            graphics::num_cells(interp, args[1])?;
        },
        0x12 => /* AddToPic */ {
            let cast = if args[0] >= 1 { args[1] } else { 0 };
            graphics::add_to_pic(interp, cast)?;
        },
        0x17 => /* DrawControl */ {
            let control = args[1];
            graphics::draw_control(interp, control)?;
        },
        0x1a => /* TextSize */ {
            let rect = args[1] as usize;
            let offset = args[2];
            let font_nr = args[3];

            let (width, height) = graphics::text_size(interp, font_nr, offset)?;

            interp.heap.store_u16(rect + 0, 0); // top
            interp.heap.store_u16(rect + 2, 0); // left
            interp.heap.store_u16(rect + 4, height); // bottom
            interp.heap.store_u16(rect + 6, width); // right
        },
        0x1c => /* GetEvent */ {
            let _flags = args[1];
            let offset = args[2];
            log::warn!("kGetEvent: not yet supported, returning null event");

            // Default to null event
            interp.regs.acc = 0;

            if let Some(event) = interp.ui.pump_events() {
                match event {
                    ui::SciEvent::Terminate => {
                        interp.terminating = true;
                    }
                    ui::SciEvent::Key(ch) => {
                        let i_type = interp.get_object_value_index(offset, SEL_TYPE).unwrap();
                        let i_message = interp.get_object_value_index(offset, SEL_MESSAGE).unwrap();

                        let object = heap_object::Object0::new(&interp.heap, offset)?;
                        let o_type = object.get_variable_offset(i_type);
                        let o_message = object.get_variable_offset(i_message);

                        log::warn!("kGetEvent: kludging an event together!");
                        interp.heap.store_u16(o_type, EVT_TYPE_MOUSEDOWN);
                        interp.heap.store_u16(o_message, ch as u16);
                    },
                }
            }
        },
        0x27 => /* HaveMouse */ {
            interp.regs.acc = SCI_TRUE;
            log::warn!("kHaveMouse: forcing result to {}", interp.regs.acc);
        },
        0x30 => /* GameIsRestarting */ {
            interp.regs.acc = SCI_FALSE;
            log::warn!("kGameIsRestarting: forcing result to {}", interp.regs.acc);
        },
        0x32 => /* NewList */ {
            let list = interp::List::new();
            let id = interp.allocate_handle(interp::HandleContent::ListHandle(list));
            interp.regs.acc = id;
            if DEBUG_LIST { println!("DEBUG_LIST: kNewList: new list id {}", interp.regs.acc); }
        },
        0x33 => /* DisposeList */ {
            let list_handle = args[1];
            if DEBUG_LIST {
                println!("DEBUG_LIST: kDisposeList: list id {}", list_handle);
            }
            if let Some(index) = interp.handles.iter().position(|h| h.id == list_handle) {
                interp.handles.remove(index);
            } else {
                log::error!("dispose list with unrecognized handle {}", list_handle);
            }
        },
        0x34 => /* NewNode */ {
            let value = args[1];
            let key = args[2];
            let node = interp::Node::new(key, value);
            let id = interp.allocate_handle(interp::HandleContent::NodeHandle(node));
            interp.regs.acc = id;
            if DEBUG_LIST { println!("DEBUG_LIST: kNewNode: value {} key {} --> id {}", value, key, id); }
        },
        0x35 => /* FirstNode */ {
            let handle = args[1];
            if let Some(list) = interp.find_list_by_handle(handle) {
                if let Some(node) = list.items.first() {
                    if DEBUG_LIST { println!("DEBUG_LIST: kFirstNode: handle {} --> {}", handle, *node); }
                    interp.regs.acc = *node;
                } else {
                    if DEBUG_LIST { println!("DEBUG_LIST: kFirstNode: handle {} --> nil", handle); }
                    interp.regs.acc = 0;
                }
            } else {
                log::error!("kFirstNode: unrecognized list handle {}", handle);
            }
        },
        0x38 => /* NextNode */ {
            let node_handle = args[1];
            if let Some(node) = interp.find_node_by_handle(node_handle) {
                let list = interp.find_list_by_handle(node.list).unwrap();
                let index = list.items.iter().position(|i| *i == node_handle).unwrap();
                if index < list.items.len() - 1 {
                    interp.regs.acc = list.items[index + 1];
                    if DEBUG_LIST { println!("DEBUG_LIST: kNextNode: handle {} --> {}", node_handle, interp.regs.acc); }
                } else {
                    if DEBUG_LIST { println!("DEBUG_LIST: kNextNode: handle {} --> nil", node_handle); }
                    interp.regs.acc = 0;
                }
            } else {
                log::error!("kNextNode: unrecognized node handle {}", node_handle);
            }
        },
        0x39 => /* PrevNode */ {
            let node_handle = args[1];
            if let Some(node) = interp.find_node_by_handle(node_handle) {
                let list = interp.find_list_by_handle(node.list).unwrap();
                let index = list.items.iter().position(|i| *i == node_handle).unwrap();
                if index > 0 {
                    interp.regs.acc = list.items[index - 1];
                    if DEBUG_LIST { println!("DEBUG_LIST: kPrevNode: handle {} --> {}", node_handle, interp.regs.acc); }
                } else {
                    if DEBUG_LIST { println!("DEBUG_LIST: kPrevNode: handle {} --> nil", node_handle); }
                    interp.regs.acc = 0;
                }
            } else {
                log::error!("kPrevNode: unrecognized node handle {}", node_handle);
            }
        },
        0x3a => /* NodeValue */ {
            let node_handle = args[1];
            if let Some(node) = interp.find_node_by_handle(node_handle) {
                if DEBUG_LIST { println!("DEBUG_LIST: kNodeValue: node {} --> {}", node_handle, node.value); }
                interp.regs.acc = node.value;
            } else {
                log::error!("kNodeValue: unrecognized node handle {}", node_handle);
            }
        },
        0x3c => /* AddToFront */ {
            let list_handle = args[1];
            let node_handle = args[2];
            let node_ok = interp.find_node_by_handle(node_handle).is_some();
            if let Some(list) = interp.find_mut_list_by_handle(list_handle) {
                if node_ok {
                    if DEBUG_LIST { println!("DEBUG_LIST: kAddToFront: list {} node {}", list_handle, node_handle); }
                    list.items.insert(0, node_handle);
                    let node = interp.find_mut_node_by_handle(node_handle).unwrap();
                    node.list = list_handle;
                } else {
                    log::error!("kAddToFront: unrecognized node handle {}", node_handle);
                }
            } else {
                log::error!("kAddToFront: unrecognized list handle {}", list_handle);
            }

        },
        0x3d => /* AddToEnd */ {
            let list_handle = args[1];
            let node_handle = args[2];
            let node_ok = interp.find_node_by_handle(node_handle).is_some();
            if let Some(list) = interp.find_mut_list_by_handle(list_handle) {
                if node_ok {
                    if DEBUG_LIST { println!("DEBUG_LIST: kAddToEnd: list {} node {}", list_handle, node_handle); }
                    list.items.push(node_handle);
                    let node = interp.find_mut_node_by_handle(node_handle).unwrap();
                    node.list = list_handle;
                } else {
                    log::error!("kAddToEnd: unrecognized node handle {}", node_handle);
                }
            } else {
                log::error!("kAddToEnd: unrecognized list handle {}", list_handle);
            }
        },
        0x3e => /* FindKey */ {
            let list_handle = args[1];
            let key = args[2];
            interp.regs.acc = 0;
            if let Some(list) = interp.find_list_by_handle(list_handle) {
                for node_handle in &list.items {
                    if let Some(node) = interp.find_node_by_handle(*node_handle) {
                        if node.key == key {
                            if DEBUG_LIST { println!("DEBUG_LIST: kFindKey: list {} key {} -> node {}", list_handle, key, node_handle); }
                            interp.regs.acc = *node_handle;
                            break;
                        }
                    }
                }
            } else {
                log::error!("kFindKey: unrecognized list {}", list_handle);
            }
        },
        0x3f => /* DeleteKey */ {
            let list_handle = args[1];
            let key = args[2];
            if let Some(list) = interp.find_list_by_handle(list_handle) {
                for (node_index, node_handle) in list.items.iter().enumerate() {
                    let node_handle = *node_handle;
                    if let Some(node) = interp.find_node_by_handle(node_handle) {
                        if node.key == key {
                            if DEBUG_LIST { println!("DEBUG_LIST: kDeleteKey: list {} key {} -> node {}", list_handle, key, node_handle); }
                            let list = interp.find_mut_list_by_handle(list_handle).unwrap();
                            list.items.remove(node_index);
                            interp.free_handle(node_handle);
                            break;
                        }
                    }
                }
            } else {
                log::error!("kDeleteKey: unrecognized list {}", list_handle);
            }
        },
        0x40 => /* Random */ {
            let min = args[1];
            let max = args[2];
            interp.regs.acc = min;
            // Note: avoid any random behaviour by forcing kRandom to always yield the min
            // value
            log::warn!("kRandom: stub implementation for random [ {} .. {} ] -> {}",
                min, max, interp.regs.acc);
        },
        0x45 => /* Wait */ {
            log::warn!("kWait; stub implementation");
            graphics::render(interp);
        },
        0x46 => /* GetTime */ {
            interp.regs.acc = interp.time;
            interp.time += 1;
            log::warn!("kGetTime: stub implementation -> {}", interp.regs.acc);
        },
        0x4d => /* GetFarText */ {
            let res_nr = args[1];
            let str_nr = args[2];
            let offset = args[3] as usize;

            let text_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::Text, num: res_nr });
            let text = text::Text::new(&text_res.data)?;
            let message = text.get_item(str_nr as usize).context(format!("text {} does not contain string {}", res_nr, str_nr))?;
            for (n, v) in message.iter().enumerate() {
                interp.heap.store_u8(offset + n, *v);
            }
            interp.heap.store_u8(offset + message.len(), 0); // terminator
        },
        0x51 => /* CanBeHere */ {
            interp.regs.acc = SCI_TRUE;
            log::warn!("kCanBeHere: stub implementation -> {}", interp.regs.acc);
        },
        0x52 => /* OnControl */ {
            interp.regs.acc = 0x9fff;
            log::warn!("kOnControl: stub implementation -> {}", interp.regs.acc);
        },
        0x53 => /* InitBresen */ {
            let mover = args[1];
            let step_factor = if args[0] >= 2 { args[2] } else { 1 };
            movement::init_bresen(interp, mover, step_factor)?;
        },
        0x54 => /* DoBresen */ {
            let mover = args[1];
            movement::do_bresen(interp, mover)?;
        },
        0x5c => /* MemoryInfo */ {
            match args[1] {
                0 => { // total amount of free memory on the heap
                    interp.regs.acc = interp.heap.get_free_bytes();
                },
                1 => { // total contigous amount of free memory on the heap
                    interp.regs.acc = interp.heap.get_largest_contiguous_block();
                },
                2 => { // largest block of hunk memory
                    log::warn!("kMemoryInfo: TODO hunk memory");
                    interp.regs.acc = 65535;
                },
                _ => {
                    log::error!("kMemoryInfo: unrecognized request {}, claiming no memory is available", args[1]);
                    interp.regs.acc = 0;
                }
            }
        },
        0x62 => /* GetCwd */ {
            let address = args[1] as usize;
            interp.heap.store_u8(address + 0, b'C');
            interp.heap.store_u8(address + 1, b':');
            interp.heap.store_u8(address + 2, b'\\');
            interp.heap.store_u8(address + 3, 0);
            interp.regs.acc = address as u16;
        },
        0x68 => /* GetSaveDir */ {
            interp.regs.acc = interp.save_dir_offset;
        },
        _ => {
            interp.regs.acc = 0;
            println!("handle_kcall: unimplemented kcall {} - {} {:?} -> {:x}", nr, interp.kvocab.get_string(nr as usize).unwrap_or(&"<???>".to_string()), args, interp.regs.acc);
        },
    }
    Ok(())
}

