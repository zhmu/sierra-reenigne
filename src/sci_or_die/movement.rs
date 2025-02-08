use crate::{
    sci_or_die::{interp},
};
use anyhow::{anyhow, Result};

const DEBUG_BRESEN: bool = false;

const SEL_Y: u16 = 3;
const SEL_X: u16 = 4;
const SEL_SIGNAL: u16 = 17;
const SEL_CLIENT: u16 = 45;
const SEL_DX: u16 = 46;
const SEL_DY: u16 = 47;
const SEL_MOVECNT: u16 = 48;
const SEL_I1: u16 = 49;
const SEL_I2: u16 = 50;
const SEL_DI: u16 = 51;
const SEL_XAXIS: u16 = 52;
const SEL_INCR: u16 = 53;
const SEL_XSTEP: u16 = 54;
const SEL_YSTEP: u16 = 55;
const SEL_MOVESPEED: u16 = 56;
const SEL_XLAST: u16 = 168;
const SEL_YLAST: u16 = 169;
const SEL_CANBEHERE: u16 = 57;
const SEL_MOVEDONE: u16 = 170;

const SIGNAL_HIT_OBSTACLE: u16 = 0x400;

// This is a port of ScummVM's kInitBresen in kmovement.cpp
pub fn init_bresen(interp: &mut interp::Interpreter, mover: u16, step_factor: u16) -> Result<()> {
    let client = interp.read_object_by_selector(mover, SEL_CLIENT)?;
    let mover_x = interp.read_object_by_selector(mover, SEL_X)? as i16;
    let mover_y = interp.read_object_by_selector(mover, SEL_Y)? as i16;

    let mut client_xstep = (interp.read_object_by_selector(client, SEL_XSTEP)? * step_factor) as i16;
    let client_ystep = (interp.read_object_by_selector(client, SEL_YSTEP)? * step_factor) as i16;
    let mut client_step = if client_xstep < client_ystep {
        client_ystep * 2
    } else {
        client_xstep * 2
    };

    let delta_x = mover_x - interp.read_object_by_selector(client, SEL_X)? as i16;
    let delta_y = mover_y - interp.read_object_by_selector(client, SEL_Y)? as i16;

    let mut mover_dx: i16;
    let mut mover_dy: i16;
    let mut mover_i1: i16;
    let mut mover_i2: i16;
    let mut mover_di;
    let mut mover_incr;
    let mut mover_xaxis;
    loop {
        mover_dx = client_xstep;
        mover_dy = client_ystep;
        mover_incr = 1;
        if delta_x.abs() >= delta_y.abs() {
            mover_xaxis = 1;
            if delta_x < 0 {
                mover_dx = -mover_dx;
            }
            mover_dy = if delta_x != 0 { mover_dx * delta_y / delta_x } else { 0 };
            mover_i1 = ((mover_dx * delta_y) - (mover_dy * delta_x)) * 2;
            if delta_y < 0 {
                mover_incr = -1;
                mover_i1 = -mover_i1;
            }
            mover_i2 = mover_i1 - (delta_x * 2);
            mover_di = mover_i1 - delta_x;
            if delta_x < 0 {
                mover_i1 = -mover_i1;
                mover_i2 = -mover_i2;
                mover_di = -mover_di;
            }
        } else {
            mover_xaxis = 0;
            if delta_y < 0 {
                mover_dy = -mover_dy;
            }
            mover_dx = if delta_y != 0 { mover_dy * delta_x / delta_y } else { 0 };
            mover_i1 = ((mover_dy * delta_x) - (mover_dx * delta_y)) * 2;
            if delta_x < 0 {
                mover_incr = -1;
                mover_i1 = -mover_i1;
            }
            mover_i2 = mover_i1 - (delta_y * 2);
            mover_di = mover_i1 - delta_y;
            if delta_y < 0 {
                mover_i1 = -mover_i1;
                mover_i2 = -mover_i2;
                mover_di = -mover_di;
            }
            break;
        }
        if client_xstep <= client_ystep { break; }
        if client_xstep == 0 { break; }
        if client_ystep >= (mover_dy + mover_incr).abs() { break; }

        client_step -= 1;
        if client_step == 0 {
            return Err(anyhow!("init_bresen: failed"));
        }
        client_xstep -= 1;
    }
    interp.write_object_by_selector(mover, SEL_DX, mover_dx as u16)?;
    interp.write_object_by_selector(mover, SEL_DY, mover_dy as u16)?;
    interp.write_object_by_selector(mover, SEL_I1, mover_i1 as u16)?;
    interp.write_object_by_selector(mover, SEL_I2, mover_i2 as u16)?;
    interp.write_object_by_selector(mover, SEL_DI, mover_di as u16)?;
    interp.write_object_by_selector(mover, SEL_INCR, mover_incr as u16)?;
    interp.write_object_by_selector(mover, SEL_XAXIS, mover_xaxis as u16)?;

    if DEBUG_BRESEN {
        println!("kInitBresen: mover {:04x} client {:04x} ({}, {}) -> ({}, {}) => dx {} dy {} i1 {} i2 {} di {} incr {} xaxis {}",
        mover, client,
        mover_x, mover_y,
        interp.read_object_by_selector(client, SEL_X)?,
        interp.read_object_by_selector(client, SEL_Y)?,
        mover_dx, mover_dy, mover_i1, mover_i2, mover_di, mover_incr, mover_xaxis);
    }

    Ok(())
}

