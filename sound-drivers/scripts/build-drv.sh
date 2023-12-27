#!/bin/sh
WATCOM="/opt/watcom"
OPTS="-0 -bt=dos -ml -i=${WATCOM}/h"
WASM="wasm ${OPTS} -zq"

DRV=$1
EXPECTED_HASH=$2
if [ -z "$DRV" -o -z "$EXPECTED_HASH" ]; then
    echo "usage: $0 driver sha1-hash"
    exit 1
fi

REF=../../reference/${DRV}.drv
OUT=out.drv

mkdir -p build
rm -f build/${DRV}.obj build/${OUT}
${WASM} ${DRV}.asm -fo=build/${DRV}.obj
wlink option quiet format raw bin file build/${DRV}.obj name build/${OUT}
CUR_HASH=`sha1sum build/${OUT}|awk '{print $1}'`
if [ "${CUR_HASH}" != "$EXPECTED_HASH" ]; then
    echo
    echo "*** OUTPUT DOES NOT MATCH EXPECTED HASH!!!"
    if [ -f "${REF}" ]; then
        ndisasm -b 16 ${REF} > /tmp/base.txt
        ndisasm -b 16 build/${OUT} > /tmp/out.txt
        diff -u /tmp/base.txt /tmp/out.txt
    fi
else
    echo
    echo "*** Build result has the correct hash"
    echo
fi
