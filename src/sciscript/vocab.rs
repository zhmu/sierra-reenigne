use byteorder::{LittleEndian, ReadBytesExt, ByteOrder};
use anyhow::{anyhow, Result};
use std::io::Cursor;
use std::str;

pub struct Vocab997 {
    pub words: Vec<String>
}

impl Vocab997 {
    pub fn new(input: &[u8]) -> Result<Vocab997> {
        let count = LittleEndian::read_u16(&input[0..=2]) as usize;
        let mut words: Vec<String> = Vec::with_capacity(count);
        for n in 0..count {
            let offset = LittleEndian::read_u16(&input[2 + n * 2..=4 + n * 2]) as usize;
            let length = LittleEndian::read_u16(&input[offset..=offset + 2]) as usize;
            if offset + 2 + length < input.len() {
                let s = str::from_utf8(&input[offset+2..offset+2+length]).unwrap();
                words.push(s.to_string());
            } else {
                log::warn!("vocab997: offset {}..{} out of resource range, discarding index {}",
                    offset + 2, offset + 2 + length, n);
                words.push("(corrupt)".to_string());
            }
        }

        Ok(Vocab997{ words })
    }

    pub fn get_string(&self, id: usize) -> Option<&String> {
        if id < self.words.len() {
            Some(&self.words[id])
        } else {
            None
        }
    }

    pub fn get_strings(&self) -> &Vec<String> {
        &self.words
    }
}

pub struct Word {
    pub word: String,
    pub class: u16,
    pub group: u16
}

pub struct Vocab000 {
    pub words: Vec<Word>,
}

impl Vocab000 {
    pub fn new(input: &[u8]) -> Result<Vocab000> {
        let mut rdr = Cursor::new(&input);
        for _ in 'A'..='Z' {
            let _offset = rdr.read_u16::<LittleEndian>()?;
        }

        let mut words: Vec<Word> = Vec::new();
        loop {
            let copy_amount = rdr.read_u8();
            if copy_amount.is_err() { break; }
            let copy_amount = copy_amount.unwrap() as usize;

            let mut cur_word: String;
            if let Some(prev_word) = &words.last() {
                if copy_amount > prev_word.word.len() {
                    return Err(anyhow!("cannot copy {} bytes from previous word '{}'", copy_amount, prev_word.word));
                } else {
                    cur_word = prev_word.word[0..copy_amount].to_string();
                }
            } else {
                cur_word = "".to_string();
                if copy_amount != 0 {
                    return Err(anyhow!("vocab tries to copy from nothing"));
                }
            }

            loop {
                let ch = rdr.read_u8()?;
                cur_word.push((ch & 0x7f) as char);
                if (ch & 0x80) != 0 { break; }
            }

            let id1 = rdr.read_u8()? as u32;
            let id2 = rdr.read_u8()? as u32;
            let id3 = rdr.read_u8()? as u32;
            let id = (id1 << 16) | (id2 << 8) | id3;

            let class = ((id >> 12) & 0xfff) as u16;
            let group = (id & 0xfff) as u16;

            words.push(Word{ word: cur_word, class, group });
        }

        Ok(Vocab000{ words })
    }

    pub fn get_words_by_group(&self, group: u16) -> Vec<&Word> {
        self.words.iter().filter(|&w| w.group == group).collect::<Vec<_>>()
    }

}

pub struct Vocab996 {
    classes: Vec<u16>
}

impl Vocab996 {
    pub fn new(input: &[u8]) -> Result<Vocab996> {
        let mut classes: Vec<u16> = Vec::new();

        // LSL3 has an odd vocab.996 resource: the last entry is incomplete
        // and appears to be corrupt. Ensure we only process complete entries
        let mut rdr = Cursor::new(&input);
        let num_classes = input.len() / 4;
        for _ in 0..num_classes {
            let must_be_zero = rdr.read_u16::<LittleEndian>();
            if must_be_zero.is_err() { break; }
            assert_eq!(0, must_be_zero.unwrap());
            let script = rdr.read_u16::<LittleEndian>()?;
            classes.push(script);
        }

        Ok(Vocab996{ classes })
    }

    pub fn get_script(&self, class_id: u16) -> Option<u16> {
        let class_id = class_id as usize;
        if class_id >= self.classes.len() {
            return None;
        }
        Some(self.classes[class_id])
    }

    pub fn get_number_of_classes(&self) -> usize {
        self.classes.len()
    }
}

pub struct Vocab999 {
    strings: Vec<String>
}

impl Vocab999 {
    pub fn new(input: &[u8]) -> Result<Vocab999> {
        // New-style vocab.999 simply contains words seperated by nul
        // characters. We'll just start processing and if we find a charachter that's not
        // in 1..0x7f, reject the vocab
        let mut strings: Vec<String> = Vec::new();

        let mut cur_string = String::new();
        for ch in input {
            match ch {
                0x00 => {
                    strings.push(cur_string.clone());
                    cur_string.clear();
                }
                0x01..=0x7f => {
                    cur_string.push(*ch as char);
                },
                _ => {
                    return Err(anyhow!("found non-ascii char in vocab, rejecting"));
                }
            }
        }
        Ok(Vocab999{ strings })
    }

    pub fn get_string(&self, id: usize) -> Option<&String> {
        if id < self.strings.len() {
            Some(&self.strings[id])
        } else {
            None
        }
    }

    pub fn get_strings(&self) -> &Vec<String> {
        &self.strings
    }
}
