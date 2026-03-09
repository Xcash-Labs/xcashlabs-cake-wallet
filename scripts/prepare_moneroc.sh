#!/bin/bash

set -x -e

cd "$(dirname "$0")"

if [[ ! -d "xcashlabs_c/.git" ]];
then
    rm -rf xcashlabs_c
    git clone https://github.com/Xcash-Labs/xcashlabs_c --branch develop xcashlabs_c
    cd xcashlabs_c
    git reset --hard
    git submodule update --init --force --recursive
    ./apply_patches.sh xcash-labs-core
    ./apply_patches.sh wownero
    ./apply_patches.sh zano
else
    cd xcashlabs_c
fi

for coin in xcash-labs-core wownero zano;
do
    if [[ ! -f "$coin/.patch-applied" ]];
    then
        ./apply_patches.sh "$coin"
    fi
done

cd ..

echo "xcashlabs_c source prepared"
