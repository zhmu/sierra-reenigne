use crate::{
    sciscript::{vocab, kcalls},
    scires::{resource::ResourceID, resource::ResourceType},
    sci_or_die::{resman, interp, ui},
};
use std::env;
use anyhow::{anyhow, Result};

pub fn run() -> Result<()> {
    env_logger::init();
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        return Err(anyhow!(format!("usage: {} path", args[0])));
    }
    let mut resource_manager = resman::ResourceManager::new(args[1].clone());

    let vocab996_res = resource_manager.get(ResourceID{ rtype: ResourceType::Vocab, num: 996 });
    let vocab996 = vocab::Vocab996::new(&vocab996_res.data)?;

    let vocab997_res = resource_manager.get(ResourceID{ rtype: ResourceType::Vocab, num: 997 });
    let vocab997 = vocab::Vocab997::new(&vocab997_res.data)?;

    let kvocab = kcalls::load_kernel_vocab(&args[1]);

    let mut ui = ui::UI::new()?;

    let mut interp = interp::Interpreter::new(&mut ui, &mut resource_manager, vocab996, vocab997, kvocab)?;
    interp.load_script(0)?;
    interp.info();

    match interp.run() {
        Ok(_) => { },
        Err(e) => {
            println!("FATAL ERROR: {}", e);
            interp.debug_dump();
        }
    }
    Ok(())
}
