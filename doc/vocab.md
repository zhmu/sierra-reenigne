# Vocab(ulary) resources

Please send any corrections or additions to [Rink Springer](mailto:rink@rink.nu) - thanks!

Even though the game's parser vocabulary would seem the most obvious resource here, `vocab` resources are used for completely different formats and uses.

## vocab.000: Game vocabulary

This resource contains all words understood by the parser. This resource starts with a 52-byte header:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |offset_a |u16 |Offset to words starting with 'a'              |
|2     |offset_b |u16 |Offset to words starting with 'b'              |
|4     |offset_c |u16 |Offset to words starting with 'c'              |
|...   |...      |... |...                                            |
|46    |offset_x |u16 |Offset to words starting with 'x'              |
|48    |offset_y |u16 |Offset to words starting with 'y'              |
|50    |offset_c |u16 |Offset to words starting with 'z'              |

Every word is stored using the following method:

- The first byte contains the number of bytes to copy from the previous word
- The word's characters are contained in the next bytes
  - The charachter is stored in bits 0..6 of the byte
  - If bit 7 is set, it is the final character and the word is complete
- A 24-bit value describes the word's properties
  - Bits 12..15 contain the _class_ of the word
  - Bits 0..11 contain the _group_ of the word

## vocab.996: Class table

Whenever the interpreter needs to retrieve class _n_, it needs to know which script contains the code of this class. This information is contained within `vocab.996`, which consists of 4-byte records, where each record is:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |address  |u16 |Must be zero                                   |
|2     |scriptnr |u16 |Refers to script.<scriptnr> resource           |

These records are used by just indexing them: suppose the interpreter needs to reference some class _c_. It will then look at index _c_ of the `vocab.996` resource: if `address` is non-zero, it assumes the script has already been loaded and returns this address. Otherwise, it will load `script.<scriptnr>`, which will result in all `addresses` of its classes being set.

## vocab.997

This contains all selector names, which are only used for debugging (games seem to include this resource nevertheless). The resource starts with a 2-byte header:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |count    |u16 |Number of strings                              |

This is followed by `count` instances of a 2-byte record, where each record is:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |offset   |u16 |Offset of the string data                      |

At each `offset`, the actual string is stored as follows:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |length   |u16 |Offset of the string data                      |
|2     |content  |u8[]|ASCII characters, `length` times               |