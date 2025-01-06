use crate::sciscript::opcode;
use std::io::Cursor;
use byteorder::{ReadBytesExt, LittleEndian};

pub type ArgType = u16;

pub struct Instruction<'a> {
    pub offset: usize,
    pub bytes: &'a [u8],
    pub opcode: &'static opcode::Opcode,
    pub args: Vec<ArgType>,
}

pub struct Disassembler<'a> {
    base: usize,
    rdr: Cursor<&'a [u8]>,
}

impl<'a> Disassembler<'a> {
    pub fn new(base: usize, data: &'a [u8]) -> Disassembler<'a> {
        let rdr = Cursor::new(data);
        Disassembler{ base, rdr }
    }

    pub fn new1(base: usize, data: &'a [u8]) -> Disassembler<'a> {
        let rdr = Cursor::new(data);
        Disassembler{ base, rdr }
    }
}

impl<'a> Iterator for Disassembler<'a> {
    type Item = Instruction<'a>;

    fn next(&mut self) -> Option<Instruction<'a>> {
        let offset = self.rdr.position() as usize;
        let opcode = self.rdr.read_u8();
        if opcode.is_err() { return None }

        let opcode = &opcode::OPCODES[opcode.unwrap() as usize];
        let mut args: Vec<ArgType> = Vec::new();
        for arg in opcode.arg {
            match arg {
                opcode::Arg::RelPos8 | opcode::Arg::Imm8 => {
                    let value = self.rdr.read_u8();
                    if value.is_err() { return None }
                    args.push(value.unwrap().into());
                },
                opcode::Arg::RelPos16 | opcode::Arg::Imm16 => {
                    let value = self.rdr.read_u16::<LittleEndian>();
                    if value.is_err() { return None }
                    args.push(value.unwrap());
                },
            }
        }
        let bytes = &self.rdr.get_ref()[offset..self.rdr.position() as usize];
        Some(Instruction{ offset: self.base + offset, bytes, opcode, args })
    }
}

// Note: always uses the first argument
pub fn relpos0_to_absolute_offset(ins: &Instruction) -> u16
{
    let a_type = &ins.opcode.arg[0];
    let a_value: usize = ins.args[0].into();
    let offset: usize = ins.offset as usize + ins.bytes.len();
    match a_type {
        opcode::Arg::RelPos8 => {
            let j_offset: usize;
            if (a_value & 0x80) == 0 {
                j_offset = offset + a_value;
            } else {
                j_offset = offset - (0x100 - a_value);
            }
            j_offset as u16
        }
        opcode::Arg::RelPos16 => {
            let j_offset = (offset + a_value) & 0xffff;
            j_offset as u16
        }
        _ => { panic!("only to be called with relative positions"); }
    }
}

pub fn sci0_get_lofsa_address(ins: &Instruction, offset: u16) -> u16 {
    ((offset as usize + ins.bytes.len() + ins.args[0] as usize) & 0xffff) as u16
}

pub fn sci1_get_lofsa_address(ins: &Instruction) -> u16 {
    // lofsa is not relative in SCI1 (at least in QfG3)
    ins.args[0]
}
