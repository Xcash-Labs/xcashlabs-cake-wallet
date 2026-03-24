#!/bin/bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"

set -x -e

cd "$(dirname "$0")"

../prepare_moneroc.sh

JNI_LIBS_DIR="../../android/app/src/main/jniLibs"

for COIN in monero; do
    pushd ../xcashlabs_c
        for target in {x86_64,aarch64}-linux-android armv7a-linux-androideabi; do
            if [[ -f "release/${COIN}/${target}_libwallet2_api_c.so" ]]; then
                echo "file exist, not building xcashlabs_c for ${COIN}/$target."
            else
                ./build_single.sh "${COIN}" "$target" -j${MAKE_JOB_COUNT:-1}
                unxz -f "release/${COIN}/${target}_libwallet2_api_c.so.xz"
            fi

            case "$target" in
                x86_64-linux-android)
                    ABI_DIR="x86_64"
                    ;;
                aarch64-linux-android)
                    ABI_DIR="arm64-v8a"
                    ;;
                armv7a-linux-androideabi)
                    ABI_DIR="armeabi-v7a"
                    ;;
                *)
                    echo "Unknown Android target: $target"
                    exit 1
                    ;;
            esac

            mkdir -p "$JNI_LIBS_DIR/$ABI_DIR"
            rm -f "$JNI_LIBS_DIR/$ABI_DIR/lib${COIN}_libwallet2_api_c.so"

            install -m 0644 \
                "release/${COIN}/${target}_libwallet2_api_c.so" \
                "$JNI_LIBS_DIR/$ABI_DIR/lib${COIN}_libwallet2_api_c.so"

            ls -l "$JNI_LIBS_DIR/$ABI_DIR/lib${COIN}_libwallet2_api_c.so"
        done
    popd
done