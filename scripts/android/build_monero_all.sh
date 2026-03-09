#!/bin/bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"

# Usage: env USE_DOCKER= ./build_all.sh 

set -x -e

cd "$(dirname "$0")"

../prepare_moneroc.sh

for COIN in monero wownero zano;
do
    pushd ../xcashlabs_c
        for target in {x86_64,aarch64}-linux-android armv7a-linux-androideabi
        do
            if [[ -f "release/${COIN}/${target}_libwallet2_api_c.so" ]];
            then
                echo "file exist, not building xcashlabs_c for ${COIN}/$target.";
            else
                ./build_single.sh ${COIN} $target -j$MAKE_JOB_COUNT
                unxz -f ../xcashlabs_c/release/${COIN}/${target}_libwallet2_api_c.so.xz
            fi
        done
    popd
done
