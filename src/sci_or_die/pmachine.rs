use anyhow::Result;

use crate:: {
    sci_or_die::{interp, kernel}
};

const DEBUG_REST: bool = false;

pub fn execute(interp: &mut interp::Interpreter) -> Result<()> {
    let opcode = interp.load_pc_u8();

    match opcode {
        0x00 | 0x01 => { // bnot
            interp.regs.acc = interp.regs.acc ^ 0xffff;
        },
        0x02 => { // add
            interp.regs.acc = interp.regs.acc.overflowing_add(interp.pop()?).0;
        },
        0x04 => { // sub
            interp.regs.acc = interp.pop()?.overflowing_sub(interp.regs.acc).0;
        },
        0x06 => { // mul
            interp.regs.acc = interp.regs.acc.overflowing_mul(interp.pop()?).0;
        },
        0x08 => { // div
            if interp.regs.acc != 0 {
                interp.regs.acc = interp.pop()?.overflowing_div(interp.regs.acc).0;
            }
        },
        0x0a => { // mod
            if interp.regs.acc != 0 {
                interp.regs.acc = interp.pop()? % interp.regs.acc;
            }
        },
        0x0c => { // shr
            interp.regs.acc = interp.pop()? >> interp.regs.acc;
        },
        0x0e => { // shl
            interp.regs.acc = interp.pop()? << interp.regs.acc;
        },
        0x10 => { // xor
            interp.regs.acc = interp.regs.acc ^ interp.pop()?;
        },
        0x12 => { // and
            interp.regs.acc = interp.regs.acc & interp.pop()?;
        },
        0x14 => { // or
            interp.regs.acc = interp.regs.acc | interp.pop()?;
        },
        0x16 => { // neg
            interp.regs.acc = interp.regs.acc ^ 0x8000; /* TODO: is this correct */
        },
        0x18 => { // not
            interp.regs.acc = if interp.regs.acc == 0 { 1 } else { 0 };
        },
        0x1a => { // eq?
            interp.regs.prev = interp.regs.acc;
            interp.regs.acc = if interp.pop()? == interp.regs.acc {
                1
            } else {
                0
            };
        },
        0x1c => { // ne?
            interp.regs.prev = interp.regs.acc;
            interp.regs.acc = if interp.pop()? != interp.regs.acc {
                1
            } else {
                0
            };
        },
        0x1e => { // gt?
            interp.regs.prev = interp.regs.acc;
            interp.regs.acc = if (interp.pop()? as i16) > (interp.regs.acc as i16) {
                1
            } else {
                0
            };
        },
        0x20 => { // ge?
            interp.regs.prev = interp.regs.acc;
            interp.regs.acc = if (interp.pop()? as i16) >= (interp.regs.acc as i16) {
                1
            } else {
                0
            };
        },
        0x22 => { // lt?
            interp.regs.prev = interp.regs.acc;
            interp.regs.acc = if (interp.pop()? as i16) < (interp.regs.acc as i16) {
                1
            } else {
                0
            };
        },
        0x24 => { // le?
            interp.regs.prev = interp.regs.acc;
            interp.regs.acc = if (interp.pop()? as i16) <= (interp.regs.acc as i16) {
                1
            } else {
                0
            };
        },
        0x26 => { // ugt?
            interp.regs.prev = interp.regs.acc; // TODO is this correct?
            interp.regs.acc = if interp.pop()? > interp.regs.acc {
                1
            } else {
                0
            };
        },
        0x28 => { // uge?
            interp.regs.prev = interp.regs.acc; // TODO is this correct?
            interp.regs.acc = if interp.pop()? >= interp.regs.acc {
                1
            } else {
                0
            };
        },
        0x2a => { // ult?
            interp.regs.prev = interp.regs.acc; // TODO is this correct?
            interp.regs.acc = if interp.pop()? < interp.regs.acc {
                1
            } else {
                0
            };
        },
        0x2c => { // ule?
            interp.regs.prev = interp.regs.acc; // TODO is this correct?
            interp.regs.acc = if interp.pop()? <= interp.regs.acc {
                1
            } else {
                0
            };
        },
        0x2e | 0x2f => { // bt
            let relpos = if opcode == 0x2e {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            if interp.regs.acc != 0 {
                interp.regs.pc = interp.regs.pc.overflowing_add(relpos).0;
            }
        },
        0x30 | 0x31 => { // bnt
            let relpos = if opcode == 0x30 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            if interp.regs.acc == 0 {
                interp.regs.pc = interp.regs.pc.overflowing_add(relpos).0;
            }
        },
        0x32 | 0x33 => { // jmp
            let relpos = if opcode == 0x32 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            interp.regs.pc = interp.regs.pc.overflowing_add(relpos).0;
        },
        0x34 | 0x35 => { // ldi
            interp.regs.acc = if opcode == 0x34 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_s8()
            };
        },
        0x36 => { // push
            interp.push(interp.regs.acc)?;
        },
        0x38 | 0x39 => { // pushi
            let v = if opcode == 0x38 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_s8()
            };
            interp.push(v)?;
        },
        0x3a => { // toss
            interp.pop()?;
        },
        0x3c => { // dup
            let tos = interp.heap.load_u16((interp.regs.sp - 2) as usize);
            interp.push(tos)?;
        },
        0x3e | 0x3f => { // link
            let size = if opcode == 0x3e {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            // Note: SCI1 seems to use sp+2 here ??
            interp.regs.temp_vars = Some(interp.regs.sp);
            for n in 0..size as usize {
                interp.heap.store_u16(interp.regs.sp as usize + n * 2, 0xfade);
            }
            interp.regs.sp = interp.regs.sp + size * 2;
            interp.verify_stack()?;
            println!(">> link: temp_vars now {:x?}, sp {:x}", interp.regs.temp_vars, interp.regs.sp);
        },
        0x40 | 0x41 => { // call
            let relpos = if opcode == 0x40 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_s8()
            };
            let frame_size = interp.load_pc_u8() as u16;
            println!("CALL {:x} {:x} - curious if this is okay", relpos, frame_size);
            let old_pc = interp.regs.pc;
            let old_parm = interp.regs.parm_vars;
            let old_temp = interp.regs.temp_vars;
            let parm_vars = interp.regs.sp - frame_size - interp.regs.rest;
            interp.regs.parm_vars = Some(parm_vars);

            // Update parameter count
            let mut v = interp.heap.load_u16(parm_vars as usize);
            v += interp.regs.rest / 2;
            interp.heap.store_u16(parm_vars as usize, v);
            interp.regs.rest = 0;

            // Handle the call
            interp.regs.pc = interp.regs.pc.overflowing_add(relpos).0;
            interp.run_pmachine()?;

            // Restore registers
            interp.regs.sp = parm_vars - 2;
            interp.regs.parm_vars = old_parm;
            interp.regs.temp_vars = old_temp;
            interp.regs.pc = old_pc;
        },
        0x42 | 0x43 => { // callk
            let nr = if opcode == 0x42 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            // TODO: &rest could be a later SCI0 addition ...
            let nr_parms = interp.load_pc_u8() as u16;
            interp.regs.sp = interp.regs.sp - (nr_parms + 2 + interp.regs.rest);

            // Update parameter count
            let mut v = interp.heap.load_u16(interp.regs.sp as usize);
            v += interp.regs.rest / 2;
            interp.heap.store_u16(interp.regs.sp as usize, v);
            interp.regs.rest = 0;

            // Gather parameters and handle kernel function
            let mut args = Vec::new();
            let nr_parms = nr_parms + 2; // argument count
            for n in (0..nr_parms).step_by(2) {
                let value = interp.heap.load_u16((interp.regs.sp + n) as usize);
                args.push(value);
            }
            kernel::handle_kcall(interp, nr, &args)?;

            // Restore registers
            // XXX We need to restore sp ??
        }
        0x44 | 0x45 => { // callb,
            let disp_index = if opcode == 0x44 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let nr_parms = interp.load_pc_u8() as u16;
            interp.call_external_script(0, disp_index, nr_parms)?;
        },
        0x46 | 0x47 => { // calle
            let script_num;
            let disp_index;
            if opcode == 0x46 {
                script_num = interp.load_pc_u16();
                disp_index = interp.load_pc_u16();
            } else {
                script_num = interp.load_pc_u8() as u16;
                disp_index = interp.load_pc_u8() as u16;
            };
            let nr_parms = interp.load_pc_u8() as u16;
            interp.call_external_script(script_num, disp_index, nr_parms)?;
        },
        0x48 => { // ret
            return Ok(());
        },
        0x49 | 0x4a => { // send
            let nr_parms = interp.load_pc_u8() as u16;
            interp.handle_send(interp.regs.acc, interp.regs.acc, nr_parms)?;
        },
        0x50 | 0x51 => { // class
            let class_id = if opcode == 0x50 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            interp.regs.acc = interp.get_class_offset(class_id)? as u16;
        },
        0x54 => { // interp
            let nr_parms = interp.load_pc_u8() as u16;
            interp.handle_send(interp.regs.object, interp.regs.object, nr_parms)?;
        },
        0x56 | 0x57 => { // super
            let class_id = if opcode == 0x56 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let nr_parms = interp.load_pc_u8() as u16;
            let class = interp.get_class_offset(class_id)? as u16;
            interp.handle_send(interp.regs.object, class, nr_parms)?;
        },
        0x59 => { // &rest
            let param_index = interp.load_pc_u8() as u16;

            let parm_vars = interp.regs.parm_vars.expect("&rest without local parms");

            // Argument count is first value on parameter stack
            let argc = interp.heap.load_u16(parm_vars as usize);
            if DEBUG_REST {
                println!("&rest: current argc {}", argc);
            }
            for n in 0..argc {
                let value = interp.heap.load_u16((parm_vars + n) as usize);
                if DEBUG_REST {
                    println!("  arg {}: 0x{:x} {}", n, value, value);
                }
            }

            let extra_params = if argc >= param_index { (argc - param_index) + 1 } else { 0 };
            if DEBUG_REST {
                println!("argc {} param_index {} -> extra_params {}", argc, param_index, extra_params);
            }
            for n in 0..extra_params {
                let value = interp.heap.load_u16((parm_vars + (param_index + n) * 2) as usize);
                if DEBUG_REST {
                    println!("  adding arg {}: 0x{:x} {}", n, value, value);
                }
                interp.push(value)?;
            }
            interp.regs.rest += extra_params * 2;
            if DEBUG_REST {
                println!(">>> &rest -> rest reg now {}", interp.regs.rest);
                println!("dumping last few args...");
                for n in 1..10 {
                    let sp_mod = n * 2;
                    let value = interp.heap.load_u16((interp.regs.sp - sp_mod) as usize);
                    println!("  sp-{}: arg {}: {} {:x}", sp_mod, n, value, value);
                }
            }
        },
        0x5a | 0x5b => { // lea
            let typ;
            let index;
            if opcode == 0x5a {
                typ = interp.load_pc_u16();
                index = interp.load_pc_u16();
            } else {
                typ = interp.load_pc_u8() as u16;
                index = interp.load_pc_u8() as u16;
            }

            let vtype = (typ >> 1) & 3;
            let acc_index = (typ & 0x10) != 0;
            let mut address = match vtype {
                0 => interp.regs.global_vars,
                1 => interp.regs.local_vars.expect("lea without local_vars"),
                2 => interp.regs.temp_vars.expect("lea without temp_vars"),
                3 => interp.regs.parm_vars.expect("lea without parm_vars"),
                _ => unreachable!()
            };
            if acc_index {
                address = address.overflowing_add(interp.regs.acc * 2).0;
            }
            interp.regs.acc = address.overflowing_add(index * 2).0;
        },
        0x5c => { // interpid
            interp.regs.acc = interp.regs.object;
        },
        0x60 => { // pprev
            interp.push(interp.regs.prev)?;
        },
        0x62 | 0x63 => { // pToa
            let offset = if opcode == 0x62 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let value = interp.heap.load_u16(interp.regs.object as usize + offset as usize);
            interp.regs.acc = value;
        },
        0x64 | 0x65 => { // aTop
            let offset = if opcode == 0x64 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            interp.heap.store_u16(interp.regs.object as usize + offset as usize, interp.regs.acc);
        },
        0x66 | 0x67 => { // pTos
            let offset = if opcode == 0x66 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let value = interp.heap.load_u16(interp.regs.object as usize + offset as usize);
            interp.push(value)?;
        },
        0x68 | 0x69 => { // sTop
            let offset = if opcode == 0x68 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let value = interp.pop()?;
            interp.heap.store_u16(interp.regs.object as usize + offset as usize, value);
        },
        0x6a | 0x6b => { // ipToa
            let offset = if opcode == 0x6a {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let prop_offset = interp.regs.object as usize + offset as usize;
            let value = interp.heap.load_u16(prop_offset).overflowing_add(1).0;
            interp.heap.store_u16(prop_offset, value);
            interp.regs.acc = value;
        },
        0x6c | 0x6d => { // dpToa
            let offset = if opcode == 0x6c {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let prop_offset = interp.regs.object as usize + offset as usize;
            let value = interp.heap.load_u16(prop_offset).overflowing_sub(1).0;
            interp.heap.store_u16(prop_offset, value);
            interp.regs.acc = value;
        },
        0x6e | 0x6f => { // ipTos
            let offset = if opcode == 0x6e {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let prop_offset = interp.regs.object as usize + offset as usize;
            let value = interp.heap.load_u16(prop_offset).overflowing_add(1).0;
            interp.heap.store_u16(prop_offset, value);
            interp.push(value)?;
        },
        0x70 | 0x71 => { // dpTos
            let offset = if opcode == 0x70 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            let prop_offset = interp.regs.object as usize + offset as usize;
            let value = interp.heap.load_u16(prop_offset).overflowing_sub(1).0;
            interp.heap.store_u16(prop_offset, value);
            interp.push(value)?;
        },
        0x72 | 0x73 => { // lofsa
            let offset = if opcode == 0x72 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            println!("lofsa: pc {:x}, offset {:x} -> {:x}",
                interp.regs.pc, offset,
                interp.regs.pc.overflowing_add(offset).0
            );
            interp.regs.acc = interp.regs.pc.overflowing_add(offset).0;
        },
        0x74 | 0x75 => { // lofss
            let offset = if opcode == 0x72 {
                interp.load_pc_u16()
            } else {
                interp.load_pc_u8() as u16
            };
            interp.push(interp.regs.pc.overflowing_add(offset).0)?;
        },
        0x76 => { // push0
            interp.push(0)?;
        },
        0x78 => { // push1
            interp.push(1)?;
        },
        0x7a => { // push2
            interp.push(2)?;
        },
        0x7c => { // pushinterp
            interp.push(interp.regs.object)?;
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
                interp.load_pc_u8() as u16
            } else {
                interp.load_pc_u16()
            };

            let mut var_offset;
            match typ {
                0 => { // global
                    var_offset = interp.regs.global_vars.overflowing_add(index * 2).0;
                },
                1 => { // local
                    var_offset = interp.regs.local_vars.expect("opcode without local_vars").overflowing_add(index * 2).0;
                },
                2 => { // temporary
                    var_offset = interp.regs.temp_vars.expect("opcode without temp_vars").overflowing_add(index * 2).0;
                },
                3 => { // parameter
                    var_offset = interp.regs.parm_vars.expect("opcode without parm_vars").overflowing_add(index * 2).0;
                },
                _ => unreachable!()
            };
            if acc_modifier {
                var_offset = var_offset.overflowing_add(interp.regs.acc * 2).0;
            }

            match oper {
                2 => { /* increment var, then load to acc/stack */
                    let mut v = interp.heap.load_u16(var_offset as usize);
                    v = v.overflowing_add(1).0;
                    interp.heap.store_u16(var_offset as usize, v);
                    oper = 0;
                },
                3 => { /* decrement var, then load to acc/stack */
                    let mut v = interp.heap.load_u16(var_offset as usize);
                    v = v.overflowing_sub(1).0;
                    interp.heap.store_u16(var_offset as usize, v);
                    oper = 0;
                },
                _ => {}
            };

            match oper {
                0 => { // load variable to acc/stack
                    let v = interp.heap.load_u16(var_offset as usize);
                    if on_stack {
                        interp.push(v)?;
                    } else {
                        interp.regs.acc = v;
                    }
                },
                1 => { // store acc/stack to variable
                    // if !on_stack && acc_modifier {
                    //    todo!("special case?");
                    // }
                    let v = if on_stack {
                        interp.pop()?
                    } else {
                        interp.regs.acc
                    };
                    interp.heap.store_u16(var_offset as usize, v);
                },
                _ => unreachable!()
            };
        },
        _ => { todo!("unimplemented opcode {:x}", opcode); }
    }
    Ok(())
}
