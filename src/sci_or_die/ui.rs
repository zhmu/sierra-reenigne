use sdl2::{
    pixels,
    rect::Point,
    event::Event,
    keyboard::Keycode,
    render::Canvas,
    video::Window,
};
use crate::{
    scigfx::palette,
    sci_or_die::{render},
};

use anyhow::{anyhow, Result};

pub const SCALE: f32 = 2.0;

pub struct UI {
    _sdl_context: sdl2::Sdl,
    event_pump: sdl2::EventPump,
    canvas: Canvas<Window>,
    palette: [ u8; 768 ],
}

pub enum SciEvent {
    Terminate,
    Key(char),
}

impl UI {
    pub fn new() -> Result<UI> {
        let sdl_context = sdl2::init().map_err(|e| anyhow!("cannot init sdl2: {}", e))?;
        let video_subsystem = sdl_context.video().unwrap();
        let window = video_subsystem.window("SCI or die", (render::SCREEN_WIDTH as f32 * SCALE) as u32, (render::SCREEN_HEIGHT as f32 * SCALE) as u32)
            .build()
            .map_err(|e| anyhow!("cannot create sdl2 window: {}", e))?;
        let mut canvas = window
            .into_canvas()
            .accelerated()
            .build()
            .map_err(|e| anyhow!("cannot create sdl2 canvas: {}", e))?;
        canvas.set_scale(SCALE, SCALE).expect("cannot set scale");

        let event_pump = sdl_context.event_pump().unwrap();

        let mut palette = [ 0u8; 768 ];
        palette::fill_ega_colours(&mut palette);
        Ok(Self{_sdl_context: sdl_context, canvas, event_pump, palette})
    }

    pub fn render(&mut self, framebuffer: &render::Framebuffer) {
        for y in 0..render::SCREEN_HEIGHT {
            for x in 0..render::SCREEN_WIDTH {
                let index = framebuffer.pixels[((y * render::SCREEN_WIDTH) + x) as usize];
                let color = self.lookup_palette_color(index);
                self.canvas.set_draw_color(color);
                self.canvas.draw_point(Point::new(x, y)).unwrap()
            }
        }
        self.canvas.present();
    }

    pub fn pump_events(&mut self) -> Option<SciEvent> {
        for event in self.event_pump.poll_iter() {
            match event {
                Event::Quit {..} => {
                    return Some(SciEvent::Terminate);
                },
                Event::KeyDown{ keycode: kc, .. } => {
                    if let Some(key) = kc {
                        match key {
                            Keycode::Escape => { return Some(SciEvent::Terminate); },
                            Keycode::Return => { return Some(SciEvent::Key('\n')); },
                            _ => {}
                        }
                    }
                },
                _ => {}
            }
        }
        None
    }

    fn lookup_palette_color(&self, index: u8) -> pixels::Color {
        let index = index as usize;
        let r = self.palette[index * 3 + 0];
        let g = self.palette[index * 3 + 1];
        let b = self.palette[index * 3 + 2];
        pixels::Color::RGB(r, g, b)
    }
}
