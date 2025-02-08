use crate::{
    scires::resource,
    scigfx::{font, picture, view0},
    sci_or_die::{interp, render},
};
use anyhow::Result;

const DEBUG_ANIMATE: bool = true;

const SEL_Y: u16 = 3;
const SEL_X: u16 = 4;
const SEL_VIEW: u16 = 5;
const SEL_LOOP: u16 = 6;
const SEL_CEL: u16 = 7;
const SEL_NS_TOP: u16 = 9;
const SEL_NS_LEFT: u16 = 10;
const SEL_NS_BOTTOM: u16 = 11;
const SEL_NS_RIGHT: u16 = 12;
const _SEL_SIGNAL: u16 = 17;
const SEL_TEXT: u16 = 26;
const SEL_MODE: u16 = 30;
const SEL_FONT: u16 = 33;
const SEL_TYPE: u16 = 34;
const SEL_DOIT: u16 = 60;
const SEL_PRIORITY: u16 = 63;

const D_TYPE_TEXT: u16 = 2;

pub struct Point {
    pub x: i32,
    pub y: i32,
}

pub struct Rect {
    pub top: i32,
    pub left: i32,
    pub bottom: i32,
    pub right: i32,
}

#[derive(Debug)]
struct AnimateEntry {
    object: u16,
    y: u16,
    priority: u16,
}

pub struct Port {
    pub rect: Rect,
}

impl Port {
    pub fn new(rect: Rect) -> Self {
        Self{rect}
    }
}

pub struct State {
    framebuffer: render::Framebuffer,
    pic_not_valid: u8,
    pic_port: Port,
}

impl State {
    pub fn new() -> Self {
        let framebuffer = render::Framebuffer::new();
        let pic_rect = Rect{ top: 10, left: 0, bottom: 200, right: 320 };
        Self{ framebuffer, pic_not_valid: 0, pic_port: Port::new(pic_rect) }
    }
}

pub fn draw_pic(interp: &mut interp::Interpreter, pic_nr: u16, _animation: u16, _flags: u16) {
    interp.gfx.pic_not_valid = 1;

    let pic_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::Picture, num: pic_nr });
    let pic = picture::Picture::new_pic0(interp.gfx.pic_port.rect.left, interp.gfx.pic_port.rect.top, &pic_res.data).expect("cannot load pic");
    interp.gfx.framebuffer.render_pic(&pic);
}

fn draw_text(interp: &mut interp::Interpreter, control: u16) -> Result<()> {
    let text = interp.read_object_by_selector(control, SEL_TEXT).unwrap() as usize;
    let font = interp.read_object_by_selector(control, SEL_FONT).unwrap();
    let _mode = interp.read_object_by_selector(control, SEL_MODE).unwrap();
    let ns_top = interp.read_object_by_selector(control, SEL_NS_TOP).unwrap();
    let ns_left = interp.read_object_by_selector(control, SEL_NS_LEFT).unwrap();
    let ns_bottom = interp.read_object_by_selector(control, SEL_NS_BOTTOM).unwrap();
    let ns_right = interp.read_object_by_selector(control, SEL_NS_RIGHT).unwrap();

    let font_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::Font, num: font });
    let font = font::Font::new(&font_res.data)?;

    let port_x = interp.gfx.pic_port.rect.left;
    let port_y = interp.gfx.pic_port.rect.top;
    let pen_colour = 4; // TODO: this should come from the port

    println!("text: {} {} {} {}", ns_left, ns_top, ns_right, ns_bottom);
    let mut n: usize = 0;
    let mut base_x = ns_left;
    let mut base_y = ns_top;
    loop {
        let ch = interp.heap.load_u8(text + n);
        n += 1;
        if ch == 0 { break; }
        if ch == b'\n' {
            base_x = ns_left;
            base_y += font.get_height();
            continue;
        }

        font.render(ch, &mut |x, y| {
            interp.gfx.framebuffer.put_pixel(port_x + (base_x + x) as i32, port_y + (base_y + y) as i32, pen_colour);
        });
        base_x += font.get_char_width(ch as usize) as u16;

    }
    Ok(())
}

pub fn draw_control(interp: &mut interp::Interpreter, control: u16) -> Result<()> {
    let d_type = interp.read_object_by_selector(control, SEL_TYPE).unwrap();

    match d_type {
        D_TYPE_TEXT => { draw_text(interp, control) },
        _ => { log::warn!("draw_control(): unrecognized type {}, ignored", d_type); Ok(()) }
    }
}

pub fn text_size(interp: &mut interp::Interpreter, font_nr: u16, offset: u16) -> Result<(u16, u16)> {
    let font_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::Font, num: font_nr });
    let font = font::Font::new(&font_res.data)?;

    let mut height: u16 = font.get_height();
    let mut width: u16 = 0;
    let mut line_width: u16 = 0;
    let mut n: usize = 0;
    loop {
        let ch = interp.heap.load_u8(offset as usize + n);
        if ch == 0 { break; }
        n += 1;

        if ch == b'\n' {
            width = std::cmp::max(width, line_width);
            line_width = 0;
            height += font.get_height();
        } else {
            line_width += font.get_char_width(ch as usize) as u16;
        }
    }
    width = std::cmp::max(width, line_width);
    Ok((width, height))
}

