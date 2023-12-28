#!/bin/sh -e

for drv in \
    kq5/audblast \
    kq5/mt32 \
    qfg2/sndblast \
    qfg3/audblast \
    qfg3/genmidi \
    qfg3/std \
    sq3/adl \
    sq3/mt32 \
    ; do
        (cd $drv && ./build.sh)
done
