use anyhow::Result;

pub struct Text {
    items: Vec<Vec<u8>>
}

impl Text {
    pub fn new(data: &[u8]) -> Result<Self> {
        let mut items = Vec::new();
        let mut current_item = Vec::new();
        for n in 0..data.len() {
            let value = data[n];
            if value == 0 {
                items.push(current_item);
                current_item = Vec::new();
            } else {
                current_item.push(value);
            }
        }
        if !current_item.is_empty() {
            items.push(current_item);
        }
        Ok(Self{ items })
    }

    pub fn get_item(&self, index: usize) -> Option<&[u8]> {
        return if index < self.items.len() {
            Some(&self.items[index])
        } else {
            None
        }
    }
}
