extern crate sierra_reenigne;

use anyhow::Result;
use sierra_reenigne::sciscript::{
    vocab, kcalls,
    cmd::{print, inspect0, inspect1, recode1, decode1},
    sci0::{class_defs0, script0},
    sci1::{class_defs1, script1}
};
use clap::{Parser, Subcommand};

#[derive(Subcommand)]
enum CliCommand {
    /// Inspects given script
    Inspect {
        /// Script to decode
        script_id: u16
    },
    /// Decodes internal script.nnn structure
    Decode {
        /// Script to decode
        script_id: u16
    },
    /// Decodes and encodes script.nnn
    Recode {
        /// Script to decode
        script_id: u16
    },
    /// Display selector nams
    Selectors { },
    /// Display classes
    Classes{ },
}

/// Disassembles Sierra scripts
#[derive(Parser)]
struct Cli {
    #[command(flatten)]
    verbose: clap_verbosity_flag::Verbosity,
    #[clap(long, default_value_t=false)]
    /// Treat input as SCI1 (default: SCI0)
    sci1: bool,
    #[clap(long, default_value_t=false)]
    /// If set, external scripts will not be loaded
    no_externals: bool,
    /// Input directory
    in_dir: String,
    #[command(subcommand)]
    command: CliCommand
}

fn sci0_inspect(extract_path: &str, script_id: u16, kernel_vocab: &kcalls::KernelVocab, selector_vocab: &vocab::Vocab997) -> Result<()> {
    let class_definitions = sci0_get_class_defs(extract_path)?;

    let main_vocab: Option<vocab::Vocab000>;
    if let Ok(vocab_000_data) = std::fs::read(format!("{}/vocab.000", extract_path)) {
        match vocab::Vocab000::new(&vocab_000_data) {
            Ok(v) => { main_vocab = Some(v); },
            Err(e) => {
                println!("error: vocab.000 is corrupt: {}", e);
                main_vocab = None;
            }
        }
    } else {
        main_vocab = None;
    }

    let script0 = script0::load_sci0_script(extract_path, script_id as u16)?;
    inspect0::inspect_script0(&script0, selector_vocab, &kernel_vocab, &class_definitions, &main_vocab)
}

fn sci0_get_class_defs(extract_path: &str)-> Result<class_defs0::ClassDefinitions> {
    let vocab_996_data = std::fs::read(format!("{}/vocab.996", extract_path))?;
    let class_vocab = vocab::Vocab996::new(&vocab_996_data)?;
    Ok(class_defs0::ClassDefinitions::new(extract_path.to_string(), &class_vocab))
}

fn sci1_get_class_defs(extract_path: &str, load_externals: bool) -> Result<class_defs1::ClassDefinitions1> {
    let vocab_996_data = std::fs::read(format!("{}/vocab.996", extract_path))?;
    let class_vocab = vocab::Vocab996::new(&vocab_996_data)?;
    let class_extract_path = if load_externals { Some(extract_path) } else { None };
    class_defs1::ClassDefinitions1::new(class_extract_path, &class_vocab)
}

fn get_selectors(extract_path: &str) -> Result<vocab::Vocab997> {
    let vocab_997_data = std::fs::read(format!("{}/vocab.997", extract_path))?;
    vocab::Vocab997::new(&vocab_997_data)
}

fn decode(extract_path: &str, script_id: u16, args: &Cli, no_externals: bool) -> Result<()> {
    let selector_vocab = get_selectors(extract_path)?;
    let kernel_vocab = kcalls::load_kernel_vocab(extract_path);

    if args.sci1 {
        let class_definitions = sci1_get_class_defs(extract_path, !no_externals)?;
        let script1 = script1::load_sci1_script(extract_path, script_id as u16)?;
        decode1::decode_script1(&script1, &selector_vocab, &kernel_vocab, &class_definitions)
    } else {
        todo!("not implemented for sci0");
    }
}

fn inspect(extract_path: &str, script_id: u16, args: &Cli, no_externals: bool) -> Result<()> {
    let selector_vocab = get_selectors(extract_path)?;
    let kernel_vocab = kcalls::load_kernel_vocab(extract_path);

    if args.sci1 {
        let class_definitions = sci1_get_class_defs(extract_path, !no_externals)?;
        let script1 = script1::load_sci1_script(extract_path, script_id as u16)?;
        inspect1::inspect_script1(&script1, &selector_vocab, &kernel_vocab, &class_definitions)
    } else {
        sci0_inspect(extract_path, script_id, &kernel_vocab, &selector_vocab)
    }
}

fn sci1_recode(extract_path: &str, script_id: u16, kernel_vocab: &kcalls::KernelVocab, selector_vocab: &vocab::Vocab997) -> Result<()> {
    let class_definitions = sci1_get_class_defs(extract_path, true)?;
    let script1 = script1::load_sci1_script(extract_path, script_id as u16)?;
    recode1::recode_script1(&script1, selector_vocab, &kernel_vocab, &class_definitions)
}

fn recode(extract_path: &str, script_id: u16, args: &Cli) -> Result<()> {
    let selector_vocab = get_selectors(extract_path)?;
    let kernel_vocab = kcalls::load_kernel_vocab(extract_path);

    if args.sci1 {
        sci1_recode(extract_path, script_id, &kernel_vocab, &selector_vocab)
    } else {
        todo!("not implemented for sci0");
    }
}

fn main() -> Result<()> {
    let args = Cli::parse();
    env_logger::Builder::new()
        .filter_level(args.verbose.log_level_filter())
        .init();

    let extract_path = args.in_dir.as_str();

    match args.command {
        CliCommand::Inspect{ script_id } => {
            inspect(extract_path, script_id, &args, args.no_externals)
        },
        CliCommand::Decode{ script_id } => {
            decode(extract_path, script_id, &args, args.no_externals)
        },
        CliCommand::Recode{ script_id } => {
            recode(extract_path, script_id, &args)
        },
        CliCommand::Selectors{ } => {
            let selector_vocab = get_selectors(extract_path)?;
            print::print_selectors(&selector_vocab)
        },
        CliCommand::Classes{ } => {
            if args.sci1 {
                let class_definitions = sci1_get_class_defs(extract_path, true)?;
                print::sci1_print_classes(&class_definitions)
            } else {
                let class_definitions = sci0_get_class_defs(extract_path)?;
                print::sci0_print_classes(&class_definitions)
            }
        },
    }
}