fn pri_coord(y: u16) -> u16 {
    y
}

fn create_animate_list(interp: &mut interp::Interpreter, list: &[u16]) -> Result<Vec<AnimateEntry>> {
    let mut items = Vec::new();
    for object in list {
        let object = *object;
        let y = interp.read_object_by_selector(object, SEL_Y)?;
        let mut priority = interp.read_object_by_selector(object, SEL_PRIORITY)?;
        if priority == u16::MAX {
            priority = pri_coord(y);
        }
        items.push(AnimateEntry{
            object,
            y,
            priority
        });
    }
    items.sort_by_key(|item| (item.priority, item.y));
    Ok(items)
}

pub fn animate(interp: &mut interp::Interpreter, cast: u16) -> Result<()> {
    if cast == 0 {
        log::warn!("TODO: animate() called without a cast list");
        return Ok(());
    }

    if let Some(list) = interp.find_list_by_handle(cast) {
        let object_ids: Vec<_> = list.items.iter().map(|e| interp.find_node_by_handle(*e).expect("add_to_pic: node not found").value).collect();
        let items = create_animate_list(interp, &object_ids)?;
        for item in &items {
            interp.execute_code(item.object, SEL_DOIT, &[])?;
        }

        // Create new animate list
        let list = interp.find_list_by_handle(cast).expect("cast list became invalid after doit() !");
        let object_ids: Vec<_> = list.items.iter().map(|e| interp.find_node_by_handle(*e).expect("add_to_pic: node invalid after doit() !").value).collect();
        let items = create_animate_list(interp, &object_ids)?;

        let port_x = interp.gfx.pic_port.rect.left;
        let port_y = interp.gfx.pic_port.rect.top;

        // TODO: determine the actual difference between this and add_to_pic()
        for (n, item) in items.iter().enumerate() {
            let view_num = interp.read_object_by_selector(item.object, SEL_VIEW)?;

            let view_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::View, num: view_num });
            let view = view0::View0::new(&view_res.data)?;

            let loop_index = interp.read_object_by_selector(item.object, SEL_LOOP)?;
            let cel_index = interp.read_object_by_selector(item.object, SEL_CEL)?;
            let x = interp.read_object_by_selector(item.object, SEL_X)?;
            let y = item.y;
            if DEBUG_ANIMATE {
                println!("animate: item {}, object {:04x} x {} y {} view {} loop {} cel {}", n, item.object,
                    x, y, view_num, loop_index, cel_index);
            }
            interp.gfx.framebuffer.render_view(&view, loop_index as usize, cel_index as usize, port_x + x as i32, port_y + y as i32);
        }
    }
    render(interp);
    Ok(())
}

pub fn add_to_pic(interp: &mut interp::Interpreter, cast: u16) -> Result<()> {
    if cast == 0 { return Ok(()); }
    if let Some(list) = interp.find_list_by_handle(cast) {
        let object_ids: Vec<_> = list.items.iter().map(|e| interp.find_node_by_handle(*e).expect("add_to_pic: node not found").value).collect();
        let items = create_animate_list(interp, &object_ids)?;

        let port_x = interp.gfx.pic_port.rect.left;
        let port_y = interp.gfx.pic_port.rect.top;

        // TODO: determine the actual difference between this and animate()
        for (n, item) in items.iter().enumerate() {
            let view_num = interp.read_object_by_selector(item.object, SEL_VIEW)?;

            let view_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::View, num: view_num });
            let view = view0::View0::new(&view_res.data)?;

            let loop_index = interp.read_object_by_selector(item.object, SEL_LOOP)?;
            let cel_index = interp.read_object_by_selector(item.object, SEL_CEL)?;
            let x = interp.read_object_by_selector(item.object, SEL_X)?;
            let y = item.y;
            if DEBUG_ANIMATE {
                println!("add_to_pic: item {}, object {:04x} x {} y {} view {} loop {} cel {}", n, item.object,
                    x, y, view_num, loop_index, cel_index);
            }
            interp.gfx.framebuffer.render_view(&view, loop_index as usize, cel_index as usize, port_x + x as i32, port_y + y as i32);
        }
    } else {
        todo!("cast list not found");
    }
    render(interp);
    Ok(())
}

pub fn num_cells(interp: &mut interp::Interpreter, object: u16) -> Result<()> {
    let view_num = interp.read_object_by_selector(object, SEL_VIEW)?;
    let loop_index = interp.read_object_by_selector(object, SEL_LOOP)?;

    let view_res = interp.resman.get(resource::ResourceID{ rtype: resource::ResourceType::View, num: view_num });
    let view = view0::View0::new(&view_res.data)?;

    let group = &view.groups[loop_index as usize];
    interp.regs.acc = group.images.len() as u16;
    Ok(())
}

pub fn render(interp: &mut interp::Interpreter) {
    interp.ui.render(&interp.gfx.framebuffer);
}