// This is a port of ScummVM's kDoBresen in kmovement.cpp
pub fn do_bresen(interp: &mut interp::Interpreter, mover: u16) -> Result<()> {
    let client = interp.read_object_by_selector(mover, SEL_CLIENT)?;
    let mut completed = false;

    let client_signal = interp.read_object_by_selector(client, SEL_SIGNAL)?;
    interp.write_object_by_selector(client, SEL_SIGNAL, client_signal & !SIGNAL_HIT_OBSTACLE)?;

    // let handle_move_count = true;
    let mover_move_count = interp.read_object_by_selector(mover, SEL_MOVECNT)? + 1;
    let client_movespeed = interp.read_object_by_selector(client, SEL_MOVESPEED)?;

    if client_movespeed < mover_move_count {
        let mut client_x = interp.read_object_by_selector(client, SEL_X)? as i16;
        let mut client_y = interp.read_object_by_selector(client, SEL_Y)? as i16;
        let mover_x = interp.read_object_by_selector(mover, SEL_X)? as i16;
        let mover_y = interp.read_object_by_selector(mover, SEL_Y)? as i16;
        let mover_xaxis = interp.read_object_by_selector(mover, SEL_XAXIS)? as i16;
        let mover_dx = interp.read_object_by_selector(mover, SEL_DX)? as i16;
        let mover_dy = interp.read_object_by_selector(mover, SEL_DY)? as i16;
        let mover_incr = interp.read_object_by_selector(mover, SEL_INCR)? as i16;
        let mut mover_i1 = interp.read_object_by_selector(mover, SEL_I1)? as i16;
        let mut mover_i2 = interp.read_object_by_selector(mover, SEL_I2)? as i16;
        let mut mover_di = interp.read_object_by_selector(mover, SEL_DI)? as i16;
        let mover_org_i1 = mover_i1;
        let mover_org_i2 = mover_i2;
        let mover_org_di = mover_di;

        interp.write_object_by_selector(mover, SEL_XLAST, client_x as u16)?;
        interp.write_object_by_selector(mover, SEL_YLAST, client_y as u16)?;

        let var_backup = interp.read_variables(client)?;

        if true /* ega only */ {
            if mover_xaxis != 0 {
                if (mover_x - client_x).abs() < mover_dx.abs() {
                    completed = true;
                }
            } else {
                if (mover_y - client_y).abs() < mover_y.abs() {
                    completed = true;
                }
            }
        }

        if completed {
            client_x = mover_x;
            client_y = mover_y;
        } else {
            client_x += mover_dx;
            client_y += mover_dy;
            if mover_di < 0 {
                mover_di += mover_i1;
            } else {
                mover_di += mover_i2;
                if mover_xaxis == 0 {
                    client_x += mover_incr;
                } else {
                    client_y += mover_incr;
                }
            }
        }
        interp.write_object_by_selector(client, SEL_X, client_x as u16)?;
        interp.write_object_by_selector(client, SEL_Y, client_y as u16)?;

        let mut collision = false;
        interp.regs.acc = 0;
        interp.execute_code(client, SEL_CANBEHERE, &[ mover ])?;
        if interp.regs.acc == 0 {
            collision = true;
        }

        if collision {
            interp.write_variables(client, &var_backup)?;
            mover_i1 = mover_org_i1;
            mover_i2 = mover_org_i2;
            mover_di = mover_org_di;

            let client_signal = interp.read_object_by_selector(client, SEL_SIGNAL)?;
            interp.write_object_by_selector(client, SEL_SIGNAL, client_signal | SIGNAL_HIT_OBSTACLE)?;
        }

        interp.write_object_by_selector(mover, SEL_I1, mover_i1 as u16)?;
        interp.write_object_by_selector(mover, SEL_I2, mover_i2 as u16)?;
        interp.write_object_by_selector(mover, SEL_DI, mover_di as u16)?;
        interp.write_object_by_selector(mover, SEL_MOVECNT, mover_move_count)?;
        if client_x == mover_x && client_y == mover_y {
            interp.execute_code(mover, SEL_MOVEDONE, &[ mover ])?;
        }
    }

    interp.write_object_by_selector(mover, SEL_MOVECNT, mover_move_count)?;
    Ok(())
}
