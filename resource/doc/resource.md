# Sierra resources

Please send any corrections or additions to [Rink Springer](mailto:rink@rink.nu) - thanks!

## Introduction

For the purposes of this document, we will focus on the following files part in every SCI-based game:

- `RESOURCE.MAP`: lists which resources are available and where to find them
- `RESOURCE.nnn`: contains the resource data (`n` is `000`, `001`, etc)

In the earlier games, there would be a single `RESOURCE.nnn` per floppy disk. Some games use only a single `RESOURCE.000` file to contain all resource data.

Every resource is uniquely identified by a 16-bit _number_, typically ranging from 0 .. 999, and a _resource type_.

## Resource types

Below is a non-exhaustive list of all SCI resource types:

|Value|Name                |Description                                           |
|-----|--------------------|------------------------------------------------------|
|0    |view                |Sprites                                               |
|1    |picture             |Static pictures (contains graphics and collision data)|
|2    |script              |Script code/data                                      |
|3    |text                |Text (localized)                                      |
|4    |sound               |Music                                                 |
|6    |[vocab](vocab.md)   |Parser vocabulary (0), other are data for interpreter |
|7    |font                |Font                                                  |
|8    |cursor              |Mouse cursor                                          |
|9    |patch               |Music driver initialization data                      |

## SCI0

### RESOURCE.MAP

The SCI0 `RESOURCE.MAP` consists of a list of 6-byte records, where each record is:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |id       |u16 |Resource type/ID                               |
|2     |position |u32 |Resource location (`RESOURCE.nnn` / offset)    |

- Bits 0..10 of `id` contain the resource number, 0 .. 2047
- Bits 11..15 of `id` contain the resource type, 0 .. 31
- Bits 0..25 of `position` are the offset within the `RESOURCE.nnn` file of the resource
- Bits 26..31 of `position` is the resource volume to use (which `RESOURCE.nnn` file to use), 0..63

### Resource data

Once a resource has been located using the `RESOURCE.MAP` as described previously, the corresponding `RESOURCE.nnn` file is accessed and data is read. The first 8 bytes contain a resource header, which is:

|Offset|Name       |Type|Description                                  |
|------|-----------|----|---------------------------------------------|
|0     |id         |u16 |Resource type/ID                             |
|2     |comp_size  |u16 |Length of compressed data, in bytes          |
|4     |decomp_size|u16 |Resource length after decompression, in bytes|
|6     |comp_method|u16 |Compression algorithm in use                 |

The `id` has the same format as the `id` in the `RESOURCE.MAP` and should therefore be equal (I don't know why it is included here).

Compression methods are described in the [compress](compress.md) document.

## SCI1

### RESOURCE.MAP

The SCI1 `RESOURCE.MAP` improves resource searching by listing resources per type in a sorted list. This allows for binary searching.

#### Resource type directory

First, the `RESOURCE.MAP` contains a list of 3-byte records, where each record is:

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |type     |u8  |Resource type                                  |
|1     |offset   |u16 |Offset to resource list                        |

The final entry contains the resource type of `255`.

There is no length value stored: all resource lists are adjacently stored. For example, if following records are stored:

- type = 0, offset = 1000
- type = 1, offset = 1180
- type = 2, offset = 1300
- type = 255, offset = 1330

Then the following resource lists are present:

- type = 0, at offset 1000 ... 1180
- type = 1, at offset 1180 .. 1300
- type = 2, at offset 1300 .. 1330

#### Resource type list

For every `type`/`offset` combination, there is a sequence of records containing the resource information. Depending on the SCI1 version in use, these may be 6-byte of 5-byte records (the 5-byte records are newer)

##### 6-byte records

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |id       |u16 |Resource ID                                    |
|2     |position |u32 |Resource location (`RESOURCE.nnn` / offset)    |

- `id` is just the resource number and does not contain the type
- Bits 0..27 of `position` are the offset within the `RESOURCE.nnn` file of the resource
- Bits 28..31 of `position` is the resource volume to use (which `RESOURCE.nnn` file to use), 0..15

##### 5-byte records

This record format contains all resource data in a single file, `RESOURCE.000`.

|Offset|Name     |Type|Description                                    |
|------|---------|----|-----------------------------------------------|
|0     |id       |u16 |Resource ID                                    |
|2     |position |u24 |Bits 1..15 of the offset within `RESOURCE.000` |

- `id` is just the resource number and does not contain the type
- `position` is a 3-byte value (the three bytes must be combined to a 24-bit value).

Note that bit 0 of the offset is always zero (i.e. resources are always at even offsets) and is not stored. Hence, if we refer to the bytes of `position` as `a`, `b` and `c` in roder, the offset within `RESOURCE.000` is `(a << 1) + (b << 9) + (c << 17)`.

### Resource data

Once a resource has been located using the `RESOURCE.MAP` as described previously, the corresponding `RESOURCE.nnn` file is accessed and data is read. The first 9  bytes contain a resource header, which is:

|Offset|Name       |Type|Description                                  |
|------|-----------|----|---------------------------------------------|
|0     |type       |u8  |Resource type                                |
|1     |number     |u16 |Resource number                              |
|2     |comp_size  |u16 |Length of compressed data, in bytes          |
|4     |decomp_size|u16 |Resource length after decompression, in bytes|
|6     |comp_method|u16 |Compression algorithm in use                 |

Compression methods are described in the [compress](compress.md) document.