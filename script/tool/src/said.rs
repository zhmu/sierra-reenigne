use byteorder::ReadBytesExt;
use std::io::Cursor;

use anyhow::Result;
use crate::vocab;
use crate::sci0::script0;

fn said_operator_to_char(op: u8) -> char {
    match op {
        0xf0 => ',',
        0xf1 => '&',
        0xf2 => '/',
        0xf3 => '(',
        0xf4 => ')',
        0xf5 => '[',
        0xf6 => ']',
        0xf7 => '#',
        0xf8 => '<',
        0xf9 => '>',
        _ => '?'
    }
}

pub struct SaidItem {
    pub offset: usize,
    pub said: String
}

pub struct Said {
    pub items: Vec<SaidItem>
}

impl Said {
    pub fn new(block: &script0::ScriptBlock, vocab: &vocab::Vocab000) -> Result<Said> {
        let mut rdr = Cursor::new(&block.data);
        let mut current_position: usize = 0;
        let mut current_said: String = "".to_string();

        let mut items: Vec<SaidItem> = Vec::new();
        loop {
            let token = rdr.read_u8();
            if token.is_err() { break; }
            let token = token.unwrap();
            if token == 0xff {
                items.push(SaidItem{ offset: block.base + current_position, said: current_said });
                current_said = "".to_string();
                current_position = rdr.position() as usize;
            } else if token >= 0xf0 {
                current_said += &format!("{} ", said_operator_to_char(token)).to_string();
            } else {
                let byte = rdr.read_u8();
                if byte.is_err() { break; }
                let group = ((token as u16) << 8) | byte.unwrap() as u16;

                let words = vocab.get_words_by_group(group);
                current_said += "{";
                for w in words {
                    current_said += &format!(" {}", w.word);
                }
                current_said += " }";
            }
        }
        Ok(Said{ items })
    }
}
