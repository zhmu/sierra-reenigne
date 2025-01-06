use sdl2::{
    pixels,
    rect::Point,
    render::Canvas,
    video::Window
};

use crate::scigfx::{picture, view0};

pub const SCALE: f32 = 2.0;
pub const SCREEN_WIDTH: i32 = 320;
pub const SCREEN_HEIGHT: i32 = 200;

fn resolve_palette_to_rgb(palette: &[u8], index: u8) -> pixels::Color {
    let index = index as usize;
    let r = palette[index * 3 + 0];
    let g = palette[index * 3 + 1];
    let b = palette[index * 3 + 2];
    pixels::Color::RGB(r, g, b)
}

pub fn put_pixel(canvas: &mut Canvas<Window>, x: i32, y: i32, color: pixels::Color) {
    canvas.set_draw_color(color);
    canvas.draw_point(Point::new(x, y)).unwrap()
}

pub fn render_pic(canvas: &mut Canvas<Window>, pic: &picture::Picture, palette: &[u8]) {
    for y in 0..SCREEN_HEIGHT {
        for x in 0..SCREEN_WIDTH {
            let index = pic.visual[((y * SCREEN_WIDTH) + x) as usize];
            let color = resolve_palette_to_rgb(palette, index);
            put_pixel(canvas, x, y, color);
        }
    }
}

pub fn render_view(canvas: &mut Canvas<Window>, view: &view0::View0, palette: &[u8], group: usize, image: usize, base_x: i32, base_y: i32) {
    let image = &view.groups[group].images[image];
    let x_mod: i32 = image.x_place_mod.into();
    let y_mod: i32 = image.y_place_mod.into();
    for y in 0..image.height as i32 {
        for x in 0..image.width as i32 {
            let index = image.visual[((y * image.width as i32) + x as i32) as usize];
            if index == image.color_key { continue; }
            let color = resolve_palette_to_rgb(palette, index);
            put_pixel(canvas, base_x + x_mod + x, base_y + y_mod + y, color);
        }
    }
}
