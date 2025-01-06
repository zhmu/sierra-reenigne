use crate::{
    scigfx::{palette, picture, view0},
    sciscript::{sci0::script0},
    scires::{resource::ResourceID, resource::ResourceType},
    sci_or_die::{render, resman},
};
use std::env;
use sdl2::{
    event::Event,
    keyboard::Keycode
};
use std::time::Duration;
use anyhow::{anyhow, Result};

pub fn run() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        return Err(anyhow!(format!("usage: {} path", args[0])));
    }
    let mut resource_manager = resman::ResourceManager::new(args[1].clone());

    let script_res = resource_manager.get(ResourceID{ rtype: ResourceType::Script, num: 0 });
    let script = script0::Script::new(0, &script_res.data)?;

    let pic_res = resource_manager.get(ResourceID{ rtype: ResourceType::Picture, num: 300 });
    let view_res = resource_manager.get(ResourceID{ rtype: ResourceType::View, num: 0 });

    let sdl_context = sdl2::init().map_err(|e| anyhow!("cannot init sdl2: {}", e))?;
    let video_subsystem = sdl_context.video().unwrap();
    let window = video_subsystem.window("SCI or die", (render::SCREEN_WIDTH as f32 * render::SCALE) as u32, (render::SCREEN_HEIGHT as f32 * render::SCALE) as u32)
        .build()
        .map_err(|e| anyhow!("cannot create sdl2 window: {}", e))?;
    let mut canvas = window
        .into_canvas()
        .accelerated()
        .build()
        .map_err(|e| anyhow!("cannot create sdl2 canvas: {}", e))?;
    canvas.set_scale(render::SCALE, render::SCALE).expect("cannot set scale");

    let pic = picture::Picture::new_pic0(&pic_res.data)?;
    let view = view0::View0::new(&view_res.data)?;

    let mut ega_palette = [ 0u8; 768 ];
    palette::fill_ega_colours(&mut ega_palette);

    let mut event_pump = sdl_context.event_pump().unwrap();
    let mut running = true;
    while running {
        render::render_pic(&mut canvas, &pic, &ega_palette);
        render::render_view(&mut canvas, &view, &ega_palette, 0, 0, 100, 100);

        for event in event_pump.poll_iter() {
            match event {
                Event::Quit {..} | Event::KeyDown { keycode: Some(Keycode::Escape), .. } => {
                    running = false;
                },
                _ => {}
            }
        }

        canvas.present();
        std::thread::sleep(Duration::from_millis(100));
    }
    Ok(())
}
