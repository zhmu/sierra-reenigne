extern crate sciresource;

use std::fs::File;
use std::io::Write;
use std::path::{Path, PathBuf};

use anyhow::Result;
use clap::Parser;

use sciresource::{resource, resource0, resource1, decompress};

/// Extracts Sierra resources from RESOURCE.* to individual files
#[derive(Parser)]
struct Cli {
    /// Input directory
    in_dir: PathBuf,
    /// Output directory
    out_dir: PathBuf,
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
        resource::CompressionMethod::Explode => {
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
        },
        resource::CompressionMethod::Unknown(n) => {
            message = format!("unrecognized compression method {}", n);
            output = Vec::new();
        }
    }
    DecompressResult{ message, output }
}

fn extract(out_dir: &Path, resource_map: &dyn resource::ResourceMap) -> Result<()> {
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

fn main() -> Result<()> {
    let args = Cli::parse();

    let resources: Box<dyn resource::ResourceMap>;

    match resource1::ResourceMapV1::new(&args.in_dir) {
        Ok(resources_v1) => {
            resources = Box::new(resources_v1);
        },
        Err(e) => {
            println!("- Unable to decode SCI1 resources: {}", e);
            match resource0::ResourceMapV0::new(&args.in_dir) {
                Ok(resources_v0) => {
                    resources = Box::new(resources_v0);
                },
                Err(e) => {
                    println!("- Unable to decode SCI0 resources: {}", e);
                    std::process::exit(1);
                }
            }
        },
    }

    extract(&args.out_dir, resources.as_ref())?;
    Ok(())
}
