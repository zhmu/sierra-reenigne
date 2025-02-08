use crate::scigfx::{picture, view0};

pub const SCREEN_WIDTH: i32 = 320;
pub const SCREEN_HEIGHT: i32 = 200;

pub struct Framebuffer {
    pub pixels: [ u8; (SCREEN_HEIGHT * SCREEN_WIDTH) as usize ],
}

impl Framebuffer {
    pub fn new() -> Self {
        let pixels = [ 0u8; (SCREEN_HEIGHT * SCREEN_WIDTH) as usize ];
        Self{ pixels }
    }

    pub fn put_pixel(&mut self, x: i32, y: i32, value: u8) {
        if x >= 0 && y >= 0 && x < SCREEN_WIDTH && y < SCREEN_HEIGHT {
            self.pixels[((y * SCREEN_WIDTH) + x) as usize] = value;
        }
    }

    pub fn render_pic(&mut self, pic: &picture::Picture) {
        for y in 0..SCREEN_HEIGHT {
            for x in 0..SCREEN_WIDTH {
                let value = pic.visual[((y * SCREEN_WIDTH) + x) as usize];
                self.put_pixel(x, y, value);
            }
        }
    }

    pub fn render_view(&mut self, view: &view0::View0, group: usize, image: usize, base_x: i32, base_y: i32) {
        let image = &view.groups[group].images[image];
        let x_mod: i32 = image.x_place_mod.into();
        let y_mod: i32 = image.y_place_mod.into();
        for y in 0..image.height as i32 {
            for x in 0..image.width as i32 {
                let value = image.visual[((y * image.width as i32) + x as i32) as usize];
                if value == image.color_key { continue; }
                self.put_pixel(base_x + x_mod + x, base_y + y_mod + y, value);
            }
        }
    }
}
