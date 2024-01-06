extern crate sciresource;

use std::fs::File;
use std::io::Write;
use std::path::{Path, PathBuf};

use anyhow::Result;
use clap::{Parser, Subcommand};

use sciresource::{resource, resource0, resource1, decompress};

#[derive(Subcommand)]
enum CliCommands {
    /// Extract resources
    Extract {
        /// Output directory
        out_dir: PathBuf,
    },
    /// Lists all resources
    List,
}

/// Extracts Sierra resources from RESOURCE.* to individual files
#[derive(Parser)]
struct Cli {
    /// Input directory
    in_dir: PathBuf,
    #[command(subcommand)]
    command: Option<CliCommands>
}

struct DecompressResult {
    message: String,
    output: Vec<u8>,
}

fn decompress(resource: &resource::ResourceData) -> DecompressResult {
    let info = &resource.info;
    let message: String;
    let mut output: Vec<u8>;
    match info.compression_method {
        resource::CompressionMethod::LZW => {
            output = Vec::with_capacity(info.uncompressed_size as usize);
            decompress::decompress_lzw(&resource.data, &mut output);
            message = "LZW".to_string();
        },
        resource::CompressionMethod::Huffman => {
            output = Vec::with_capacity(info.uncompressed_size as usize);
            decompress::decompress_huffman(&resource.data, &mut output);
            message = "Huffman".to_string();
        },
        resource::CompressionMethod::LZW1 |
        // Note that LZW1View / LZW1Pic need extra postprocessing which
        // currently isn't implemented
        resource::CompressionMethod::LZW1View |
        resource::CompressionMethod::LZW1Pic => {
            output = Vec::with_capacity(info.uncompressed_size as usize);
            decompress::decompress_lzw1(&resource.data, &mut output);
            message = "LZW1".to_string();
        },
        resource::CompressionMethod::Implode => {
            match explode::explode(&resource.data) {
                Ok(data) => {
                    message = "Explode".to_string();
                    output = data;
                },
                Err(err) => {
                    message = format!("Explode failed: {}", err);
                    output = Vec::new();
                },
            }
        },
        resource::CompressionMethod::None => {
            message = "None".to_string();
            output = resource.data.clone();
            output.truncate(info.uncompressed_size as usize);
        },
        resource::CompressionMethod::Unknown(n) => {
            message = format!("unrecognized compression method {}", n);
            output = Vec::new();
        }
    }
    DecompressResult{ message, output }
}

fn extract(out_dir: &Path, resource_map: &resource::ResourceMap) -> Result<()> {
    for rid in resource_map.get_entries() {
        let resource = resource_map.read_resource(&rid)?;
        let info = &resource.info;

        println!("  resource: {}.{:03} comp_size {} decomp_size {} comp_method {}",
            rid.rtype, rid.num, info.compressed_size, info.uncompressed_size, info.compression_method);

        let decompress_result = decompress(&resource);
        if !decompress_result.output.is_empty() {
            println!("    => {}: decompressed to {} bytes", decompress_result.message, decompress_result.output.len());
            let out_fname = out_dir.join(format!("{}.{:03}", rid.rtype, rid.num));
            let mut r_file = File::create(out_fname)?;
            r_file.write_all(&decompress_result.output)?;
        } else {
            println!("    !! could not decompress, skipping");
        }
    }
    Ok(())
}

fn list(resource_map: &resource::ResourceMap) -> Result<()> {
    println!("resource      compr uncompr method");
    for rid in resource_map.get_entries() {
        let resource = resource_map.read_resource(&rid)?;
        let info = &resource.info;
        let res_id = format!("{}.{:03}", rid.rtype, rid.num);
        println!("{:12} {:6}  {:6} {}", res_id, info.compressed_size, info.uncompressed_size, info.compression_method);
    }
    Ok(())
}

fn main() -> Result<()> {
    let args = Cli::parse();

    let resources: Option<resource::ResourceMap>;

    match resource1::parse_v1(&args.in_dir) {
        Ok(resources_v1) => {
            resources = Some(resources_v1);
        },
        Err(e) => {
            println!("- Unable to decode SCI1 resources: {}", e);
            match resource0::parse_v0(&args.in_dir) {
                Ok(resources_v0) => {
                    resources = Some(resources_v0);
                },
                Err(e) => {
                    println!("- Unable to decode SCI0 resources: {}", e);
                    std::process::exit(1);
                }
            }
        },
    }

    match &args.command {
        Some(CliCommands::Extract { out_dir }) => {
            extract(&out_dir, &resources.unwrap())?;
        },
        Some(CliCommands::List) => {
            list(&resources.unwrap())?;
        },
        None => { }
    }
    Ok(())
}
