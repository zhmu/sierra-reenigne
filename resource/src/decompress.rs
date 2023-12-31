use crate::bitstream;

#[derive(Copy, Clone)]
struct Token {
    offset: usize,
    length: usize
}

const LZW_TOKEN_RESET: u32 = 0x100;
const LZW_TOKEN_END_OF_STREAM: u32 = 0x101;
const LZW_TOKEN_INITIAL: u32 = 0x102;
const LZW_BITS_INITIAL: u32 = 9;
const LZW_BITS_MAX: u32 = 12;

fn lzw_end_token(num_bits: u32) -> u32 {
    (1 << num_bits) - 1
}

pub fn decompress_lzw(input: &[u8], output: &mut Vec<u8>) {
    let mut stream = bitstream::Streamer::new(input);
    let mut tokens = [ Token{ offset: 0, length: 0 }; (1 << LZW_BITS_MAX) as usize ];

    let mut token_lastlength: usize;
    let mut num_bits: u32 = LZW_BITS_INITIAL;
    let mut cur_token: u32 = LZW_TOKEN_INITIAL;
    while !stream.end_of_stream() {
        let token = stream.get_bits_lsb(num_bits);
        match token {
            LZW_TOKEN_RESET => {
                num_bits = LZW_BITS_INITIAL;
                cur_token = LZW_TOKEN_INITIAL;
                continue
            },
            LZW_TOKEN_END_OF_STREAM => {
                break
            },
            0x00..=0xff => {
                token_lastlength = 1;
                output.push(token as u8);
            },
            LZW_TOKEN_INITIAL.. => {
                let ref_token = &tokens[token as usize];
                token_lastlength = ref_token.length + 1;
                for n in 0..token_lastlength {
                    let b = output[ref_token.offset + n];
                    output.push(b);
                }
            }
        }

        if cur_token > lzw_end_token(num_bits) && num_bits < LZW_BITS_MAX {
            num_bits += 1;
        }

        if cur_token <= lzw_end_token(num_bits) {
            tokens[cur_token as usize] = Token{ offset: output.len() - token_lastlength, length: token_lastlength };
            cur_token += 1;
        }
    }
}

struct HuffmanNode {
    value: u8,
    index_delta_0: usize,
    index_delta_1: usize
}

fn get_huffman_code(stream: &mut bitstream::Streamer, nodes: &[HuffmanNode]) -> u16 {
    let mut index: usize = 0;
    while nodes[index].index_delta_0 != 0 || nodes[index].index_delta_1 != 0 {
        let delta = if stream.get_bits_msb(1) == 0 {
            nodes[index].index_delta_0
        } else {
            nodes[index].index_delta_1
        };
        if delta == 0 {
            return 0x100 | (stream.get_bits_msb(8) as u16);
        }
        index += delta;
    }
    nodes[index].value as u16
}

pub fn decompress_huffman(input: &[u8], output: &mut Vec<u8>) {
    let mut stream = bitstream::Streamer::new(input);
    let num_nodes: u16 = stream.get_byte() as u16;
    let terminator: u16 = 0x100 | (stream.get_byte() as u16);

    let mut nodes: Vec<HuffmanNode> = Vec::with_capacity(num_nodes as usize);
    for _ in 0..num_nodes {
        let value = stream.get_byte();
        let next = stream.get_byte();
        let index_delta_0 = (next >> 4) as usize; // 4 hi bits
        let index_delta_1 = (next & 0xf) as usize; // 4 lo bits
        nodes.push(HuffmanNode{ value, index_delta_0, index_delta_1 });
    }

    while !stream.end_of_stream() {
        let c = get_huffman_code(&mut stream, &nodes);
        if c == terminator {
            break;
        }
        output.push(c as u8);
    }
}