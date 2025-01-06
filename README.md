# Sierra reverse engineering

In the late 1980's until the early 1990's, [Sierra On-Line](https://en.wikipedia.org/wiki/Sierra_Entertainment) was a major video game developer well known for their adventure game series, such as King's Quest, Quest for Glory, Leisure Suit Larry, Police Quest and many more. If you are looking to play these old games, I recommend visiting [Good Old Games](https://www.gog.com): it is unlikely you'll find anything of value in this repository unless you are a programmer.

As a kid, I loved these games and soon I started wondering how they worked. It turns out all games use a custom engine, initially [Adventure Game Interpreter](https://en.wikipedia.org/wiki/Adventure_Game_Interpreter) and later _Script Interpreter_ (also known as _Sierra's Creative Interpreter_). I've mainly looked into the latter (SCI) games and this led to some involvement in the FreeSCI project (which has later been incorporated into [ScummVM](https://www.scummvm.org)). The design of such early software fascinates me: I love digging in and learning/discovering things!

Recently, I decided to start to properly clean up, write down and publish the information I've found and am still learning. Feedback (corrections, additional information, heck: anything really) is most welcome, preferably via email to rink@rink.nu.

## Contents

### Resource

All SCI games use a `RESOURCE.MAP` file, which details which resources are present and in which `RESOURCE.nnn` the content is located. Resources can be any aspect of game data, for example graphics, music, scripts, fonts and the like. In-depth information can be found in the [resource file format description](doc/resource.md) document.

`restool` can be used to list resource contents and extract them to individual files.

### Graphics

There are various `draw-...` tools available to render SCI resources to bitmaps:

- `draw-font`: renders SCI0 `font.NNN` (monochrome font)
- `draw-pic0`: renders SCI0 `pic.NNN` (16 colour background art)
- `draw-pic1`: renders SCI1 `pic.NNN` (256 colour background art)
- `draw-view0`: renders SCI0 `view.NNN` (16 colour sprites)
- `draw-view1`: renders SCI1 `view.NNN` (256 colour sprites)

### Sound

- [Sound drivers](sound/drivers/README.md): reverse engineered, commented sound drivers sources that yield byte-for-byte identical binaries to the original drivers (SCI0/SCI1)
- [SCI0PLAY](sound/sci0play/README.md): Allows playback of SCI0 songs on MS-DOS using the original drivers.
- [SCI1PLAY](sound/sci1play/README.md): Allows playback of SCI1 songs on MS-DOS using the original drivers.

### Script

`scripttool` can be used to 
- [disassemble0](script/tool/README.md): SCI0/SCI1 script tooling

## Building

Building all Rust-based projects requires a [Rust](https://www.rust-lang.org) toolchain installed. Once properly installed, it consists of simply invoking Cargo from the root directory, i.e.:

```sh
> cargo build
```

The sound drivers require [OpenWatcom](https://github.com/open-watcom/open-watcom-v2) to be installed. Look at the [specific instructions](sound/drivers/README.md) for more details.
