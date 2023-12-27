# Sierra sound drivers

This repository contains reverse engineered reimplementations of drivers supplied by Sierra's adventure games from the late 1980's until the early 1990's. The goal is to understand the _audio subsystem_ by taking a deep dive into how the drivers interact with the hardware.

All Sierra drivers are 16-bit binaries which are loaded to a real-mode segment. I started by decompiling the binaries into a shape that the Watcom Assembler can build, and continued cleaning up the source code from there.

The following drivers have been analyzed:

|Game             |Driver      |Size|SHA1                                    |SCI version|
|-----------------|------------|----|----------------------------------------|-----------|
|Space Quest 3    |adl.drv     |9778|9ff3c144724819c7cd3bb2c773daab7332cc4beb|0.000.685  |
|Space Quest 3    |mt32.drv    |3179|2597f218c292646974fc9190da9770342191b5e5|0.000.685  |
|Quest For Glory 2|sndblast.drv|9672|dc2fa9c534236e0c2fdcf48a640d73cfbc8e5cfc|1.000.072  |
|King's Quest 5 CD|audblast.drv|3027|a6f6e0b2615eb7230b672c142a5e977c206a4072|x.yyy.zzz  |
|King's Quest 5 CD|mt32.drv    |1976|766b7d5e64be16265d41c8a0193453ac4676af56|x.yyy.zzz  |
|Quest For Glory 3|audblast.drv|5817|6b5bbef1e217ea20b069e11fb3f8720fe6d9bc8f|1.001.050  |
|Quest For Glory 3|genmidi.drv |2577|33ea59df373e671e6fa599fa8a3612effc97507b|1.001.050  |
|Quest For Glory 3|std.drv     |1465|8b06894d3693fe24c9cd8501333669ede76862eb|1.001.050  |

## Building

You need to install [OpenWatcom](https://github.com/open-watcom/open-watcom-v2) (I used the [September 2023 snapshop of version 2.0](https://github.com/open-watcom/open-watcom-v2/releases/tag/2023-09-01-Build)) in order to build the reverse engineered drivers. The end results should be binary equivalent to their Sierra counterparts, and this will be enforced by the build scripts.

If you own the original games and have the corresponding .drv file, it can be placed in the `reference/` directory - when a SHA1 mismatch is detected during building, the original and the build result will be disassembled and compared using `diff -u`.
