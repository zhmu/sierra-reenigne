# Sierra resource compression

Please send any corrections or additions to [Rink Springer](mailto:rink@rink.nu) - thanks!

## Introduction

In early SCI decoding tools (for example, [Carl Muckenhoupt's SCI Decoder](https://web.archive.org/web/20001012101109/www.escape.com/~baf/sci/)), the compression algorithms were often referred to as _encryption_. However, rather than obfuscating the resources, disk space was a genuine concern at the time, and the fact that there have been multiple compression algorithms in use over time leads me to believe that the intent was space preservation. I will hence refer to these algorithms as _compression_ algorithms.

### No compression (method 0)

No further processing needed, the uncompressed and compressed lengths are identical.

### LZW (method 1)

As the name suggests, this is an implementation of the [Lempel–Ziv–Welch](https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Welch) algorithm. Specifically:

- The decoder starts processing 9-bit codes, which can grown up to 12 bits
- Code 0x100 resets the LZW stream to 9-bit codes, and restarts filling code 0x102
- Code 0x101 indicates end-of-stream
- Code 0x102 is the first code to be filled

LZW is very common and Sierra's implementation is pretty standard. Hence, I recommend reading [ZIP method 1: shrink/unshrink](https://www.hanshq.net/zip2.html#shrink) for more information and will not describe LZW further.

### Huffman (method 2)

Huffman coding is another common data compression mechanism - and again, there is already good information available. I recommend reading [ZIP files: Huffman coding](https://www.hanshq.net/zip.html#huffman) for more information. What makes Sierra's implementation unique is how the tree is stored and decoded.

The Sierra implementation contains a 2-byte header: 

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |num_nodes|u8  |Number of nodes in the Huffman tree            |
|1     |term     |u8  |Low byte of terminator value                   |

The terminator value consists of `term` with bit 8 set. If the Huffman tree decoder yields the terminator value, the decompression is assumed to be complete.

For every node, there is a 2-byte record:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |byte     |u8  |Literal byte value of this node                |
|1     |next     |u8  |Delta to the next node index                   |

Decoding the bytes is implemented in a straightforward matter:

- Initially, set `index = 0`
- Repeat while node `index` has a non-zero `next` value:
    - Read one bit from the input stream, into `b`
    - If `b = 0`, set `delta` to the _hi_ 4 bits of the `next` value in node `index`, otherwise
    - (`b = 1`), set `delta` to the _lo_ 4 bits of the `next` value in node `index`
    - If `delta = 0`: read 8 bits from the input stream, and return this value with bit 8 set
    - Otherwise, add `delta` to `index`
- Return the `byte` associated with node `index`

In SCI0 games, I've only seen Huffman compression used for `pic` resources - all other resources use LZW.

### Implode (methods 18, 19, 20)

This uses the _implode_ algorithm from PKWare's Data Compression Library - the string `PKWARE Data Compression Library(tm) Copyright 1990-92 PKWARE Inc.  All Rights Reserved.  Patent No. 5,051,745 Version 1.03` can be found in game executables that implement this compression method. Note that [US Patent 5.051.745](https://patents.google.com/patent/US5051745A/en) covers a string search method which seems to be used for _compressing_ the data.

More information can be found in [this usenet post from Ben Rudiak-Gould](https://groups.google.com/g/comp.compression/c/M5P064or93o/m/W1ca1-ad6kgJ).